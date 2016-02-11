#!/bin/sh

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
parseMultiMapped=$cMapping/perl/parseMultiMapped.pl
parseIterativeSam=$cMapping/perl/parseIterativeSam.pl
assumeCisAllele=$cMapping/perl/assumeCisAllele.pl
filterFragmentAssigned=$cMapping/perl/filterFragmentAssigned.pl
sam2tab=$cMapping/perl/sam2tab.pl
assignFragment=$cMapping/python/assign_fragment.py

nMaps=0
for ((  c = ${chunkStart};  c <= ${chunkEnd};  c++  )) 
do
	#create a temporary shell to throw to background.
	mapJob=${jobDir}/${jobName}.c${c}.sh
	
	# load R and python modules
	echo "module load python/2.7.5 &> /dev/null" >> ${mapJob}
	echo "module load R/3.0.2" >> ${mapJob}
	
	side1ChunkFileName=${side1FileName}.c${c}
	side2ChunkFileName=${side2FileName}.c${c}
	
	#side 1
	side1chunkFile=${mapReduceDir}/chunks/${side1ChunkFileName}
	side1fastqFile=${jobDir}/${side1ChunkFileName}
	side1SamFile=${jobDir}/${side1ChunkFileName}.sam
	echo "cp ${side1chunkFile} ${side1fastqFile}.i0.noMap.fastq" >> ${mapJob}
	
	#side 2
	side2chunkFile=${mapReduceDir}/chunks/${side2ChunkFileName}
	side2fastqFile=${jobDir}/${side2ChunkFileName}
	side2SamFile=${jobDir}/${side2ChunkFileName}.sam
	echo "cp ${side2chunkFile} ${side2fastqFile}.i0.noMap.fastq" >> ${mapJob}
	
	# run the iterative mapping
	i=${iterativeMappingStart}
	lastIteration=0
	
	#echo -e "starting iterative mapping ( ${iterativeMappingStart} - ${iterativeMappingEnd} ) [${iterativeMappingStep}]...";
	
	while [ $i -le $iterativeMappingEnd ]
	do 
		
		currentIteration=0
		if [ $i -eq $iterativeMappingStart ]
		then
			currentIteration=0
		else 
			currentIteration=$lastIteration
		fi
		
		trimAmount=$(( $readLength - $i ))
		bowtieIterativeMappingOptions=""
		novocraftIterativeMappingOptions=""
		if [[ $iterativeMappingFlag = 1 ]]
		then
			bowtieIterativeMappingOptions="-3 ${trimAmount}"
			novocraftIterativeMappingOptions="-n ${trimAmount}"
		fi
					
		side1Reads=${side1fastqFile}.i${currentIteration}.noMap.fastq
		side2Reads=${side2fastqFile}.i${currentIteration}.noMap.fastq
		side1Sam=${side1fastqFile}.i${i}.sam
		side2Sam=${side2fastqFile}.i${i}.sam
		side1CondensedSam=${side1fastqFile}.i${i}.condensed.sam
		side2CondensedSam=${side2fastqFile}.i${i}.condensed.sam
		
		if [ $currentIteration != 0 ] && [ $debugModeFlag = 0 ]; then echo "rm ${jobDir}/${side1ChunkFileName}.i${currentIteration}.unMapped.sam" >> ${mapJob}; fi
		if [ $currentIteration != 0 ] && [ $debugModeFlag = 0 ]; then echo "rm ${jobDir}/${side2ChunkFileName}.i${currentIteration}.unMapped.sam" >> ${mapJob}; fi
		
		echo "mkdir -p ${mapReduceDir}/stats/i${i}" >> ${mapJob}
		
		if [[ ${aligner} = "bowtie2" ]]
		then
			echo "${alignmentSoftwarePath} --no-hd --no-sq --mm --qc-filter --${qvEncoding} ${alignmentOptions} ${optionalSide1AlignmentOptions} -x ${genomePath} -q ${side1Reads} ${bowtieIterativeMappingOptions} -S ${side1Sam} > ${side1Sam}.alignerLog 2>&1" >> ${mapJob}
			echo "${alignmentSoftwarePath} --no-hd --no-sq --mm --qc-filter --${qvEncoding} ${alignmentOptions} ${optionalSide2AlignmentOptions} -x ${genomePath} -q ${side2Reads} ${bowtieIterativeMappingOptions} -S ${side2Sam} > ${side2Sam}.alignerLog 2>&1" >> ${mapJob}
		elif [[ ${aligner} = "novoCraft" ]]
		then
			echo "${alignmentSoftwarePath} ${alignmentOptions} ${optionalSide1AlignmentOptions} -F ${qvEncoding} -d ${genomePath} -f ${side1Reads} -o SAM ${novocraftIterativeMappingOptions} 2> ${side1Sam}.alignerLog 1> ${side1Sam}" >> ${mapJob}
			echo "${alignmentSoftwarePath} ${alignmentOptions} ${optionalSide2AlignmentOptions} -F ${qvEncoding} -d ${genomePath} -f ${side2Reads} -o SAM ${novocraftIterativeMappingOptions} 2> ${side2Sam}.alignerLog 1> ${side2Sam}" >> ${mapJob}
		else 
			echo "invalid aligner!"
			exit
		fi
		
		# copy alignment log file back to mapReduceDir log folder
		echo "cp ${side1Sam}.alignerLog ${mapReduceDir}/aligner-log/." >> ${mapJob}
		echo "cp ${side2Sam}.alignerLog ${mapReduceDir}/aligner-log/." >> ${mapJob}
		
		# optinonal SNP parsing goes here	
		if [[ ${snpModeFlag} = 1 ]]
		then
			echo "perl ${parseMultiMapped} -is ${side1Sam} -os ${side1CondensedSam} -mrd ${minimumReadDistance}" >> ${mapJob}
			if [ $debugModeFlag = 1 ]; then echo "cp ${side1Sam} ${side1Sam}.preCondensed.sam" >> ${mapJob}; fi
			echo "cp ${side1CondensedSam} ${side1Sam}" >> ${mapJob}
		fi
		
		echo "perl ${parseIterativeSam} -is ${side1Sam} -if ${side1Reads} -in ${side1ChunkFileName} -iter ${i} -side 1 -o ${jobDir}" >> ${mapJob}		
		if [ $debugModeFlag = 0 ]; then echo "rm ${side1Sam}" >> ${mapJob}; fi
		if [ $debugModeFlag = 0 ]; then echo "rm ${side1Reads}" >> ${mapJob}; fi
		echo "cat ${jobDir}/${side1ChunkFileName}.i${i}.mapped.sam >> ${side1SamFile}" >> ${mapJob} # running cat of all mapped same entries
		if [ $debugModeFlag = 0 ]; then echo "rm ${jobDir}/${side1ChunkFileName}.i${i}.mapped.sam" >> ${mapJob}; fi
		echo "cp ${jobDir}/${side1ChunkFileName}.i${i}.stats ${mapReduceDir}/stats/i${i}/." >> ${mapJob}
		
		# optinonal SNP parsing goes here	
		if [[ ${snpModeFlag} = 1 ]]
		then
			echo "perl ${parseMultiMapped} -is ${side2Sam} -os ${side2CondensedSam}" >> ${mapJob}
			if [ $debugModeFlag = 1 ]; then echo "cp ${side2Sam} ${side2Sam}.preCondensed.sam" >> ${mapJob}; fi
			echo "cp ${side2CondensedSam} ${side2Sam}" >> ${mapJob}
		fi
		
		echo "perl ${parseIterativeSam} -is ${side2Sam} -if ${side2Reads} -in ${side2ChunkFileName} -iter ${i} -side 2 -o ${jobDir}" >> ${mapJob}
		if [ $debugModeFlag = 0 ]; then echo "rm ${side2Sam}" >> ${mapJob}; fi
		if [ $debugModeFlag = 0 ]; then echo "rm ${side2Reads}" >> ${mapJob}; fi
		echo "cat ${jobDir}/${side2ChunkFileName}.i${i}.mapped.sam >> ${side2SamFile}" >> ${mapJob} # running cat of all mapped same entries
		if [ $debugModeFlag = 0 ]; then echo "rm ${jobDir}/${side2ChunkFileName}.i${i}.mapped.sam" >> ${mapJob}; fi
		echo "cp ${jobDir}/${side2ChunkFileName}.i${i}.stats ${mapReduceDir}/stats/i${i}/." >> ${mapJob}
		
		lastIteration=$i
		
		i=$(( $i + $iterativeMappingStep ))
		if [ $i -gt $iterativeMappingEnd ] && [ $(( $i - $iterativeMappingEnd )) -lt $iterativeMappingStep ]
		then
			i=$readLength
		fi
	done
	
	# cat on the last iterativeMappings unmapped reads (this makes the sam file whole)
	
	# copy back header information to mapReduce dir
	if [ $c = $chunkStart ]
	then
		echo "cp ${jobDir}/${side1ChunkFileName}.iterativeMapping.header ${mapReduceDir}/stats/iterativeMapping.header" >> ${mapJob}
	fi
	
	echo "cat ${jobDir}/${side1ChunkFileName}.i${iterativeMappingEnd}.unMapped.sam >> ${side1SamFile}" >> ${mapJob}
	echo "cat ${jobDir}/${side2ChunkFileName}.i${iterativeMappingEnd}.unMapped.sam >> ${side2SamFile}" >> ${mapJob}
	
	# rm all iterative files
	if [ $debugModeFlag = 0 ]; then echo "rm ${jobDir}/${side1ChunkFileName}.i[0-9]*.*" >> ${mapJob}; fi
	if [ $debugModeFlag = 0 ]; then echo "rm ${jobDir}/${side2ChunkFileName}.i[0-9]*.*" >> ${mapJob}; fi

	# sort the sam files by the QUERY NAME (readID)
	echo "sort -k 1,1 ${side1SamFile} -o ${side1SamFile}" >> ${mapJob}
	echo "sort -k 1,1 ${side2SamFile} -o ${side2SamFile}" >> ${mapJob}
	
	# copy back mapped sam files 
	if [ $debugModeFlag = 1 ]; then echo "cp ${side1SamFile} ${mapReduceDir}/sam/." >> ${mapJob}; fi
	if [ $debugModeFlag = 1 ]; then echo "cp ${side2SamFile} ${mapReduceDir}/sam/." >> ${mapJob}; fi

	# if snp mode, then run assumeCisAllele override script
	if [[ ${snpModeFlag} = 1 ]]
	then
		if [ $debugModeFlag = 1 ]; then echo "cp ${side1SamFile} ${side1SamFile}.preCisAlleled.sam" >> ${mapJob}; fi
		if [ $debugModeFlag = 1 ]; then echo "cp ${side2SamFile} ${side2SamFile}.preCisAlleled.sam" >> ${mapJob}; fi
		echo "perl ${assumeCisAllele} -i1 ${side1SamFile} -i2 ${side2SamFile} -jn ${jobDir}/${jobName}.c${c}" >> ${mapJob}
		echo "cp ${jobDir}/${jobName}.c${c}.alleleOverride.log ${mapReduceDir}/allele-log/." >> ${mapJob}
		echo "mv ${side1SamFile}.cisAlleled.sam ${side1SamFile}" >> ${mapJob}
		echo "mv ${side2SamFile}.cisAlleled.sam ${side2SamFile}" >> ${mapJob}
	fi

	#NOAM's program goes here - sam to new format
	echo "cat ${side1SamFile} | perl ${sam2tab} ${side1SamFile}.unMapped | sort -k 3,3 -k 4,4n | python ${assignFragment} -frags ${mapReduceRestrictionFragmentFile} -reads - -out ${side1SamFile} -ig '_-'" >> ${mapJob}
	echo "cat ${side2SamFile} | perl ${sam2tab} ${side2SamFile}.unMapped | sort -k 3,3 -k 4,4n | python ${assignFragment} -frags ${mapReduceRestrictionFragmentFile} -reads - -out ${side2SamFile} -ig '_-'" >> ${mapJob}
	echo "cat ${side1SamFile}.mapped.fragAssigned ${side1SamFile}.unMapped > ${side1SamFile}.fragAssigned" >> ${mapJob}
	echo "cat ${side2SamFile}.mapped.fragAssigned ${side2SamFile}.unMapped > ${side2SamFile}.fragAssigned" >> ${mapJob}
	if [ $debugModeFlag = 0 ]; then echo "rm ${side1SamFile}.mapped.fragAssigned ${side1SamFile}.unMapped" >> ${mapJob}; fi
	if [ $debugModeFlag = 0 ]; then echo "rm ${side2SamFile}.mapped.fragAssigned ${side2SamFile}.unMapped" >> ${mapJob}; fi
	
	# Re sort the fragAssigned files by READ ID
	echo "sort -k 6,6 ${side1SamFile}.fragAssigned -o ${side1SamFile}.fragAssigned " >> ${mapJob}
	echo "sort -k 6,6 ${side2SamFile}.fragAssigned -o ${side2SamFile}.fragAssigned " >> ${mapJob}
	
	# perform the interaction assignment from fragAssigned files
	echo "perl ${filterFragmentAssigned} -i1 ${side1SamFile}.fragAssigned -i2 ${side2SamFile}.fragAssigned -jn ${jobDir}/${jobName}.c${c}" >> ${mapJob}

	# cleaup fragAssigned files
	if [ $debugModeFlag = 0 ]; then echo "rm ${side1SamFile}.fragAssigned" >> ${mapJob}; fi
	if [ $debugModeFlag = 0 ]; then echo "rm ${side2SamFile}.fragAssigned" >> ${mapJob}; fi
	
	# sort the valid pairs (fragIndex1,fragIndex2,mappedPos1,mappedPos2)
	echo "sort -k6,6n -k12,12n -k3,3n -k9,9n -o ${jobDir}/${jobName}.c${c}.validPair.txt ${jobDir}/${jobName}.c${c}.validPair.txt" >> ${mapJob}
	echo "gzip ${jobDir}/${jobName}.c${c}.validPair.txt" >> ${mapJob}
	
	# copy interaction assigmnet log files back to mapReduce dir
	echo "cp ${jobDir}/${jobName}.c${c}.error ${mapReduceDir}/error/. 2>/dev/null" >> ${mapJob}
	echo "cp ${jobDir}/${jobName}.c${c}.moleculeSize.log ${mapReduceDir}/moleculeSize-log/. 2>/dev/null" >> ${mapJob}
	echo "cp ${jobDir}/${jobName}.c${c}.strandBias.log ${mapReduceDir}/strandBias-log/. 2>/dev/null" >> ${mapJob}
	echo "cp ${jobDir}/${jobName}.c${c}.validPair.txt.gz ${mapReduceDir}/validPairs/. 2>/dev/null" >> ${mapJob}	
	echo "cp ${jobDir}/${jobName}.c${c}.interaction.log ${mapReduceDir}/interaction-log/. 2>/dev/null" >> ${mapJob}	
	echo "cp ${jobDir}/${jobName}.c${c}.mapping.log ${mapReduceDir}/mapping-log/. 2>/dev/null" >> ${mapJob}
	
	# purge any/all loaded modules
	echo "module purge" >> ${mapJob}
	
	# delete chunk files
	echo "rm ${side1chunkFile}" >> ${mapJob}
	echo "rm ${side2chunkFile}" >> ${mapJob}
	
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