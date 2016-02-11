#!/bin/bash

UUID=$1
subID=$2
logDir=$3

logFile=${logDir:=~}/LSB_${LSB_JOBID:=ERROR}.log

hostName=`hostname`

jobDirs="/tmp/cWorld__*__${UUID:=ERROR}__${subID:=*}__*/"

if ls ${jobDirs} &> /dev/null; then
	
	echo -e "LSB_JOBID\t${LSB_JOBID}" | tee -a ${logFile}
	echo -e "hostName\t${hostName}" | tee -a ${logFile}
	echo -e "jobDirs\t${jobDirs}\n" | tee -a ${logFile}
	
	echo -e "found leftover jobDirs!\n" | tee -a ${logFile}
	
	for f in ${jobDirs}
	do
		tmpUsed=`du -hs $f | cut -f1`
		echo -e "\t$f\t${tmpUsed}" | tee -a ${logFile}
		rm -rf ${f}
		if ls ${f} &> /dev/null; then
			echo -e "\nERROR - could not remove $f!\n" | tee -a ${logFile}
		else
			echo -e "\t\t\tremoved" | tee -a ${logFile}
		fi
	done
fi