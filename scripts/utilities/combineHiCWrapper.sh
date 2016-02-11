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
combineHiC=${cMapping}/scripts/combineHiC.sh
createHiCLogFile=${cMapping}/perl/createHiCLogFile.pl
collapseHiCValidPair=${cMapping}/perl/collapseHiCValidPairs.pl
splitIntervalFile=${cMapping}/perl/splitIntervalFile.pl

wrapperJobID=${LSB_JOBID}
appendToConfigFile ${configFile} "wrapperJobID" ${wrapperJobID}

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
	
	
done

# merge sort all files together.
nValidPairFiles=`ls -l ${jobDir}/validPairs/*.validPair.txt.gz | wc -l`
if [ ${nValidPairFiles} -gt 1 ]
then
	# now merge sort all valid pair files
	cmd="sort -m -k6,6n -k12,12n -k3,3n -k9,9n "
	for input in ${jobDir}/validPairs/*.validPair.txt.gz;
	do
		cmd="$cmd <(gunzip -c '$input')"
	done
	eval "$cmd" | gzip > ${jobDir}/${jobName}.validPair.txt.gz
else 
	mv ${jobDir}/validPairs/*.validPair.txt.gz ${jobDir}/${jobName}.validPair.txt.gz
fi

if [[ ${sameStrand} = "y" ]]
then
	sameStrandFlag="-ss"
else
	sameStrandFlag=""
fi

# collapse the valid pair file
nReads=`perl ${collapseHiCValidPair} -jn ${jobDir}/${jobName} -i ${jobDir}/${jobName}.validPair.txt.gz ${sameStrandFlag}`

appendToConfigFile ${configFile} "nReads" ${nReads}

validPairTxtFile=${jobDir}/${jobName}.validPair.txt.gz
validPairItxFile=${jobDir}/${jobName}.validPair.itx.gz

# remove the validPairTxtFile - no longer needed
# rm ${validPairTxtFile}

pcrDupeLogFile=${jobDir}/${jobName}.pcrDupe.log

appendToConfigFile ${configFile} "validPairItxFile" ${validPairItxFile}

validPairItxFileSize=`du -s ${validPairItxFile} | cut -f1`
let tmpNeeded=($validPairItxFileSize+1024-1)/1024*10

# build log file
logFile=${jobDir}/${jobName}.combineHiC.log
appendToConfigFile ${configFile} "logFile" ${logFile}

# create log file
perl ${createHiCLogFile} -cf ${configFile} 

# now spawn off all combine workers (1 per bin level)
nResults=0
# submit binning+correction
if [[ ${binSizes} != "NA" ]]
then
	IFS=,
	binSizesArray=($binSizes)
	binLabelsArray=($binLabels)
	binModesArray=($binModes)

	for index in "${!binSizesArray[@]}"
	do		
		mapID=`uuidgen | rev | cut -d '-' -f 1`
		mkdir -p ${jobDir}/map__${mapID}/
		
		binSize=${binSizesArray[$index]}
		binLabel=${binLabelsArray[$index]}
		binMode=${binModesArray[$index]}
		
		if [ ${binMode} = "chr" ]
		then
			groups=`perl ${splitIntervalFile} -jn ${jobDir}/map__${mapID}/${jobName} -i ${restrictionFragmentPath} -sm ${binMode}`
			groupsArray=($groups)
			nGroups=${#groupsArray[@]}
			if [[ ${nGroups} -gt 100 ]]
			then
				echo "ERROR - attempting to start too many jobs ($nGroups)"
				exit
			fi
				
			for g in "${!groupsArray[@]}"
			do
				group=${groupsArray[$g]}
				intervalFile=${jobDir}/map__${mapID}/${jobName}__${group}.txt
				
				sub_mapID=`uuidgen | rev | cut -d '-' -f 1`
				chr_mapID=${mapID}__${sub_mapID}
				
				#echo "bsub -n 1 -q $combineQueue -R rusage[mem=$combineMemoryNeeded:tmp=$tmpNeeded] -W $combineTimeNeeded -N -u bryan.lajoie\@umassmed.edu -J combineHiC -o /home/bl73w/lsf_jobs/LSB_%J.log -e /home/bl73w/lsf_jobs/LSB_%J.err -Ep "${cMapping}/scripts/garbageCollectTmp.sh ${UUID} ${chr_mapID} /home/bl73w/lsf_jobs" ${combineHiC} ${configFile} ${binSize} ${binLabel} ${group} ${intervalFile} ${chr_mapID}"
				bsub -n 1 -q $combineQueue -R rusage[mem=$combineMemoryNeeded:tmp=$tmpNeeded] -W $combineTimeNeeded -N -u bryan.lajoie\@umassmed.edu -J combineHiC -o /home/bl73w/lsf_jobs/LSB_%J.log -e /home/bl73w/lsf_jobs/LSB_%J.err -Ep "${cMapping}/scripts/garbageCollectTmp.sh ${UUID} ${chr_mapID} /home/bl73w/lsf_jobs" ${combineHiC} ${configFile} ${binSize} ${binLabel} ${group} ${intervalFile} ${chr_mapID}
				results[${nResults}]=${jobName}__${group}__${binLabel}-${binSize}.complete
				let nResults++
			done
		else 
			group="genome"
			cp ${restrictionFragmentPath} ${jobDir}/map__${mapID}/${jobName}__${group}.txt
			intervalFile=${jobDir}/map__${mapID}/${jobName}__${group}.txt
			bsub -n 1 -q $combineQueue -R rusage[mem=$combineMemoryNeeded:tmp=$tmpNeeded] -W $combineTimeNeeded -N -u bryan.lajoie\@umassmed.edu -J combineHiC -o /home/bl73w/lsf_jobs/LSB_%J.log -e /home/bl73w/lsf_jobs/LSB_%J.err -Ep "${cMapping}/scripts/garbageCollectTmp.sh ${UUID} ${mapID} /home/bl73w/lsf_jobs" ${combineHiC} ${configFile} ${binSize} ${binLabel} ${group} ${restrictionFragmentPath} ${mapID}
			results[${nResults}]=${jobName}__${group}__${binLabel}-${binSize}.complete
			let nResults++
		fi
		
	done
fi

#now look for binning/correction to report back that they are complete.
completeResults=0
while [ ${completeResults} -lt ${nResults} ]
do
	completeResults=0
	for ((  i = 0;  i < ${nResults};  i++  )) 
	do
		resultFile=${jobDir}/state/${results[${i}]}
		if [ -f ${resultFile} ]
		then
			let completeResults++
		fi
	done
	sleep 30
done

#
# now log all of the matrix files into tarball
#

# create txt folder structure in tmp jobDir
txtDirName=${jobName}__txt
txtDir=${jobDir}/${txtDirName}
appendToConfigFile ${configFile} "txtDirName" ${txtDirName}
appendToConfigFile ${configFile} "txtDir" ${txtDir}
mkdir -p ${txtDir}/

# create hdf folder structure in tmp jobDir
hdfDirName=${jobName}__hdf
hdfDir=${jobDir}/${hdfDirName}
appendToConfigFile ${configFile} "hdfDirName" ${hdfDirName}
appendToConfigFile ${configFile} "hdfDir" ${hdfDir}
mkdir -p ${hdfDir}

# move over log files
cat ${logFile} ${pcrDupeLogFile} > ${txtDir}/${txtDirName}.log
cat ${logFile} ${pcrDupeLogFile} > ${hdfDir}/${hdfDirName}.log

if [[ ${binSizes} != "NA" ]]
then
	IFS=,
	binSizesArray=($binSizes)
	binLabelsArray=($binLabels)
	binModesArray=($binModes)

	for index in "${!binSizesArray[@]}"
	do
		binSize=${binSizesArray[$index]}
		binLabel=${binLabelsArray[$index]}
		binMode=${binModesArray[$index]}

		mkdir -p ${txtDir}/${binLabel}-${binSize}/raw
		mkdir -p ${txtDir}/${binLabel}-${binSize}/iced
		mkdir -p ${txtDir}/${binLabel}-${binSize}/supp
		mv ${jobDir}/${jobName}__*__${binLabel}-${binSize}-raw*.matrix.gz ${txtDir}/${binLabel}-${binSize}/raw/. 2> /dev/null
		mv ${jobDir}/${jobName}__*__${binLabel}-${binSize}-iced*.matrix.gz ${txtDir}/${binLabel}-${binSize}/iced/. 2> /dev/null
		cp ${jobDir}/${jobName}__*__${binLabel}-${binSize}.log ${txtDir}/${binLabel}-${binSize}/supp/. 2> /dev/null
		cp ${jobDir}/${jobName}__*__${binLabel}-${binSize}.error ${txtDir}/${binLabel}-${binSize}/supp/. 2> /dev/null
		
		mkdir -p ${hdfDir}/${binLabel}-${binSize}/raw
		mkdir -p ${hdfDir}/${binLabel}-${binSize}/iced/
		mkdir -p ${hdfDir}/${binLabel}-${binSize}/supp
		mv ${jobDir}/${jobName}__*__${binLabel}-${binSize}-raw.hdf5 ${hdfDir}/${binLabel}-${binSize}/raw/. 2> /dev/null
		mv ${jobDir}/${jobName}__*__${binLabel}-${binSize}-iced.hdf5 ${hdfDir}/${binLabel}-${binSize}/iced/. 2> /dev/null
		cp ${jobDir}/${jobName}__*__${binLabel}-${binSize}.log ${hdfDir}/${binLabel}-${binSize}/supp/. 2> /dev/null
		cp ${jobDir}/${jobName}__*__${binLabel}-${binSize}.error ${hdfDir}/${binLabel}-${binSize}/supp/. 2> /dev/null
		
	done
fi

# this should not be necessary, but it seems like an io lag?
sleep 30

#now tarball everything
tar -cf ${txtDir}.tar -C ${jobDir}/ ${txtDirName}/
rm -rf ${jobDir}/${txtDirName}

#now copy tarball back to hicData
cp ${txtDir}.tar ${outputFolder}.

#now tarball everything
tar -cf ${hdfDir}.tar -C ${jobDir}/ ${hdfDirName}/
rm -rf ${jobDir}/${hdfDirName}

#now copy tarball back to hicData
cp ${hdfDir}.tar ${outputFolder}.
