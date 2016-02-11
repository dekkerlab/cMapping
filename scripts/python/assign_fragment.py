

import argparse
import sys
import locale
locale.setlocale(locale.LC_ALL, 'en_US.UTF-8') 

def main():
    parser=argparse.ArgumentParser(description='Map reads to restriction fragments. Assumes both files are sorted by chr,start,end.',formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    parser.add_argument('-frags',help='restriction fragment file',dest='fragfile',type=str,required=True)
    parser.add_argument('-reads',help='read file',dest='readfile',type=str,required=True)
    parser.add_argument('-out',help='output file prefix',dest='outfile',type=str,required=True)
    parser.add_argument('-ig',help='characters to ignore',dest='ignorechrs',type=str)

    args=parser.parse_args()
    
    fragfile=args.fragfile
    readfile=args.readfile
    outfile=args.outfile
    ignorechrs=args.ignorechrs

    if ignorechrs==None:
        ignorechrs=''
        
    get_frag_pos = ( lambda x: (x[0].translate(None,ignorechrs).lower(),int(x[1]),int(x[2])) )
    get_read_pos = ( lambda x: (x[2].translate(None,ignorechrs).lower(),int(x[3]),int(x[3])) )
    
    if fragfile=='-':
        frag_fh=sys.stdin
    else:
        frag_fh=open(fragfile,'r')
        
    if readfile=='-':
        read_fh=sys.stdin
        out_mapped_fh=open(outfile+'.mapped.fragAssigned','w')
        read_count=None
    else:
        read_fh=open(readfile,'r')
        out_mapped_fh=open(outfile+'.fragAssigned','w')
        read_count = file_len(readfile)
        
    frag_iter=(i.rstrip("\n").split("\t") for i in frag_fh)
    read_iter=(i.rstrip("\n").split("\t") for i in read_fh)
    
    out_mapped_fh=open(outfile+'.mapped.fragAssigned','w')
    out_log_fh=open(outfile+'.log','w')

    c=0
    for i in intersection_iter(frag_iter,read_iter,get_frag_pos,get_read_pos):
        # tack onto READ line (FRAGID,FRAGSTART,FRAGEND)
        out_mapped_fh.write("\t".join(i[1]+[i[0][4]]+[i[0][1]]+[i[0][2]])+"\n")
        c=c+1

    out_log_fh.write(str(c)+" / "+str(read_count)+" reads mapped to a fragment.\n")
    
    if read_count!=None and c!=read_count:
        skipped_reads=read_count-c
        sys.stderr.write('\nERROR: '+str(c)+' / '+str(read_count)+' ['+str(skipped_reads)+'] reads skipped!\n\n')

    out_mapped_fh.close()
    out_log_fh.close()
        
    frag_fh.close()
    read_fh.close()




# output all pairs of intersecting loci

def intersection_iter(loc1_iter,loc2_iter,posf1,posf2):

    loc2_buffer=[]

    for loc1 in loc1_iter:

        loc1_chr,loc1_start,loc1_end=posf1(loc1)

        if loc1_start>loc1_end:
            sys.exit('loc1 start>end: '+str((loc1_chr,loc1_start,loc1_end))+')')

        # remove from buffer locations that have been passed

        new_loc2_buffer=[]
        
        for i in loc2_buffer:
            if i!=None:
                i_chr,i_start,i_end=posf2(i)
            if i==None or i_chr>loc1_chr or (i_chr==loc1_chr and i_end>=loc1_start):
                new_loc2_buffer.append(i)
         
        loc2_buffer=new_loc2_buffer

        # add to buffer locations that intersect
        
        while True:

            if len(loc2_buffer)>0:

                if loc2_buffer[-1]==None:
                    break
                
                last_chr,last_start,last_end = posf2(loc2_buffer[-1])
                
                if last_chr>loc1_chr:
                    break

                if last_chr==loc1_chr and last_start>loc1_end:
                    break

            try:

                newloc2=loc2_iter.next()
                
                newloc2_chr,newloc2_start,newloc2_end=posf2(newloc2)

                if newloc2_start>newloc2_end:
                    sys.exit('loc2 start>end: '+str((newloc2_chr,newloc2_start,newloc2_end)))

                # add location to buffer if relevant
                if newloc2_chr==None or newloc2_chr>loc1_chr or (newloc2_chr==loc1_chr and newloc2_end>=loc1_start):
                    loc2_buffer.append(newloc2)
              
            except StopIteration: # if loc2_iter ended

                loc2_buffer.append(None)

        # yield loc1 x loc2_buffer
            
        for loc2 in loc2_buffer[:-1]:
            yield loc1,loc2


def file_len(fname):
    i=0
    nonempty=False
    with open(fname) as f:
        for i, l in enumerate(f):
            pass
            nonempty=True
    
    if nonempty:
        return i + 1
    
    return i
    
    
if __name__=="__main__":
    main()
