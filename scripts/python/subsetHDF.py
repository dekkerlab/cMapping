
from __future__ import print_function

import numpy as np
import scipy as sp
import pdb
import h5py
import sys
import argparse
import time
import shutil
import re
import os

def main():
    
    parser=argparse.ArgumentParser(description='Apply Sinkhorn Balancing to interaction matrix.',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-in',help='interaction matrix hdf5 file',dest='infile',type=str,required=True)
    
    parser.add_argument('-out',help='output hdf5 file ',dest='outfile',type=str,required=False)
    
    parser.add_argument('-cis',help='extract cis maps only',dest='cis_mode',action='store_true')
    parser.add_argument('-chrs',help='subset of chromosomes to extract (default=all)',dest='rel_chrs',nargs='+',type=str)
    parser.add_argument('-zc',help='zoom coordinate (can only select symmetrical subsets)',dest='zoom_coord_str',type=str)

    parser.add_argument('-b',help='block size for extracting (default=hdf chunk size)',dest='blocksize',type=int)
    
    
    args=parser.parse_args()

    infile=args.infile
    outfile=args.outfile
    cis_mode=args.cis_mode
    rel_chrs=args.rel_chrs
    zoom_coord_str=args.zoom_coord_str
    blocksize=args.blocksize

    print("\n",end="")
    
    infile_name=os.path.basename(infile)
    infile_name=re.sub(".hdf5", "", infile_name)
    
    if outfile==None:
        outfile=infile_name+'.subset.hdf5'
    
    inhdf=h5py.File(infile,'r')
    n=inhdf['interactions'].shape[0]
    
    # build chr dict    
    chrs=inhdf['chrs'][:]
    chr_dict={}
    for i,c in enumerate(chrs):
        chr_dict[c]=i
          
    zoom_chr_id,zoom_start,zoom_end=None,None,None
    if(zoom_coord_str!=None):
        zoom_coord=re.search(r'(\S+):(\d+)-(\d+)',zoom_coord_str)
        if zoom_coord==None:
            sys.exit('error: incorrect zoom input format!')
        zoom_chr_id,zoom_start,zoom_end=zoom_coord.groups()
        zoom_start=int(zoom_start)
        zoom_end=int(zoom_end)
        rel_chrs=[zoom_chr_id]
        
    print("zoom subset coordinates:",zoom_coord_str)
    print("\n",end="")
    
    print("selected chxromosomes\n",end="")
    if rel_chrs!=None:
        # check relevant chromosomes    
        for c in rel_chrs:
            print("\t",c,"\n",end="")
            if not c in chr_dict:
                sys.exit('specificed chr '+c+'not found in file!')
        # ensure rel_chrs are sorted same as the HDF
        rel_chrs=sorted(rel_chrs,key=lambda x:chr_dict[x])
    else:
        rel_chrs=chrs
        print("\tall\n",end="")
        
    print("\n",end="")
     
    subset_chr_dict={}
    for i,c in enumerate(rel_chrs):
        subset_chr_dict[c]=i
    
    print("available chromosomes\n",end="")
    for i,c in enumerate(chrs):
        print("\t",c,"\n",end="")
    print("\n",end="")
      
    bin_positions=inhdf['bin_positions'][:]
    genome=inhdf.attrs['genome'][:]
    chr_bin_range=inhdf['chr_bin_range'][:]
    n=inhdf['interactions'].shape[0]
    bin_mask=np.zeros(n,dtype=bool)
    c_ind_mask=np.zeros(len(chrs),dtype=bool)
    chr_bin_mask = {}
    
    for i,c in enumerate(rel_chrs):
        #build bin mask
        c_ind=chr_dict[c]
        
        c_ind_mask[c_ind]=True
        
        tmp_chr_bin_mask=np.zeros(n,dtype=bool)
        r=chr_bin_range[c_ind]
        tmp_chr_bin_mask[r[0]:r[1]+1]=True
        bin_mask[r[0]:r[1]+1]=True
        
        chr_bin_mask[c]=tmp_chr_bin_mask
    
    # re-mask chr mask by bin_mask [rel_chrs]
    for i,c in enumerate(rel_chrs):
        cis_mask=chr_bin_mask[c]
        cis_mask=cis_mask[bin_mask]
        chr_bin_mask[c]=cis_mask
        
    if blocksize==None:
        blocksize=inhdf['interactions'].chunks[0]

    print("matrix is",n,"x",n)
    sn=np.count_nonzero(bin_mask)
    print("subset matrix is",sn,"x",sn)
    print("blocksize is",blocksize)
    
    print("")
   
    # subset chrs
    #outhdf.create_dataset('chrs',data=rel_chrs)
    
    masked_bin_positions=bin_positions[bin_mask]
    
    print("subsetting hdf datasets ... ",end="")
    # subset chr bin range
    bin_index=0
    masked_chr_bin_range=np.zeros((len(rel_chrs),2),dtype=np.int)    
    for i,c in enumerate(rel_chrs):
        c_ind=chr_dict[c]
        c_start,c_end=inhdf['chr_bin_range'][c_ind]
        
        # redefine chr bounds by bin mask 
        tmp_bin_mask=bin_mask[c_start:c_end+1]
        
        c_end=max(np.nonzero(tmp_bin_mask))[-1]+bin_index
        c_start=max(np.nonzero(tmp_bin_mask))[0]+bin_index

        bin_index += (c_end-c_start)+1
        
        masked_chr_bin_range[i]=c_start,c_end
        # reset chr index
        masked_bin_positions[c_start:c_end+1,0]=i
    
    print("done")
    
    if blocksize>sn:
        blocksize=sn        
    
    outhdf=h5py.File(outfile,'w')
    outhdf.create_dataset('interactions',shape=(sn,sn),dtype='float64',compression='gzip',chunks=(blocksize,blocksize))
    #test
    print("subsetting matrix ...")
    rowchunk=0
    for c in rel_chrs:
        c_ind=chr_dict[c]
        c_start,c_end=inhdf['chr_bin_range'][c_ind]
            
        # redefine chr bounds by bin mask 
        tmp_bin_mask=bin_mask[c_start:c_end+1]
        c_end=max(np.nonzero(tmp_bin_mask))[-1]+c_start
        c_start=max(np.nonzero(tmp_bin_mask))[0]+c_start
        
        for i in xrange(c_start,c_end+1,blocksize):
            b=min(c_end-i+1,blocksize)
            current_block=inhdf['interactions'][i:i+b,:][:,bin_mask]
            colspread=current_block.shape[1]
            
            #print("\t",i,rowchunk,"-",(rowchunk+current_block.shape[0]),current_block.shape[0],"x",colspread)
            outhdf['interactions'][rowchunk:rowchunk+current_block.shape[0],:]=current_block
            rowchunk+=current_block.shape[0]
            
            if(rowchunk != 0):
                sys.stdout.write('\r')
            pc=((float(rowchunk)/float(sn))*100)
            sys.stdout.write("\t"+str(rowchunk)+" / "+str(sn)+" ["+str("{0:.2f}".format(pc))+"%] complete")
            sys.stdout.flush()

    sys.stdout.write('\r')
    pc=((float(sn)/float(sn))*100)
    sys.stdout.write("\t"+str(sn)+" / "+str(sn)+" ["+str("{0:.2f}".format(pc))+"%] complete")
    sys.stdout.flush()
            
    outhdf.attrs['genome']=genome
    outhdf.create_dataset('chrs',data=rel_chrs)
    outhdf.create_dataset('chr_bin_range',data=masked_chr_bin_range,dtype='int64')
    outhdf.create_dataset('bin_positions',data=masked_bin_positions,dtype='int64')
    
    print("")
    
    
           
def getOverlap(a, b):
    return max(0, min(a[1], b[1]) - max(a[0], b[0]))


if __name__=="__main__":
    main()

   
   