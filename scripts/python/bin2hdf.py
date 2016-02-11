
from __future__ import print_function
from __future__ import division

import numpy as np
import scipy as sp
import pdb
import h5py
import sys
import argparse
import time

def main():

    parser=argparse.ArgumentParser(description='Convert binned file to hdf5',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-in',help='binned file (sorted frag1,frag2,bin1,bin2,countcol; bin1<=bin2)',dest='infile',type=str,required=True)
    parser.add_argument('-out',help='output hdf5 file',dest='outfile',type=str,required=True)
    
    parser.add_argument('-g',help='genome name',dest='genome',type=str,required=True)

    parser.add_argument('-in_bp',help='bin position file (sorted chr,start,end)',dest='bp_infile',type=str,required=True)
 
    parser.add_argument('-b',help='blocksize for chunks',dest='blocksize',type=int,default=128)
    parser.add_argument('-c',help='bin columns in binned input file (zero-based)',dest='bincols',type=int,nargs='+',default=[4,5])
    parser.add_argument('-cc',help='counts column (zero-based)',dest='countcol',type=int,default=6)

    parser.add_argument('-nan',help='file with row/column numbers to set as nans.',type=str,dest='nanfile')

    args=parser.parse_args()

    infile=args.infile
    outfile=args.outfile
    genome=args.genome
    bp_infile=args.bp_infile
    blocksize=args.blocksize
    bincols=args.bincols
    nanfile=args.nanfile
    countcol=args.countcol
    
    print("\n",end="")
    
    outhdf=h5py.File(outfile,'w')

    bin_chrids=[]
    bin_starts=[]
    bin_ends=[]
    chrs_set=set()
    chr2index=[]
    current_chr=None
    # load bin position file
    
    print(sys.argv[0],": loading bin position file ... ", end="")
    bp_infh=open(bp_infile,"r")
    for i in bp_infh:
        bin_id,chr_id,start,end=i.rstrip("\n").split("\t")
        bin_chrids.append(chr_id)
        chrs_set.add(chr_id)

        if (chr_id!=current_chr):
            chr2index.append(chr_id)
        current_chr=chr_id

        bin_starts.append(int(start))
        bin_ends.append(int(end))
    bp_infh.close()
    print("done\n", end="")
    
    chrs=np.array(chr2index)
    nchrs=chrs.shape[0]

    chr_dict=dict(zip(chrs,np.arange(nchrs)))
    bin_chrs=[chr_dict[i] for i in bin_chrids]
    
    bin_positions=np.c_[bin_chrs,bin_starts,bin_ends]
    chr_bin_range=np.zeros((nchrs,2))
  
    print(sys.argv[0],": found",nchrs,"chromosomes\n", end="")
    for i in xrange(nchrs):
        chr_bins=np.nonzero(bin_positions[:,0]==i)[0]
        chr_bin_range[i]=np.min(chr_bins),np.max(chr_bins)

    outhdf.create_dataset('chrs',data=chrs)
    outhdf.create_dataset('chr_bin_range',data=chr_bin_range,dtype='int64')
    outhdf.create_dataset('bin_positions',data=bin_positions,dtype='int64')
    
    n=bin_positions.shape[0]

    if blocksize<=0:
        blocksize=64
    if blocksize>n:
        blocksize=n
    
    print(sys.argv[0],": setting block size to",blocksize,"\n", end="")
    
    outhdf.create_dataset('interactions',shape=(n,n),dtype='float64',compression='gzip',chunks=(blocksize,blocksize))
    outhdf.attrs['genome']=genome
    
    # write interaction matrix to file
    print(sys.argv[0],": writing matrix to hdf ... ", end="")
    
    infh=open(infile,'r')

    try:
        a=infh.next().rstrip("\n").split("\t")
        
        bin1,bin2=int(a[bincols[0]]),int(a[bincols[1]])
        counts=1
        if countcol!=None:
            counts=int(a[countcol])
    except StopIteration:
        bin1=np.inf
        
    start_time=time.time()
    for i in xrange(0,n,blocksize):
        bsize=min(blocksize,n-i)
        memblock=np.zeros((bsize,n-i))
    
        while bin1<i+bsize:

            try:
                memblock[bin1-i,bin2-i]+=counts
                a=infh.next().rstrip("\n").split("\t")
                bin1,bin2=int(a[bincols[0]]),int(a[bincols[1]])
                if bin1>bin2:
                    sys.exit('error: bin1 ('+str(bin1)+') > bin2 ('+str(bin2)+')')
                counts=1
                if countcol!=None:
                    counts=int(a[countcol])
       
            except StopIteration:
                bin1=np.inf

        tri_ind=np.triu_indices(bsize)
        memblock[tri_ind[1],tri_ind[0]]=memblock[tri_ind[0],tri_ind[1]]
        outhdf['interactions'][i:i+bsize,i:n]=memblock[:]
        if i+bsize<n:
            outhdf['interactions'][i+bsize:n,i:i+bsize]=memblock[:,bsize:].T
            
    infh.close()
    print("done\n", end="")
 
 
    # load nan rows and write to hdf
    
    if nanfile!=None:
        print(sys.argv[0],": loading nan rows to hdf ... ", end="")
        nnanrow=0
        nan_fh=open(nanfile,"r")
        for i in nan_fh:
            nanrow=int(i.rstrip("\n"))
            outhdf['interactions'][:,nanrow]=np.nan
            outhdf['interactions'][nanrow,:]=np.nan
            nnanrow+=1
        
        nan_fh.close()
        print("done\n", end="")
        print(sys.argv[0],": filtered",nnanrow,"rows")
        
    outhdf.close()
    
def round_down(num, divisor):
    return num - (num%divisor)    

if __name__=="__main__":
    main()


    
