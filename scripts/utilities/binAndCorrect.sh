#!/bin/bash
#$ -V
#$ -cwd
#$ -o $HOME/sge_jobs_output/sge_job.$JOB_ID.out -j y
#$ -S /bin/bash
#$ -M bryan.lajoie@umassmed.edu
#$ -m beas

codeTree=${1}
inputFileString=${2}
cGenome=${3}
genomeFasta=${4}
excludeChromosomeString=${5}
binSize=${6}
outBase=${7}
parentJobDir=${8}

cMapping=$HOME/cMapping/$codeTree

mergeBinFiltered=$cMapping/mirnylib-API/mergeBinFiltered.py
iterCorr=$cMapping/mirnylib-API/iterCorr.py

#setup necessary paths
jobDir=$HOME/scratch/jobid_$JOB_ID

#create scratch space
mkdir ${jobDir}
mkdir -p ${jobDir}

array=(${inputFileString//,/ })
for (( i = 0 ; i < ${#array[@]} ; i++ ))
do
	hdf5File=${array[$i]}
	if [[ ${hdf5File} =~ "dekkerR/" ]] || [[ ${hdf5File} =~ "farline/" ]] || [[ ${hdf5File} =~ "isilon/" ]]
	then
		ssh hpcc03 "cp ${hdf5File} ${jobDir}/."
	else
		cp ${hdf5File} ${jobDir}/.
	fi
done

find ${jobDir}/*.hdf5 -type f -print > ${jobDir}/refined-HDF5-files.txt

# merge and bin refined HDF5 files
python ${mergeBinFiltered} -i ${jobDir}/refined-HDF5-files.txt -g ${genomeFasta} -b ${binSize} -o ${jobDir}/${outBase} -l ${jobDir}/totalReadsLogFile.txt

totalReads=`cat ${jobDir}/totalReadsLogFile.txt`
# iterative correct binned hdf5 file
python ${iterCorr} -i ${jobDir}/${outBase}-${binSize}.hdf5 -g ${genomeFasta} -b ${binSize} -n ${cGenome} -x ${excludeChromosomeString} -o ${jobDir}/${outBase} -R -d NA -t ${totalReads}

# copy results back to parent jobDir
cp ${jobDir}/*.matrix ${parentJobDir}/.
cp ${jobDir}/*.hdf5 ${parentJobDir}/.

touch ${parentJobDir}/state/${outBase}.complete
