#!/bin/bash

configFile=${1}
chunkStart=${2}
chunkEnd=${3}
mapID=${4}
	
source ${configFile}

# set up job/task ID variables
jobID=${LSB_JOBID}
jobDir=${mapScratchDir}/cWorld__stage1-map__${UUID}__${mapID}__${LSB_JOBID}
mkdir -p ${jobDir}
# set up job/task ID variables

# set up perl/python/shell paths
novo25C=${cMapping}/perl/novo25C.pl

nMaps=0
for ((  c = ${chunkStart};  c <= ${chunkEnd};  c++  )) 
do
	#create a temporary shell to throw to background.
	mapJob=${jobDir}/${jobName}.c${c}.sh
	
	# load R and python modules
	echo "module load python/2.7.5 &> /dev/null" >> ${mapJob}
	echo "module load R/3.0.2 &> /dev/null" >> ${mapJob}
	
	side1ChunkFileName=${side1ShortFileName}.c${c}
	side2ChunkFileName=${side2ShortFileName}.c${c}
	
	#side 1
	side1chunkFile=${mapReduceDir}/chunks/${side1ChunkFileName}.gz
	side1fastqFile=${jobDir}/${side1ChunkFileName}.noMap.fastq.gz
	side1NovoOutputFile=${jobDir}/${side1ChunkFileName}.novoOutput
	echo "cp ${side1chunkFile} ${side1fastqFile}" >> ${mapJob}
	
	#side 2
	side2chunkFile=${mapReduceDir}/chunks/${side2ChunkFileName}.gz
	side2fastqFile=${jobDir}/${side2ChunkFileName}.noMap.fastq.gz
	side2NovoOutputFile=${jobDir}/${side2ChunkFileName}.novoOutput
	echo "cp ${side2chunkFile} ${side2fastqFile}" >> ${mapJob}
	
	if [[ ${aligner} = "novoCraft" ]]
	then
		# novoalign cannot (yet) handle gzipped files - decompress them
		# side1
		side1ReadsUnzipped=${jobDir}/${side1ChunkFileName}.i${currentIteration}.noMap.fastq
		echo "gunzip -c ${side1fastqFile} > ${side1ReadsUnzipped}" >> ${mapJob}
		echo "${alignmentSoftwarePath} ${alignmentOptions} ${optionalSide1AlignmentOptions} -F ${qvEncoding} -d ${genomePath} -f ${side1ReadsUnzipped} 2> ${side1NovoOutputFile}.alignerLog 1> ${side1NovoOutputFile}" >> ${mapJob}
		echo "rm ${side1ReadsUnzipped}" >> ${mapJob}
		# side2
		side2ReadsUnzipped=${jobDir}/${side2ChunkFileName}.i${currentIteration}.noMap.fastq
		echo "gunzip -c ${side2fastqFile} > ${side2ReadsUnzipped}" >> ${mapJob}
		echo "${alignmentSoftwarePath} ${alignmentOptions} ${optionalSide2AlignmentOptions} -F ${qvEncoding} -d ${genomePath} -f ${side2ReadsUnzipped} 2> ${side2NovoOutputFile}.alignerLog 1> ${side2NovoOutputFile}" >> ${mapJob}
		echo "rm ${side2ReadsUnzipped}" >> ${mapJob}
	else 
		echo "invalid aligner!"
		exit
	fi
	
	# copy alignment log file back to mapReduceDir log folder
	echo "cp ${side1NovoOutputFile}.alignerLog ${mapReduceDir}/aligner-log/." >> ${mapJob}
	echo "cp ${side2NovoOutputFile}.alignerLog ${mapReduceDir}/aligner-log/." >> ${mapJob}
	
	# process the pairs - extract validPairs
	echo "perl ${novo25C} -jn ${jobDir}/${jobName}.c${c} -s1 ${side1NovoOutputFile} -s2 ${side2NovoOutputFile} -cf ${configFile}" >> ${mapJob}
	
	# sort the valid pairs (fragIndex1,fragIndex2,mappedPos1,mappedPos2)
	echo "sort -k1,1 -k2,2 -o ${jobDir}/${jobName}.c${c}.validPair.txt ${jobDir}/${jobName}.c${c}.validPair.txt" >> ${mapJob}
	echo "gzip ${jobDir}/${jobName}.c${c}.validPair.txt" >> ${mapJob}
	echo "gzip ${jobDir}/${jobName}.c${c}.homoPair.txt" >> ${mapJob}
	
	# copy interaction assigmnet log files back to mapReduce dir
	echo "cp ${jobDir}/${jobName}.c${c}.error ${mapReduceDir}/error/. 2>/dev/null" >> ${mapJob}
	echo "cp ${jobDir}/${jobName}.c${c}.validPair.txt.gz ${mapReduceDir}/validPairs/." >> ${mapJob}	
	echo "cp ${jobDir}/${jobName}.c${c}.homoPair.txt.gz ${mapReduceDir}/homoPairs/." >> ${mapJob}	
	echo "cp ${jobDir}/${jobName}.c${c}.mapping.log ${mapReduceDir}/mapping-log/." >> ${mapJob}
	
	#create a file, signaling map completion
	echo "touch ${mapReduceDir}/state/${jobName}.c${c}" >> ${mapJob}
	maps[${nMaps}]=${jobName}.c${c}
	let nMaps++
	
	chmod 755 ${mapJob}
	${mapJob} &
	
done

#keep wrapper alive to wait for maps to finish (only wasting 1CPU here)
completeMaps=0
while [ ! ${completeMaps} -eq ${nMaps} ]
do
	completeMaps=0
	for ((  c = 0;  c < ${nMaps};  c++  )) 
	do		
		mapFile=${mapReduceDir}/state/${maps[${c}]}
		# echo "MAP waiting for... ${mapFile} ( ${nMaps} ) `date`"
		
		if [ -f ${mapFile} ]
		then
			let completeMaps++
		fi
	done	   
	sleep 5
done

# do clean up
if [ $debugModeFlag = 0 ]; then rm -rf ${jobDir}; fi