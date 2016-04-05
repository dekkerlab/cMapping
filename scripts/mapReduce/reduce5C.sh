#!/bin/bash

appendToConfigFile() {
	configFile=${1}
	variableName=${2}
	variableValue=${3}
	
	echo "${variableName}=\"${variableValue}\"" >> ${configFile}
}		

checkForErrors() {
	
	echo -e "\nmapReduce (${jobID}) - checking for errors...";
	
	for ((  i = 0;  i < ${nMaps};  i++  )) 
	do
		errorFile=${mapReduceDir}/error/${maps[${i}]}.error
		if [ -f ${errorFile} ]
		then
			echo -e "\n\tmapReduce reported error!\n\t\t$errorFile\n\t\texiting...\n"
			ssh ghpcc06 "source /etc/profile; bkill ${jobID}"
			exit
		fi
	done
	
	echo -e "\tAOK\n";
	
}
		
#take a input file to work on
configFile=${1}
jobID=${2}
jobDir=${3}

source ${configFile}

# load R module
module load R/3.0.2 &> /dev/null
module load python/2.7.5 &> /dev/null

# set up perl/python/shell paths
map=${cMapping}/mapReduce/map5C.sh
mapReduceHome=${cMapping}/mapReduce
splitFile=${cMapping}/perl/splitFile.pl
initialEmail=${cMapping}/perl/emailInitial.pl
completionEmail=${cMapping}/perl/emailResults.pl
aggregrateLogFile=${cMapping}/perl/aggregrateLogFile.pl
create5CMappingLog=${cMapping}/perl/create5CMappingLog.pl
collapse5CValidPair=${cMapping}/perl/collapse5CValidPairs.pl

# set up perl/python/shell paths

jobDir=${jobDir/%\//} #strip file / from jobDir
mapReduceDir=${jobDir}/mapReduce

appendToConfigFile ${configFile} "mapReduceDir" ${mapReduceDir}

#create scratch space
mkdir -p ${mapReduceDir}
mkdir -p ${mapReduceDir}/state
mkdir -p ${mapReduceDir}/chunks
mkdir -p ${mapReduceDir}/novoOutput
mkdir -p ${mapReduceDir}/validPairs
mkdir -p ${mapReduceDir}/homoPairs
mkdir -p ${mapReduceDir}/mapping-log
mkdir -p ${mapReduceDir}/aligner-log
mkdir -p ${mapReduceDir}/novoOutput
mkdir -p ${mapReduceDir}/log
mkdir -p ${mapReduceDir}/error
mkdir -p ${mapReduceDir}/plots

# send initial email
perl ${initialEmail} -j ${jobID} -jn ${mapReduceDir}/log/${jobName} -q ${quietModeFlag} -cf ${configFile}

# split the input file into N chunks
nSide1Chunks=`perl ${splitFile} -i ${jobDir}/${side1FileName} -s ${splitSize} -g 4 -o ${mapReduceDir}/chunks`
nSide2Chunks=`perl ${splitFile} -i ${jobDir}/${side2FileName} -s ${splitSize} -g 4 -o ${mapReduceDir}/chunks`

nChunks=0
nJobs=0
if [ $nSide1Chunks -ne $nSide2Chunks ]
then
	echo "ERROR - files are not of equal size $nSide1Chunks / $nSide2Chunks"
	echo "exiting..."
	ssh ghpcc06 "source /etc/profile; bkill ${jobID}"
	exit
else 
	nChunks=$nSide1Chunks
	let "nJobs = (($nChunks/8)+1)";
fi

# now clean up input fastq files (to save space)
if [ $debugModeFlag = 0 ]; then rm ${jobDir}/${side1FileName}; fi
if [ $debugModeFlag = 0 ]; then rm ${jobDir}/${side2FileName}; fi 

#submit all the map segments.
nMaps=0
for ((  i = 0;  i < ${nJobs};  i++  )) 
do
	let "chunkStart = $i * 8";
	let "chunkEnd = ((($i+1) * 8)-1)";
	
	
	#if chunkEnd > #chunks - correct.
	if [ $chunkEnd -gt $nChunks ]
	then
		chunkEnd=${nChunks}
	fi
	let "nTasks = (($chunkEnd - $chunkStart)+1)"
		
	for ((  i2 = ${chunkStart};  i2 <= ${chunkEnd};  i2++  )) 
	do	
		maps[${nMaps}]=${jobName}.c${i2}
		let nMaps++
	done
	
	mapID=`uuidgen | rev | cut -d '-' -f 1`
	let adjustedMapMemoryNeededMegabyte=($mapMemoryNeededMegabyte+$nTasks-1)/$nTasks; # adjust memory usage by nCPU requested
	bsub -n ${nTasks} -q $mapQueue -m blades -R "span[hosts=1]" -R "rusage[mem=$adjustedMapMemoryNeededMegabyte:tmp=$mapScratchSize]" -W $mapTimeNeeded -J mapHiC -N -u $userEmail -o $userHomeDirectory/lsf_jobs/LSB_%J.log -e $userHomeDirectory/lsf_jobs/LSB_%J.err -Ep "${cMapping}/scripts/garbageCollectTmp.sh ${UUID} ${mapID} $userHomeDirectory/lsf_jobs" ${map} ${configFile} ${chunkStart} ${chunkEnd} ${mapID}
	
	sleep 5
done

#now look for maps to report back that they are complete.
completeMaps=0
while [ ${completeMaps} -lt ${nMaps} ]
do
	completeMaps=0
	for ((  i = 0;  i < ${nMaps};  i++  )) 
	do		
		mapFile=${mapReduceDir}/state/${maps[${i}]}
		
		if [ -f ${mapFile} ]
		then
			let completeMaps++
		fi
	done	   
	sleep 5
done

# check for any MAP errors reported
checkForErrors

gunzip ${mapReduceDir}/validPairs/${jobName}.c*.validPair.txt.gz
sort -m -k1,1 -k2,2 -o ${mapReduceDir}/validPairs/${jobName}.validPair.txt ${mapReduceDir}/validPairs/${jobName}.c*.validPair.txt
if [ $debugModeFlag = 0 ]; then rm ${mapReduceDir}/validPairs/${jobName}.c*.validPair.txt; fi

# collapse valid pairs
nFinalValidPairs=`perl ${collapse5CValidPair} -jn ${mapReduceDir}/validPairs/${jobName} -i ${mapReduceDir}/validPairs/${jobName}.validPair.txt`
appendToConfigFile ${configFile} "nFinalValidPairs" ${nFinalValidPairs}
gzip ${mapReduceDir}/validPairs/${jobName}.validPair.txt
gzip ${mapReduceDir}/validPairs/${jobName}.validPair.itx

# combine all chunk stats + calculate mapping log info (U + NM + MM()
perl ${aggregrateLogFile} -i ${mapReduceDir}/mapping-log/ -jn ${mapReduceDir}/mapping-log/${jobName}
cp ${mapReduceDir}/mapping-log/${jobName}.mapping.log ${mapReduceDir}/log/.

# summarize all data and produce main email/log file
perl ${create5CMappingLog} -jn ${mapReduceDir}/log/${jobName} -mlf ${mapReduceDir}/log/${jobName}.mapping.log -cf ${configFile}

# zip of /plots and /log
cp ${configFile} ${mapReduceDir}/plots/. 
tar -czvf ${jobDir}/${jobName}.tar.gz -C ${mapReduceDir}/ log/ plots/ > /dev/null

# copy tarball back to /plots to email out
cp ${jobDir}/${jobName}.tar.gz ${mapReduceDir}/plots/. 

# send out email
perl ${completionEmail} -j ${jobID} -jn ${mapReduceDir}/log/${jobName} -lf ${mapReduceDir}/log/${jobName}.end.mappingLog.txt -q ${quietModeFlag} -cf ${configFile} -pf ${mapReduceDir}/plots/

# copy results back to main project dir
cp ${mapReduceDir}/validPairs/${jobName}.validPair.itx.gz ${jobDir}/.
cp ${mapReduceDir}/validPairs/${jobName}.validPair.txt.gz ${jobDir}/.

# do clean up
if [ $debugModeFlag = 0 ]; then rm -rf ${mapReduceDir}/; fi
