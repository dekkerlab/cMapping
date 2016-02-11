#!/bin/bash
#$ -V
#$ -cwd
#$ -o $HOME/sge_jobs_output/sge_job.$JOB_ID.out -j y
#$ -S /bin/bash
#$ -M bryan.lajoie@umassmed.edu
#$ -m beas

cMapping=${1}
filesToMap=${2}
genomeFasta=${3}
jobName=${4}
outputName=${5}
statFile=${6}
nReads=${7}

#setup necessary paths
jobDir=$HOME/scratch/jobid_$JOB_ID
sleep 5

# needed external scripts
mergeMappedHDF5=$cMapping/mirnylib-API/mergeMappedFiles.py
mappedStats=$cMapping/mirnylib-API/getMappedFragStats.py
fragFilter=$cMapping/mirnylib-API/fragFilter.py

# merge mapped files together into raw MAPPED.HDF5
python ${mergeMappedHDF5} -i ${filesToMap} -g ${genomeFasta} -o ${outputName}
echo "DEBUG: python ${mergeMappedHDF5} -i ${filesToMap} -g ${genomeFasta} -o ${outputName}"

# get mapping results (DE,SC, etc)
nBothSideMapped=`python ${mappedStats} -i ${outputName}_mapped.hdf5 -r ${nReads} -o ${statFile}`
echo "DEBUG: python ${mappedStats} -i ${outputName}_mapped.hdf5 -r ${nReads} -o ${statFile}"

# filter RS sites, fill, remove redundant
python ${fragFilter} -i ${filesToMap} -g ${genomeFasta} -o ${outputName} -r ${nBothSideMapped}
echo "DEBUG: python ${fragFilter} -i ${filesToMap} -g ${genomeFasta} -o ${outputName} -r ${nBothSideMapped}"

touch ${outputName}.mergeMapped.complete