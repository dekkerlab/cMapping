
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
import uuid
import math
import os

def main():
    
    parser=argparse.ArgumentParser(description='Apply a NAN filter/mask to interaction matrix.',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-in',help='interaction matrix hdf5 file',dest='infile',type=str,required=True)
    parser.add_argument('-nan',help='file with row/column numbers to set as nans.',type=str,dest='nanfile')
    parser.add_argument('-b',help='block size (default: hdf chunk size)',dest='blocksize',type=int)
    
    args=parser.parse_args()

    infile=args.infile
    nanfile=args.nanfile
    blocksize=args.blocksize
    
    print("\n",end="")
    
    inhdf=h5py.File(infile)
    
    bin_positions=inhdf['bin_positions'][:]
    genome=inhdf.attrs['genome'][:]
    chr_bin_range=inhdf['chr_bin_range'][:]
    chrs=inhdf['chrs'][:]
    n=inhdf['interactions'].shape[0]
    nan_mask=np.zeros(n,dtype=bool)
    
    print("\n",end="")
    
    print(sys.argv[0],": matrix ",n,"x",n,"\n",end="")
    if blocksize==None:
        blocksize=inhdf['interactions'].chunks[0]
    
    if nanfile!=None:
        
        print(sys.argv[0],": loading nan rows to hdf ... ")
        nnanrow=0
        nan_fh=open(nanfile,"r")
        
        for i in nan_fh:
            nanrow=int(i.rstrip("\n"))
            nan_mask[nanrow]=True
        
        for i in xrange(0,n,blocksize):
            current_block=inhdf['interactions'][i:i+blocksize,:]
            tmp_nan_mask=nan_mask[i:i+blocksize]
            if np.nansum(tmp_nan_mask) != 0:
                # nan rows in rowstripe
                current_block[tmp_nan_mask,:]=np.nan
            
            # nan _all_ columns in rowstripe
            current_block[:,nan_mask]=np.nan
            
            inhdf['interactions'][i:i+blocksize,:]=current_block
            
        nan_fh.close()
        print(sys.argv[0],": filtered",np.nansum(nan_mask),"rows")
        
    inhdf.close()
    
if __name__=="__main__":
    main()