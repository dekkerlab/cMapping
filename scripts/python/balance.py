
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
    parser.add_argument('-or','--output_relative', dest='output_relative', action='store_true', help='output file relative to input file path')
    parser.add_argument('-f',help='output factor file',dest='factorfile',type=str,required=False)
    parser.add_argument('-b',help='block size (default: hdf chunk size)',dest='blocksize',type=int)
    parser.add_argument('-t',help='balancing threshold',dest='threshold',type=float,default=1e-5)
    parser.add_argument('-s',help='minimal sum threshold',dest='minimal_sum',type=float,default=1e-5)
    parser.add_argument('-ddt',help='deltadelta threshold',dest='delta_delta_limit',type=float,default=1e-6)
    parser.add_argument('-etl',help='elapsed time limit',dest='elapsed_time_limit',type=float,default=129600)
    parser.add_argument('-mi',help='max iterations',dest='max_iterations',type=float,default=10000)
    parser.add_argument('-nan',help='replace isolated isolated nans with this value (default: import from neighborhood)',dest='nan_val',type=float)
    parser.add_argument('-d',help='ignore diagonal in factor calculation',dest='ignore_diagonal',action='store_true')
    
    args=parser.parse_args()

    infile=args.infile
    outfile=args.outfile
    output_relative=args.output_relative
    factorfile=args.factorfile
    blocksize=args.blocksize
    threshold=args.threshold
    delta_delta_limit=args.delta_delta_limit
    elapsed_time_limit=args.elapsed_time_limit
    max_iterations=args.max_iterations
    ignore_diagonal=args.ignore_diagonal
    nan_val=args.nan_val
    minimal_sum=args.minimal_sum

    print("\n",end="")
    
    infile_name=os.path.basename(infile)
    if output_relative:
       infile_name=infile
    
    infile_name=re.sub(".hdf5", "", infile_name)
    
    inhdf=h5py.File(infile,'r')
    
    A=inhdf['interactions']
    n=A.shape[0]
    
    # attrs
    genome=inhdf.attrs['genome'][:]
    # datasets
    bin_positions=inhdf['bin_positions'][:]
    chr_bin_range=inhdf['chr_bin_range'][:]
    chrs=inhdf['chrs'][:]
    factors=np.ones(n,dtype='float64')
    if "balance_factors" in inhdf.keys():
        factors=inhdf['balance_factors'][:]

    # matrix shape
    nrow=inhdf['interactions'].shape[0]
    ncol=inhdf['interactions'].shape[1]
    
    # calculate optimal block size
    itx_dtype=inhdf['interactions'].dtype
    itx_dtype_size=itx_dtype.itemsize
    hdf_blocksize=inhdf['interactions'].chunks[0]
    
    # ensure symmetrical
    if nrow!=ncol:
        sys.exit('error: non-symmetrical matrix found!')
    n=nrow=ncol
    
    # build chr lookup dict
    chr_dict={}
    for i,c in enumerate(chrs):
        chr_dict[c]=i
        
    if outfile==None:
        outfile=infile_name+'.balanced.hdf5'
        
    if factorfile==None:
        factorfile=infile_name+'.factors'
        
    print(sys.argv[0],": matrix ",n,"x",n,"\n",end="")
    if blocksize==None:
        blocksize=inhdf['interactions'].chunks[0]

    # hdf5 is copied, and then nans in the copy are replaced with numbers (just for balancing)
    
    print(sys.argv[0],": copying hdf file ... ", end="")
    shutil.copy(infile,outfile)
    print("done\n", end="")
    
    outhdf=h5py.File(outfile)
    
    B=outhdf['interactions']
        
    # find nan rowcols
    print(sys.argv[0],": searching for nan rows ... ", end="")
    nan_rowcols=np.array([],dtype=bool)
    for i in np.arange(0,n,blocksize):
        nan_rowcols=np.r_[nan_rowcols,i+np.nonzero(np.all(np.isnan(A[i:i+blocksize,:]),1))[0]]
    print("done\n", end="")
    
    # this is a test...
    nan_rowcols_mask=np.zeros(n,dtype=bool)
    nan_rowcols_mask[nan_rowcols]=True
    
    n_nan_rowcols=len(nan_rowcols)
    print(sys.argv[0],": found ",n_nan_rowcols," nan row/cols.\n", end="")
    
    print(sys.argv[0],": replacing nan rows ... ", end="")
    # replace nan row cols in B with 0 for icing
    # dumps row stripe into memory, controled by blocksize
    for i in xrange(0,n,blocksize):
        current_block=B[i:i+blocksize,:]
        tmp_nan_mask=nan_rowcols_mask[i:i+blocksize]
        
        if np.nansum(tmp_nan_mask) != 0:
            # nan rows in rowstripe
            current_block[tmp_nan_mask,:]=0
        
        # nan _all_ columns in rowstripe
        current_block[:,nan_rowcols]=0

        # if specified, replace diagonal with 0
        if ignore_diagonal:
            di = np.arange(current_block.shape[0])
            di_ind = [di,di+i]
            
            current_block[di_ind]=0

        B[i:i+blocksize,:]=current_block
        
    print("done\n", end="")
    
    print(sys.argv[0],": calculating nan replacements (",nan_val,") ... ", end="")
    # calculate isolated nan replacements
    ndist=1 # neighbor max distance
    nans=np.array([[],[]],dtype=int).T
    for i in np.arange(0,n,blocksize):
        nans=np.r_[nans,np.c_[np.nonzero(np.isnan(B[i:i+blocksize,:]))]+np.array([i,0])]
    
    nan_vals=[]
    for i in nans:
        if nan_val==None:
            neighbors=A[max(i[0]-ndist,0):i[0]+ndist+1,max(i[1]-ndist,0):i[1]+ndist+1]
            nan_vals.append(nanmean(neighbors))
        else:
            nan_vals.append(nan_val)
    print("done\n", end="")
    
    nan_vals=np.array(nan_vals)
    
    if np.any(np.isnan(nan_vals)):
        sys.exit('imputation failed')
    
    print(sys.argv[0],": replacing isolated nans ... ", end="")
    # replace isolated nans in B
    for i in range(nans.shape[0]):
        B[nans[i,0],nans[i,1]]=nan_vals[i]
    print("done\n", end="")
    
    start_time=time.time()
    print(sys.argv[0],": starting balance ... \n", end="")
    factors,iterations,small_means,delta,delta_bin=balance(B,threshold=threshold,blocksize=blocksize,ignore_diagonal=ignore_diagonal,minimal_sum=minimal_sum,max_iterations=max_iterations,delta_delta_limit=delta_delta_limit,elapsed_time_limit=elapsed_time_limit)
    print(sys.argv[0],": finished",str(iterations),"iterations in",time.time()-start_time,"seconds")
    print(sys.argv[0],": delta (",str(delta)," | ",str(delta_bin),") vs threshold (",str(threshold),")")
        
    # output
    f_out_fh=open(factorfile,"w")
    for i,b in enumerate(bin_positions):
        print(str(i)+"\t"+chrs[bin_positions[i,0]]+"\t"+str(bin_positions[i,1])+"\t"+str(bin_positions[i,2])+"\t"+str(factors[i]),file=f_out_fh)
    f_out_fh.close()
    
    # log factors into hdf5
    if "balance_factors" not in outhdf.keys():
        outhdf.create_dataset('balance_factors',data=factors,dtype='float64')
    else:
        outhdf['balance_factors'][:]=factors
        
    # apply factors to originl A
    for i in np.arange(0,n,blocksize):
        B[i:i+blocksize,:]=(A[i:i+blocksize,:]/factors)/factors[i:i+blocksize][None].T
    
    if ignore_diagonal:
        # re-mask diagonal, if user specified (cleanup)
        for i in xrange(0,n,blocksize):
            current_block=B[i:i+blocksize,:]
            
            di = np.arange(current_block.shape[0])
            di_ind = [di,di+i]
            
            current_block[di_ind]=np.nan
            
            B[i:i+blocksize,:]=current_block
        print("done\n", end="")
    
    outhdf.close()
    
    inhdf.close()
    
    
def nanmean(x):
    return np.nansum(x)/np.sum(~np.isnan(x))

def balance(A,threshold=1e-5,blocksize=None,minimal_sum=1e-5,ignore_diagonal=False,max_iterations=10000,delta_delta_limit=1e-6,elapsed_time_limit=129600):
    
    start_time=time.time()
    
    n=A.shape[0]

    if blocksize==None or blocksize>n or blocksize<1:
        blocksize=n
                 
    axis=0
    factors=[np.ones(n,dtype='float64'),np.ones(n,dtype='float64')]
    
    factors_final=np.ones(n,dtype='float64')
    delta=np.inf
    delta_bin=np.nan
    
    if n>50000:
        max_iterations=100
        print("\tsetting max_iterations = ",max_iterations,"\n", end="")

    c=0
    last_delta=None
    delta_delta=1
    continue_flag=1
    
    while((delta>threshold) and (c < max_iterations) and (continue_flag == 1)):
        
        elapsed_time=time.time()-start_time
        iteration_start=time.time()
        
        if blocksize<n:
            current_sum=np.zeros(n)

            for i in np.arange(0,n,blocksize):
                slicer=[np.s_[:],np.s_[:]]
                slicer[1-axis]=np.s_[i:i+blocksize]
                slicer=tuple(slicer)
                sliced_factors=factors[:]
                sliced_factors[axis]=factors[axis][i:i+blocksize]
                sliced_A=A[slicer][:] # sliced_A is now in RAM but could be either a copy (if A is hdf) or a reference (if A is a numpy array)
                
                current_sum[i:i+blocksize]=np.sum((sliced_A/sliced_factors[0])/sliced_factors[1][None].T,axis)

        else:
            current_sum = np.sum((A/factors[0])/factors[1][None].T,axis)
            
        small_sums=current_sum<minimal_sum
        counts=n*np.ones(n)-np.sum(small_sums)
        if ignore_diagonal:
            counts-=1
            
        with np.errstate(invalid='ignore'):
            current_mean=current_sum/counts
            
        current_mean[small_sums]=1.0
        factors[axis]*=current_mean
        
        last_delta=delta
        
        delta=np.max(np.abs(current_mean-1.))       
        delta_bin=np.argmax(np.abs(current_mean-1.))
        if last_delta!=None:
            delta_delta=last_delta-delta
        
        iteration_time=time.time()-iteration_start
        
        if(((delta_delta > 0) and (delta_delta < delta_delta_limit)) or (elapsed_time > elapsed_time_limit)):
            continue_flag=0
            
        print("\titeration #"+str(c)+"\tlast_delta: "+str(last_delta)+"\tdelta: "+str(delta)+"\tdelta_bin: "+str(delta_bin)+"\telapsed_time: "+str(elapsed_time)+" seconds\tdelta_delta: "+str(delta_delta)+"\n",end="")
        
        axis=1-axis

        c+=1
        

    final_factors=np.sqrt(factors[0]*factors[1])
    
    return final_factors,c,small_sums,delta,delta_bin
    
if __name__=="__main__":
    main()