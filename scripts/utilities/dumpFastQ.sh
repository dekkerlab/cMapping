#!/bin/bash

#BSUB -n 1
#BSUB -R rusage[mem=1024] # ask for 2GB per job slot, or 8GB total
#BSUB -W 24:00
#BSUB -q long 

sraFile=${1}

# load modules
module load sratoolkit/2.3.4-2

fastq-dump --split-3 --gzip ${sraFile}

