#!/bin/bash

appendToConfigFile() {
	configFile=${1}
	variableName=${2}
	variableValue=${3}
	
	echo "${variableName}=\"${variableValue}\"" >> ${configFile}
}
		
configFile=${1}

source ${configFile}

# set up perl/python/shell paths
collapse5CValidPair=${cMapping}/perl/collapse5CValidPairs.pl
create5CLogFile=${cMapping}/perl/create5CLogFile.pl

# set up job/task ID variables
jobDir=${reduceScratchDir}/cWorld__stage2-rdc__${UUID}__${reduceID}__${LSB_JOBID}
mkdir -p ${jobDir}

appendToConfigFile ${configFile} "parentJobDir" ${jobDir}

# setup job dir sub-folders
mkdir -p ${jobDir}/state
mkdir -p ${jobDir}/validPairs

# set up job shell
jobShell=${jobDir}/${laneName}.sh

# copy all input valid pair files to jobDir
array=(${inputFileString//,/ })
for (( i = 0 ; i < ${#array[@]} ; i++ ))
do
	validPairFile=${array[$i]}
	validPairFileName=`basename $validPairFile`

	if [[ ${validPairFile} =~ "dekkerR/" ]] || [[ ${validPairFile} =~ "farline/" ]] || [[ ${validPairFile} =~ "isilon/" ]]
	then
		ssh ghpcc06 "cp ${validPairFile} ${jobDir}/validPairs/."
	else
		cp ${validPairFile} ${jobDir}/validPairs/.
	fi
	
	gunzip ${jobDir}/validPairs/${validPairFileName}
	
done

# merge sort all files together.
nValidPairFiles=`ls -l ${jobDir}/validPairs/*.validPair.txt | wc -l`
if [ ${nValidPairFiles} -gt 1 ]
then
	sort -m -k1,1 -k2,2 -o ${jobDir}/${jobName}.validPair.txt ${jobDir}/validPairs/*.validPair.txt
	rm ${jobDir}/validPairs/*.validPair.txt
else 
	mv ${jobDir}/validPairs/*.validPair.txt ${jobDir}/${jobName}.validPair.txt
fi

# build log file
logFile=${jobDir}/${jobName}.combine5C.log
appendToConfigFile ${configFile} "logFile" ${logFile}

# create log file
perl ${create5CLogFile} -cf ${configFile} 

# collapse the valid pair file
nReads=`perl ${collapse5CValidPair} -jn ${jobDir}/${jobName} -i ${jobDir}/${jobName}.validPair.txt`
appendToConfigFile ${configFile} "nReads" ${nReads}
logFile=${jobDir}/${jobName}.combine5C.log

validPairTxtFile=${jobDir}/${jobName}.validPair.txt
validPairItxFile=${jobDir}/${jobName}.validPair.itx

# remove the validPairTxtFile - no longer needed
rm ${validPairTxtFile}

appendToConfigFile ${configFile} "validPairItxFile" ${validPairItxFile}

# append log file to itx file + gzip
cat ${logFile} ${validPairItxFile} | gzip > ${jobDir}/${jobName}.gz

#now copy tarball back to hicData
cp ${jobDir}/${jobName}.gz ${outputFolder}.