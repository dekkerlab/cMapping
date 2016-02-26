
from __future__ import print_function

import numpy as np
import scipy as sp
import pdb
import h5py
import sys
import argparse
import logging
import time
import shutil
import gzip
import re
import os
import uuid
import math

def main():

    parser=argparse.ArgumentParser(description='Extract c-data from HDF5 file into TXT (matrix.gz)',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-i', '--input', dest='infile', type=str, required=True, help='input h5 file')
    parser.add_argument('-o', '--output', dest='outfile', type=str, help='output h5 file')
    parser.add_argument('-info', dest='info', action='store_true', help='interaction matrix hdf5 file',)
    parser.add_argument('-v', '--verbose', dest='verbose',  action='count', help="Increase verbosity (specify multiple times for more)")
    parser.add_argument('-b', dest='blocksize', type=int, help='block size for extracting (default=hdf chunk size)')
    parser.add_argument('-p', dest='precision', type=int, default=4, help='output precision (# of digits)')
    
    #parser.print_help()
    #usage = "usage: %prog [options] arg1 arg2"
                       
    args=parser.parse_args()

    infile=args.infile
    info=args.info
    verbose=args.verbose
    outfile=args.outfile
    blocksize=args.blocksize
    precision=args.precision
    
    log_level = logging.WARNING
    if verbose == 1:
        log_level = logging.INFO
    elif verbose >= 2:
        log_level = logging.DEBUG
    logging.basicConfig(level=log_level)
    
    verbose = info if info else verbose
    verboseprint = print if verbose else lambda *a, **k: None
    format_func=("{:."+str(precision)+"f}").format
    
    verboseprint("\n",end="")
    
    infile_name=os.path.basename(infile)
    inhdf=h5py.File(infile,'r')
    
    # attrs
    genome=inhdf.attrs['genome'][:]
    # datasets
    bin_positions=inhdf['bin_positions'][:]
    chr_bin_range=inhdf['chr_bin_range'][:]
    chrs=inhdf['chrs'][:]
    # matrix shape
    nrow=inhdf['interactions'].shape[0]
    ncol=inhdf['interactions'].shape[1]
    
    if blocksize==None:
        blocksize=inhdf['interactions'].chunks[0]
    if nrow!=ncol:
        sys.exit('error: non-symmetrical matrix found!')
    n=nrow=ncol
    
    chr_dict={}
    for i,c in enumerate(chrs):
        chr_dict[c]=i
        
    if(info):
        verboseprint("inputFile",infile,sep="\t")
        verboseprint("inputFileName",infile_name,sep="\t")
        verboseprint("matrix shape\t",nrow," x ",ncol,sep="")
        verboseprint("assembly",genome,sep="\t")
        verboseprint("h5 chunk",inhdf['interactions'].chunks[0],sep="\t")
        verboseprint("user chunk",blocksize,sep="\t")
        
        verboseprint("\nchrs",sep="\t")
        for i,c in enumerate(chrs):
            cbr=chr_bin_range[chr_dict[c]]
            start,end=bin_positions[cbr[0]][1],bin_positions[cbr[1]][2]
            size=(end-start)+1
            nbins=(cbr[1]-cbr[0])+1
            verboseprint("\t",i,"\t",c,":",start,"-",end,"\t(",size,")\t",cbr,"\t",nbins,sep="")
        verboseprint("")
        quit()

    if(n>300000):
        verboseprint("\tenforcing cis only mode!\n",end="")
        cis_mode=1
    verboseprint("\n",end="")
    
    outfile=re.sub(".hdf5", "", infile_name)
    outfile=re.sub(".matrix", "", outfile)
    outfile=re.sub(".gz", "", outfile)

    outfile=outfile+'.int32.h5'

    outhdf=h5py.File(outfile,'w')
    
    # assuming int32 for the time being.
    # may need to increase later if any one pixel > ~2billion (doubt this will ever be acheived / worth it)
    outhdf.create_dataset('interactions',shape=(n,n),dtype='int32',compression='gzip',chunks=(blocksize,blocksize),compression_opts=9)    
    
    verboseprint("converting matrix ...",end="")
    for i in xrange(0,nrow,blocksize):
        b=blocksize
        rowchunk=inhdf['interactions'][i:i+b,:][:]
        rowspread=rowchunk.shape[0]
        colspread=rowchunk.shape[1]
        
        rowchunk_int=rowchunk.astype('int32')        

        outhdf['interactions'][i:i+b,:]=rowchunk_int[:]
        
        # progress bar
        if(i != 0):
            verboseprint('\r',end="")
            pc=((float(i)/float((n)))*100)
            verboseprint("\t"+str(i)+" / "+str(n)+" ["+str("{0:.2f}".format(pc))+"%] complete",end="")
            if verbose: sys.stdout.flush()
    
    verboseprint('\r',end="")
    pc=((float(n)/float((n)))*100)
    verboseprint("\t"+str(n)+" / "+str(n)+" ["+str("{0:.2f}".format(pc))+"%] complete",end="")
    if verbose: sys.stdout.flush()
        
    outhdf.create_dataset('chrs',data=chrs)
    outhdf.create_dataset('chr_bin_range',data=chr_bin_range,dtype='int64')
    outhdf.create_dataset('bin_positions',data=bin_positions,dtype='int64')
    outhdf.attrs['genome']=genome
    
    verboseprint("done\n")
    
    inhdf.close()
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
    
       