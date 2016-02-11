
from __future__ import print_function

import numpy as np
import scipy as sp
import pdb
import h5py
import sys
import argparse
import time
import gzip
from collections import defaultdict

def main():

    parser=argparse.ArgumentParser(description='Convert fragment pairs to bin pairs. fragment file does not have to be sorted',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-in',help='input fragment pairs file (format: frag1,frag2)',dest='infile',type=str,required=True)
    parser.add_argument('-in_ref',help='input reference fragment file',dest='ref_infile',type=str,required=True)
    parser.add_argument('-c',help='count column',dest='countcol',type=int,default=2)
    parser.add_argument('-out',help='output binned file',dest='outfile',type=str,required=True)    
    parser.add_argument('-out_bp',help='output bin position file',dest='bp_outfile',type=str,required=True)
    parser.add_argument('-out_map',help='output map frag to bin file',dest='map_outfile',type=str,required=True)
    parser.add_argument('-b',help='bin size',dest='binsize',type=int,default=100000)

    args=parser.parse_args()

    infile=args.infile
    ref_infile=args.ref_infile
    outfile=args.outfile 
    bp_outfile=args.bp_outfile
    map_outfile=args.map_outfile
    binsize=args.binsize
    countcol=args.countcol
    
    print("\n",end="")
    
    ref_fh=open(ref_infile,'r')
    
    frag2bin=dict()
    bin2frag=dict()
    frag2fragfrag=dict()

    print(sys.argv[0],": assigning fragments to bins ... ", end="")
    firstbin=0
    chr_lengths=dict()
    chr2index=dict()
    chr_index=0
    last_chr=None
    lastEnd=0
    
    map_out_fh=open(map_outfile,"w")
    for i,x in enumerate(ref_fh):
        a=x.rstrip("\n").split("\t")
        
        if (last_chr!=None): # intial skip
            
            if (a[0]!=last_chr): # if we are at a chr/chr transition
                
                if last_chr in chr_lengths.keys():
                    firstbin+=(chr_lengths[last_chr]/binsize)+1
                else:
                    
                    # BUG FOUND HJERE 10/23/2015
                    # NOAM AND BRYAN
                    # incorretly handle chr:chr transitions where only 1 frag exists, increase binoffset by 1 instead of increasing by # of bins in that frag
                    #
                    # chr_lengths[last_chr]=int(a[2])
                    # firstbin+=1
                    
                    chr_lengths[last_chr]=lastEnd
                    firstbin+=(chr_lengths[last_chr]/binsize)+1
                    
                chr2index[last_chr]=chr_index
                chr_index+=1
                
            else:
                chr_lengths[a[0]]=int(a[2])
          
           
        last_chr=a[0]
            
        midpoint=(int(a[1])+int(a[2]))/2
        b=(midpoint-1)/binsize+firstbin
        lastEnd=int(a[2])
        
        chr_len=None
        if last_chr in chr_lengths.keys():
            chr_len=chr_lengths[last_chr]
            
        frag2bin[int(a[4])]=b
        
        if b not in bin2frag:
            bin2frag[b]=list()
            
        bin2frag[b].append([a[0],a[1],a[2],a[3],a[4]])
        frag2fragfrag[int(a[4])]=i
        
        map_out_fh.write(str(a[4])+"\t"+str(b)+"\n")
        
    map_out_fh.close()
    ref_fh.close()
    print("done\n", end="")
    
    # handle last row
    chr_lengths[last_chr]=lastEnd
    chr2index[last_chr]=chr_index
    
    # keep the same order as the ref_infile
    chr_indices=sorted(chr2index, key=chr2index.get)

    print(sys.argv[0],": writing bin positions ... ", end="")
    bp_out_fh=open(bp_outfile,"w")
    b=0
    for c in chr_indices:
        numbins=chr_lengths[c]/binsize+1
        for i in xrange(numbins):
            binstart=i*binsize+1
            binend=min((i+1)*binsize,chr_lengths[c])
            print(b,c,binstart,binend,sep="\t",file=bp_out_fh)

            if b in bin2frag:
                frags=bin2frag[b]
                for f in frags:
                    midpoint=(int(f[1])+int(f[2]))/2
                    if c != f[0]:
                        sys.exit('error: frag/bin mismatch [chr]!\n'+str(b)+'\t'+str(c)+'\t'+str(binstart)+'\t'+str(binend)+'\n'+str(f[0])+'\t'+str(f[1])+'\t'+str(f[2])+'\t'+str(f[3])+'\t'+str(f[4])+'\n')
                    if midpoint < binstart or midpoint > binend:
                        sys.exit('error: frag/bin mismatch [midpoint]!\n'+str(b)+'\t'+str(c)+'\t'+str(binstart)+'\t'+str(binend)+'\n'+str(f[0])+'\t'+str(f[1])+'\t'+str(f[2])+'\t'+str(f[3])+'\t'+str(f[4])+'\n')
                        
            b+=1        
    bp_out_fh.close()
    print("done\n", end="")
    
    total_skipped=0
    total_kept=0
    
    print(sys.argv[0],": writing fragbin file ... ", end="")
   
    if infile.endswith('.gz'):
        in_fh=gzip.open(infile,'r')
    else:
        in_fh=open(infile,'r')
        
    out_fh=open(outfile,"w")
    for i,x in enumerate(in_fh):
    
        a=x.rstrip("\n").split("\t")
        frag1,frag2=int(a[0]),int(a[1])

        countstr=""
        count=1
        if countcol!=None:
            count=a[countcol]
            countstr="\t"+count
            
        if ((frag1 in frag2fragfrag) and (frag2 in frag2fragfrag)):
            fragfrag1,fragfrag2=frag2fragfrag[frag1],frag2fragfrag[frag2]
            bin1,bin2=frag2bin[frag1],frag2bin[frag2]
                
            if bin1>bin2:
                sys.exit('error: line#: '+str(i)+'\n'+str(x)+'\tfrag1('+str(frag1)+') / bin1('+str(bin1)+') > frag2('+str(frag2)+') / bin2('+str(bin2)+')')
            
            out_fh.write(str(frag1)+"\t"+str(frag2)+"\t"+str(fragfrag1)+"\t"+str(fragfrag2)+"\t"+str(bin1)+"\t"+str(bin2)+countstr+"\n")
            total_kept += int(count)
        else:
            total_skipped += int(count)
      
    out_fh.close()
    in_fh.close()
    print("done\n", end="")
    
    print(sys.argv[0],": total kept reads =",total_kept,"\n", end="")
    print(sys.argv[0],": total skipped reads =",total_skipped,"\n", end="")

if __name__=="__main__":
    main()
    