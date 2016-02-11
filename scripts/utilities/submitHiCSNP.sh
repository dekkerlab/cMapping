#!/bin/bash
#$ -V
#$ -cwd
#$ -o $HOME/sge_jobs_output/sge_job.$JOB_ID.out -j y
#$ -S /bin/bash
#$ -M bryan.lajoie@umassmed.edu
#$ -m beas

#take workDir as input
codeTree=${1}
workDir=${2}
flowCell=${3}
laneName=${4}
laneNum=${5}
side1File=${6}
side2File=${7}
readLength=${8}
aligner=${9}
alignmentOptions=${10}
genome=${11}
indexSize=${12}
memoryNeeded=${13}
alertMode=${14}
splitSize=${15}
enzyme=${16}
zippedFlag=${17}
emailTo=${18}
outputFolder=${19}

cType="Hi-C"

cMapping=$HOME/cMapping/$codeTree
determineQVEncoding=$cMapping/perl/determineQVEncoding.pl
collapseSorts=$cMapping/perl/collapseSorts.pl
parseSam=$cMapping/perl/parse_mapped_file.pl
collapseMolecules=$cMapping/perl/collapseMolecules.pl
emaiStart=$cMapping/perl/emailInitial.pl
emailResults=$cMapping/perl/emailResults.pl
drawIterativePlots=$cMapping/R/Draw_CF_plots.R
calculateMoleculeLengths=$cMapping/mirnylib-API/calculateMoleculeLengths.py
sortReduce=$cMapping/sortReduce
reduceBowtie=$cMapping/reduceBowtie
reduceNovocraft=$cMapping/reduceNovocraft
reduceSNP=$cMapping/reduceSNP

#setup necessary paths
jobDir=$HOME/scratch/jobid_$JOB_ID
fileType=sequence
genomePath=$HOME/genome/$aligner/$genome

#create scratch space
mkdir ${jobDir}
mkdir -p ${jobDir}

genomeName=`basename ${genomePath}`
bothName=s_${laneNum}_1+2_sequence
interactionsName=${bothName}_${genomeName}.interactions
scatter=${bothName}_${genomeName}.scatter
pairHist=${bothName}_${genomeName}.pairHist
jobShell=${jobDir}/${laneName}.sh

jobName=${flowCell}__${laneName}

#initialize isilon result folders
#isilonCData=${HOME}/isilon/HPCC/cshare/cData/${flowCell}/${laneName}/
isilonCData=${outputFolder}
ssh hpcc03 "mkdir -p ${isilonCData}"

# get name of files
side1Name=`basename "${side1File}"`
side2Name=`basename "${side2File}"`

#handle the file copy
if [[ ${workDir} =~ "dekkerR/" ]] || [[ ${workDir} =~ "farline/" ]] || [[ ${workDir} =~ "isilon/" ]]
then
	# re-route through hpcc03 to access nearline/dekkerR
	ssh hpcc03 "cp ${HOME}/${side1File} ${jobDir}/."
	ssh hpcc03 "cp ${HOME}/${side2File} ${jobDir}/."
else
	# copy the files to scratch
	cp ${HOME}/${side1File} ${jobDir}/.
	cp ${HOME}/${side2File} ${jobDir}/.
fi

if [[ ${zippedFlag} = 1 ]]
then
	gunzip ${jobDir}/${side1Name}
	gunzip ${jobDir}/${side2Name}
	side1Name=s_${laneNum}_1_sequence.txt
	side2Name=s_${laneNum}_2_sequence.txt
	cat `ls ${jobDir}/*_R1_*.fastq | sort  -t _ -k3,3n -k4,4n` > ${jobDir}/${side1Name}
	cat `ls ${jobDir}/*_R2_*.fastq | sort  -t _ -k3,3n -k4,4n` > ${jobDir}/${side2Name}
	rm ${jobDir}/*_R1_*.fastq
	rm ${jobDir}/*_R2_*.fastq
fi

nReads=`wc -l ${jobDir}/${side1Name} | awk -F" " '{ print $1 }'`
let "nReads = ($nReads/4)"

qvEncoding1=`perl ${determineQVEncoding} -i ${jobDir}/${side1Name} -aln ${aligner}`
qvEncoding2=`perl ${determineQVEncoding} -i ${jobDir}/${side2Name} -aln ${aligner}`

if [[ ${qvEncoding1} = ${qvEncoding2} ]] 
then
	qvEncoding=${qvEncoding1}
else
	echo "error with QV format - exiting."
	exit
fi

#exit if cannot get valid qv format
if [[ ${qvEncoding} = "error" ]]
then
	echo "error with QV format - exiting."
	exit
fi

emailInitialFileName="email.initial.txt"	
echo "perl ${emaiStart} -f ${flowCell} -l ${laneName} -aln ${aligner} -alno '${alignmentOptions}' -g ${genome} -rf ${qvEncoding} -nr ${nReads} -j ${JOB_ID} -c ${cType} -a ${alertMode} -rl ${readLength} -ez ${enzyme} -e '${emailTo}' -o ${jobDir}/${emailInitialFileName}" >> ${jobShell}

if [ ${aligner} = "novoCraft" ]
then
	#run the map reduce on the reads 
	echo "${reduceSNP} ${JOB_ID} ${cMapping} ${jobDir} ${jobName} ${side1Name} ${side2Name} ${splitSize} ${enzyme} ${aligner} '${alignmentOptions}' ${genomePath} ${indexSize} ${memoryNeeded} ${readLength} ${qvEncoding} ${nReads}" >> ${jobShell}	
fi

# generate email statistics
emailResultsFileName=${jobName}.email.results.txt
echo "/share/bin/R-2.12.2/bin/Rscript ${drawIterativePlots} ${jobDir} iterativeMapping.stats ${jobName}.iterativeMapping.stats ${iterationStart} ${iterationEnd} ${iterationStep} ${emailResultsFileName}" >> ${jobShell}
echo "python ${calculateMoleculeLengths} -i ${jobDir}/${jobName}_mapped.hdf5 -o ${jobDir}/${jobName}.moleculeLengths.png" >> ${jobShell}
emailContentFileName=${jobName}.email.results.fullContent.txt
echo "cat ${jobDir}/${emailInitialFileName} ${jobDir}/${emailResultsFileName} ${jobDir}/iterativeParsing.stats ${jobDir}/${jobName}_redundantStats.txt ${jobDir}/${jobName}_refinedStats.txt > ${jobDir}/${emailContentFileName}" >> ${jobShell}
attachmentString=${jobDir}/${jobName}.iterativeMapping.stats.png,${jobDir}/${jobName}.moleculeLengths.png
attachmentNameString=${jobName}.iterativeMapping.stats.png,${jobName}.moleculeLengths.png

#copy HDF5 files back to isilon/cShare
echo "ssh hpcc03 'cp ${jobDir}/${jobName}_mapped.hdf5 ${isilonCData}/${jobName}.${genomeName}.mapped.hdf5'" >> ${jobShell} # mapped (raw) hdf5 file
echo "ssh hpcc03 'cp ${jobDir}/${jobName}_refined.hdf5 ${isilonCData}/${jobName}.${genomeName}.refined.hdf5'" >> ${jobShell} # refined (filtered) hdf5 file
echo "ssh hpcc03 'cp ${jobDir}/iterativeMapping.stats ${isilonCData}/${jobName}.${genomeName}.iterativeMapping.stats'" >> ${jobShell} # iterative mapping stats
echo "ssh hpcc03 'cp ${jobDir}/${emailContentFileName} ${isilonCData}/${jobName}.${genomeName}.emailContent.txt'" >> ${jobShell} # email stats

#email the results
echo "perl ${emailResults} -a ${alertMode} -as '${attachmentString}' -ans '${attachmentNameString}' -i ${jobDir}/${emailContentFileName} -j ${JOB_ID} -aln ${aligner} -g ${genome} -e '${emailTo}'" >> ${jobShell}

echo "rm -rf ${jobDir}" >> ${jobShell}

chmod 744 ${jobShell}
${jobShell}
