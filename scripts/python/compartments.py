
from __future__ import print_function

import numpy as np
import scipy as sp
import scipy.linalg
import pdb
import h5py
import sys
import argparse
import time
import shutil

def main():
    
    parser=argparse.ArgumentParser(description='Calculate compartments (first eigenvector) using power iteration.',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-in',help='interaction matrix hdf5 file',dest='infile',type=str,required=True)
    parser.add_argument('-out',help='output file name',dest='outfile',type=str,required=True)
    parser.add_argument('-b',help='block size (default: hdf chunk size)',dest='blocksize',type=int)
    parser.add_argument('-t',help='convergence threshold',dest='threshold',type=float,default=1e-5)
   
    args=parser.parse_args()

    infile=args.infile
    outfile=args.outfile
    blocksize=args.blocksize
    threshold=args.threshold

    inhdf=h5py.File(infile,'r')
    A=inhdf['interactions']
    n=A.shape[0]
    bin_mask=np.zeros(n,dtype=bool)
    
    if blocksize==None:
        blocksize=inhdf['interactions'].chunks[0]

    chrs=inhdf['chrs'][:]
    chr_dict={}
    for i,c in enumerate(chrs):
        chr_dict[c]=i
        
    bin_positions=inhdf['bin_positions'][:]
    genome=inhdf.attrs['genome'][:]
    chr_bin_range=inhdf['chr_bin_range'][:]
    
    header=[str(i)+'|'+genome+'|'+str(chrs[bin_positions[i,0]])+':'+str(bin_positions[i,1])+'-'+str(bin_positions[i,2]) for i,b in enumerate(bin_positions)]
    
    start_time=time.time()
    print("calculating...")
    newb=1+np.random.rand(n)
    b=np.zeros(n)
    c=0
    while np.max(np.abs(b-newb))>threshold:
        print("iteration",c,"gap",np.max(np.abs(b-newb)))
        
        b=np.array(newb)

        for i in np.arange(0,n,blocksize):

            newb[i:i+blocksize]=np.dot(np.nan_to_num(A[i:i+blocksize,:]),b)

        newb/=sp.linalg.norm(newb)
            
        c+=1
        
    print("finished",str(c),"iterations in",time.time()-start_time,"seconds")
    
    for c in chrs:
        compartmentFile=outfile+"__"+c+".txt"
        print(sys.argv[0],": writing (",c,") [",compartmentFile,"] ... ")
        
        r=chr_bin_range[chr_dict[c]]
        bin_mask[r[0]:r[1]+1]=True
        header=[str(i)+'|'+genome+'|'+str(chrs[bin_positions[i,0]])+':'+str(bin_positions[i,1])+'-'+str(bin_positions[i,2]) for i in np.nonzero(bin_mask)[0]]
        compartmentData=[newb[i] for i in np.nonzero(bin_mask)[0]]
        data=np.column_stack((header,compartmentData))
        np.savetxt(compartmentFile,data,fmt="%s",delimiter="\t")
        
    # output    
    inhdf.close()

    print("done")
  
    
if __name__=="__main__":
    main()
