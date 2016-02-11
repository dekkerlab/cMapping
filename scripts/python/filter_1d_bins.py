
from __future__ import print_function

import numpy as np
import scipy as sp
import pdb
import h5py
import sys
import argparse
import time

def main():

    parser=argparse.ArgumentParser(description='filter 1d bins based on various criteria.',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-in',help='input fragment+bin pairs file (frag1,frag2,bin1,bin2 unsorted)',dest='infile',type=str,required=True)
    parser.add_argument('-in_ref',help='input reference fragment file',dest='ref_infile',type=str,required=True)
    parser.add_argument('-in_bp',help='input bin position file',dest='bp_infile',type=str,required=True)
    parser.add_argument('-in_map',help='input frag to bin map file',dest='map_infile',type=str,required=True)
    parser.add_argument('-out',help='output file (numbers of nan rowcols)',dest='outfile',type=str,required=True)
    parser.add_argument('-bsum',help='bin sum threshold fraction (filter bins with read sum N% of total reads)',dest='bin_sum_threshold_fraction',type=float,default=0.1)
    parser.add_argument('-fsum',help='frag sum threshold',dest='frag_sum_threshold',type=float,default=1)    
    parser.add_argument('-fcov',help='fraction of covered frags per bin threshold',dest='frac_covered_frags_per_bin_threshold',type=float,default=0.5)
    parser.add_argument('-cov',help='total frags per bin threshold',dest='total_frags_per_bin_threshold',type=float,default=1)
    parser.add_argument('-cc',help='counts column',dest='countcol',type=int,default=6)
    parser.add_argument('-d',help='number of diagonals to ignore in factor calculation (will be replaced by zeros for calc)',dest='ignore_diagonal',type=int,default=0)
    parser.add_argument('-debug',help='debug mode',dest='debug',action='store_true')
    
    args=parser.parse_args()

    infile=args.infile
    ref_infile=args.ref_infile
    bp_infile=args.bp_infile
    map_infile=args.map_infile
    outfile=args.outfile
    bin_sum_threshold_fraction=args.bin_sum_threshold_fraction
    frag_sum_threshold=args.frag_sum_threshold
    frac_covered_frags_per_bin_threshold=args.frac_covered_frags_per_bin_threshold
    total_frags_per_bin_threshold=args.total_frags_per_bin_threshold
    countcol=args.countcol
    ignore_diagonal=args.ignore_diagonal
    debug=args.debug
    
    print("\n",end="")
    
    # load bin positions
    bp_fh=open(bp_infile,'r')

    bin_positions=[]
    bin_chr=[]
    for i,x in enumerate(bp_fh):
        a=x.rstrip("\n").split("\t")
        bin_positions.append([int(a[2]),int(a[3])])
        bin_chr.append(a[1])

    bin_positions=np.array(bin_positions)
    bin_chr=np.array(bin_chr)

    bp_fh.close()

    # load restriction fragment positions
    print(sys.argv[0],": loading restriction fragments ... ", end="")
    ref_fh=open(ref_infile,'r')

    rf_positions=[]
    rf_chr=[]
    for i,x in enumerate(ref_fh):
        a=x.rstrip("\n").split("\t")
        rf_positions.append([int(a[1]),int(a[2])])
        rf_chr.append(a[0])

    rf_positions=np.array(rf_positions)
    rf_chr=np.array(rf_chr)

    ref_fh.close()
    print("done\n", end="")
    
    # load frag_bin map
    print(sys.argv[0],": loading frag bin map ... ", end="")
    map_fh=open(map_infile,'r')

    frag_bin=[]
    for i,x in enumerate(map_fh):
        a=x.rstrip("\n").split("\t")
        frag_bin.append(int(a[1]))

    frag_bin=np.array(frag_bin)

    map_fh.close()
    print("done\n", end="")

    
    print(sys.argv[0],": ignoring",ignore_diagonal,"diagonals\n", end="")
    
    # calculate stats
    print(sys.argv[0],": calculating frag/bin sums ... ", end="")
    frag_sum=np.zeros(rf_positions.shape[0])
    bin_sum=np.zeros(bin_positions.shape[0])

    numreads=0
    in_fh=open(infile,"r")
    for i,x in enumerate(in_fh):
        a=x.rstrip("\n").split("\t")
        f1,f2,ff1,ff2,b1,b2=int(a[0]),int(a[1]),int(a[2]),int(a[3]),int(a[4]),int(a[5])
        
        counts=1
        if countcol!=None:
            counts=int(a[countcol])

        if (ignore_diagonal > 0) and (abs(ff1-ff2) <= ignore_diagonal):
            counts=0    
            
        frag_sum[ff1]+=counts
        frag_sum[ff2]+=counts
        
        if (ignore_diagonal > 0) and (abs(b1-b2) <= ignore_diagonal):
            counts=0
            
        numreads+=counts
        
        bin_sum[b1]+=counts
        bin_sum[b2]+=counts

        
    in_fh.close()
    print("done\n", end="")
    
    if debug:
        #write fragSum data
        out_fh=open(infile+".frag.sum.log","w")
        for i,sum in enumerate(frag_sum):
            out_fh.write("f"+str(i)+"\t"+str(sum)+"\n")
        out_fh.close()
    
        #write binSum data
        out_fh=open(infile+".bin.sum.log","w")
        for i,sum in enumerate(bin_sum):
            bin_start,bin_end=bin_positions[i]
            bin_chromosome=bin_chr[i]
            bin_label=str(i)+'|'+str(bin_chromosome)+':'+str(bin_start)+'-'+str(bin_end)
            out_fh.write(str(bin_label)+"\t"+str(sum)+"\n")
        out_fh.close()

    print(sys.argv[0],": calculating nan_mask ... ", end="")
    numbins=bin_positions.shape[0]
    frag_bin_shape=frag_bin.shape[0]
    bin_sum_threshold=((numreads/numbins)*bin_sum_threshold_fraction)
    
    total_frags_per_bin=np.bincount(frag_bin,minlength=numbins).astype(float)
    covered_frags_per_bin=np.bincount(frag_bin[frag_sum>frag_sum_threshold],minlength=numbins).astype(float)

    total_frags_per_bin_shape=total_frags_per_bin.shape[0]
    covered_frags_per_bin_shape=covered_frags_per_bin.shape[0]
    
    nan_bins1 = bin_sum<bin_sum_threshold
    nan_bins2 = total_frags_per_bin<total_frags_per_bin_threshold
    
    with np.errstate(invalid='ignore'):
        nan_bins3 = covered_frags_per_bin/total_frags_per_bin < frac_covered_frags_per_bin_threshold
    
    nan_bins = nan_bins1 | nan_bins2 | nan_bins3
    
    numbins=(len(bin_positions))
    numfrags=(len(rf_positions))
    num_nan_bins1=(len(np.nonzero(nan_bins1)[0]))
    num_nan_bins2=(len(np.nonzero(nan_bins2)[0]))
    num_nan_bins3=(len(np.nonzero(nan_bins3)[0]))
    num_nan_bins=(len(np.nonzero(nan_bins)[0]))
    print("done\n", end="")
    
    print(sys.argv[0],": bin_sum_threshold =",bin_sum_threshold,"\n", end="")
    print(sys.argv[0],": numbins =",numbins,"\n", end="")
    print(sys.argv[0],": numfrags =",numfrags,"\n", end="")
    print(sys.argv[0],": num_nan_bins1 =",num_nan_bins1,"\n", end="")
    print(sys.argv[0],": num_nan_bins2 =",num_nan_bins2,"\n", end="")
    print(sys.argv[0],": num_nan_bins3 =",num_nan_bins3,"\n", end="")
    print(sys.argv[0],": num_nan_bins =",num_nan_bins,"\n", end="")
    
    out_fh=open(outfile,"w")
    map((lambda x: print(x,file=out_fh)),np.nonzero(nan_bins)[0])
    out_fh.close()

if __name__=="__main__":
    main()
