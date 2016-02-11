
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
    parser.add_argument('-nan',help='file with row/column numbers to set as nans.',type=str,dest='nanfile',required=True)
    
    parser.add_argument('-out',help='output hdf5 file ',dest='outfile',type=str,required=False)
    parser.add_argument('-b',help='block size (default: hdf chunk size)',dest='blocksize',type=int)
    
    args=parser.parse_args()

    infile=args.infile
    nanfile=args.nanfile
    
    outfile=args.outfile
    blocksize=args.blocksize

    print("\n",end="")
    
    infile_name=os.path.basename(infile)
    infile_name=re.sub(".hdf5", "", infile_name)
    
    if outfile==None:
        outfile=infile_name+'.masked.hdf5'
        
    # hdf5 is copied, and then nans in the copy are replaced with numbers (just for balancing)
    
    print(sys.argv[0],": copying hdf file ... ", end="")
    shutil.copy(infile,outfile)
    print("done\n", end="")
    
    outhdf=h5py.File(outfile)
    
    bin_positions=outhdf['bin_positions'][:]
    genome=outhdf.attrs['genome'][:]
    chr_bin_range=outhdf['chr_bin_range'][:]
    chrs=outhdf['chrs'][:]
    n=outhdf['interactions'].shape[0]
    nan_mask=np.zeros(n,dtype=bool)
    
    print(sys.argv[0],": matrix ",n,"x",n,"\n",end="")
 
    if blocksize==None:
        blocksize=outhdf['interactions'].chunks[0]

    # build chr dict    
    chr2index={}
    index2chr={}
    for i,c in enumerate(chrs):
        chr2index[c]=i
        index2chr[i]=c
    
    bin2index={}
    index2bin={}
    for i,bin in enumerate(bin_positions):
        coordinate=str(index2chr[bin[0]])+':'+str(bin[1])+'-'+str(bin[2])
        bin2index[coordinate]=i
        index2bin[i]=coordinate
        
    if nanfile!=None:
        
        print(sys.argv[0],": loading nan rows to hdf ... ")
        nnanrow=0
        nan_fh=open(nanfile,"r")
        
        for i in nan_fh:
            nanrow=i.rstrip("\n")
            bin_id,genome,chr,bin_start,bin_end=splitheader(nanrow)
            
            coordinate=str(chr)+':'+str(bin_start)+'-'+str(bin_end)
            nan_id=bin2index[coordinate]
            
            nan_mask[nan_id]=True
        
        for i in xrange(0,n,blocksize):
            current_block=outhdf['interactions'][i:i+blocksize,:]
            tmp_nan_mask=nan_mask[i:i+blocksize]
            if np.nansum(tmp_nan_mask) != 0:
                current_block[tmp_nan_mask,:]=np.nan
            
            current_block[:,nan_mask]=np.nan
            
            outhdf['interactions'][i:i+blocksize,:]=current_block
            
                  # progress bar
            if(i != 0):
                sys.stdout.write('\r')
                pc=((float(i)/float((n)))*100)
                sys.stdout.write("\t"+str(i)+" / "+str(n)+" ["+str("{0:.2f}".format(pc))+"%] complete")
                sys.stdout.flush()
    
        sys.stdout.write('\r')
        pc=((float(n)/float((n)))*100)
        sys.stdout.write("\t"+str(n)+" / "+str(n)+" ["+str("{0:.2f}".format(pc))+"%] complete")
        sys.stdout.flush()
            
        nan_fh.close()
        print(sys.argv[0],": filtered",np.nansum(nan_mask),"rows")
        
    outhdf.close()

def getSmallUniqueString():  
    tmp_uniq=str(uuid.uuid4())
    tmp_uniq=tmp_uniq.split('-')[-1]
    return(tmp_uniq)

def bin2header(bin,genome,chrs,index=getSmallUniqueString()):
    #name|assembly|chr:start-end
    header=str(index)+'|'+genome+'|'+str(chrs[bin[0]])+':'+str(bin[1])+'-'+str(bin[2])
    return(header)


def splitheader(header):
    m=re.search(r'(\S+)\|(\S+)\|(\S+):(\d+)-(\d+)',header)
    if m==None:
        sys.exit('error: incorrect input format!')
                
    bin_id,genome,chr_id,bin_start,bin_end=m.groups()
    
    return(bin_id,genome,chr_id,bin_start,bin_end)
    
if __name__=="__main__":
    main()
    
       