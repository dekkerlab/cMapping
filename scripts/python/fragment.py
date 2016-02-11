
from __future__ import print_function

import numpy as np
import scipy as sp
import pdb
import h5py
import sys
import argparse
import time
import gzip

def main():

    parser=argparse.ArgumentParser(description='Convert fragment pairs to fragment pairs. fragment file does not have to be sorted',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-in',help='input fragment pairs file (format: frag1,frag2)',dest='infile',type=str,required=True)
    parser.add_argument('-in_ref',help='input reference fragment file',dest='ref_infile',type=str,required=True)
    parser.add_argument('-c',help='count column',dest='countcol',type=int,default=2)
    parser.add_argument('-out',help='output fragment file',dest='outfile',type=str,required=True)    
    parser.add_argument('-out_bp',help='output fragment position file',dest='bp_outfile',type=str,required=True)
    parser.add_argument('-out_map',help='output map frag to frag file',dest='map_outfile',type=str,required=True)    

    args=parser.parse_args()

    infile=args.infile
    ref_infile=args.ref_infile
    outfile=args.outfile 
    bp_outfile=args.bp_outfile
    map_outfile=args.map_outfile
    countcol=args.countcol

    print("\n",end="")
    
    ref_fh=open(ref_infile,'r')

    frag2bin=dict()
    
    print(sys.argv[0],": assigning fragments to fragments ... ", end="")
    
    ref_fh=open(ref_infile,'r')
    
    bp_out_fh=open(bp_outfile,"w")
    map_out_fh=open(map_outfile,"w")
    for i,x in enumerate(ref_fh):
        a=x.rstrip("\n").split("\t")
        
        frag2bin[int(a[4])]=i
        
        map_out_fh.write(str(a[4])+"\t"+str(i)+"\n")
        bp_out_fh.write(str(i)+"\t"+a[0]+"\t"+a[1]+"\t"+a[2]+"\n")
        
    bp_out_fh.close()    
    map_out_fh.close() 
    ref_fh.close()
    print("done\n", end="")
    
    total_skipped=0
    total_kept=0
    
    print(sys.argv[0],": writing fragfrag file ... ", end="")
    
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
        
        if ((frag1 in frag2bin) and (frag2 in frag2bin)):
            fragfrag1,fragfrag2=frag2bin[frag1],frag2bin[frag2]
            bin1,bin2=fragfrag1,fragfrag2
            
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
