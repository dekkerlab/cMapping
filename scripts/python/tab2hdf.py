
from __future__ import print_function
from __future__ import division

import numpy as np
import scipy as sp
import pdb
import h5py
import sys
import argparse
import time
import re
import gzip
import os

def main():

    parser=argparse.ArgumentParser(description='Convert text file(s) to hdf5',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-in',help='interaction matrix',dest='infile',type=str,required=True)
    
    parser.add_argument('-out',help='output hdf5 file',dest='outfile',type=str,required=False)
    parser.add_argument('-g',help='genome name',dest='genome',type=str,required=False)
 
    parser.add_argument('-b',help='blocksize for chunks',dest='blocksize',type=int,default=128)
    parser.add_argument('-format',help='interaction matrix output file format',dest='in_format',type=str,default='cworld',choices=['cworld','tab3'])

    args=parser.parse_args()

    infile=args.infile
    outfile=args.outfile
    genome=args.genome
    blocksize=args.blocksize
    in_format=args.in_format
    
    infile_name=os.path.basename(infile)
    if infile.endswith('.gz'):
        infh=gzip.open(infile,'r')
        infile_name=re.sub(".matrix", "", infile_name)
        infile_name=re.sub(".gz", "", infile_name)
    else:
        infh=open(infile,'r')
   
    if outfile==None:
        outfile=infile_name+'.hdf5'
        
    outhdf=h5py.File(outfile,'w')
    header_passed=False
    initialized=False
    c=0
    
    bin_chrs=[]
    bin_starts=[]
    bin_ends=[]
    chrs=[]
    data=[]
    
    for i in infh:
        i=i.replace("NA", "nan")
        x=i.rstrip("\n").split("\t")
        
        if((len(x[0]) != 0) and (x[0][0]=="#")):
            continue
        
        if in_format=="cworld":
            
            if not header_passed:
                header_passed=True
                continue
                
            m=re.search(r'(\S+)\|(\S+)\|(\S+):(\d+)-(\d+)',x[0])
            if m==None:
                sys.exit('error: incorrect input format!')
                
            bin_id,genome,chr_id,bin_start,bin_end=m.groups()
            data+=[np.array(x[1:],dtype=np.float64)]

        elif in_format=="tab3":
            chr_id,bin_start,bin_end=x[:3]
            data+=[np.array(x[3:],dtype=np.float64)]
        else:
            sys.exit("unknown format "+in_format)
           
        if not initialized:
            n=data[0].shape[0]

            if blocksize<=0:
                blocksize=64
            if blocksize>n:
                blocksize=n
            
            print(sys.argv[0],": setting block size to",blocksize,"\n", end="")
            
            outhdf.create_dataset('interactions',shape=(n,n),dtype='float64',compression='gzip',chunks=(blocksize,blocksize))
            
            if genome==None:
                sys.exit("genome not defined")
                
            outhdf.attrs['genome']=genome

            initialized=True
    
        
        if len(chrs)==0 or chr_id!=chrs[-1]:
            chrs+=[chr_id]

        bin_chrs.append(len(chrs)-1)
        bin_starts.append(int(bin_start))
        bin_ends.append(int(bin_end))

        if len(data)==blocksize:
            outhdf['interactions'][c:c+blocksize,:]=data
            data=[]
            c+=blocksize

    if (len(data)>0):
        outhdf['interactions'][c:,:]=data
    
    infh.close()


    chrs=np.array(chrs)
    nchrs=chrs.shape[0]
    
    bin_positions=np.c_[bin_chrs,bin_starts,bin_ends]
    
    chr_bin_range=np.zeros((nchrs,2))
  
    for i in xrange(nchrs):
        chr_bins=np.nonzero(bin_positions[:,0]==i)[0]
        chr_bin_range[i]=np.min(chr_bins),np.max(chr_bins)

    outhdf.create_dataset('chrs',data=chrs)
    outhdf.create_dataset('chr_bin_range',data=chr_bin_range,dtype='int64')
    outhdf.create_dataset('bin_positions',data=bin_positions,dtype='int64')
    

    outhdf.close()

def round_down(num, divisor):
    return num - (num%divisor)    

if __name__=="__main__":
    main()
