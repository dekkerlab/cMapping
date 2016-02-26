#!/bin/sh
checkForErrors() {
	
	if [ -s ${errorFile} ]
	then
		
		echo -e "combineHiC (${jobID}) reported error!\n----------"
		cat ${errorFile}
		echo -e "----------\n"
		
		cp ${jobDir}/*.log ${parentJobDir}/. 2>> ${errorFile}
		cp ${jobDir}/*.error ${parentJobDir}/. 2>> ${errorFile}
		
		bkill ${jobID}
		bkill ${wrapperJobID}
		exit
	fi
	
}

configFile=${1}
binSize=${2}
binLabel=${3}
group=${4}
intervalFile=${5}
mapID=${6}

source ${configFile}

# append bin size to jobname
jobName=${jobName}__${group}__${binLabel}-${binSize}

# load modules
module load python/2.7.5 &> /dev/null

# set up perl/python/shell paths
bin=${cMapping}/python/bin.py
fragment=${cMapping}/python/fragment.py
filter_1d_bins=${cMapping}/python/filter_1d_bins.py
bin2hdf=${cMapping}/python/bin2hdf.py
hdf2tab=${hdf2tab_path}
balance=${balance_path}
applyNANFilter=${cMapping}/python/applyNANFilter.py

# set up job/task ID variables
jobID=${LSB_JOBID}
jobDir=${mapScratchDir}/cWorld__stage2-map__${UUID}__${mapID}__${LSB_JOBID}
mkdir -p ${jobDir}

# set up main output file
binFile=${jobDir}/${jobName}.bin
logFile=${jobDir}/${jobName}.log
errorFile=${jobDir}/${jobName}.error

# set up down secondary output files
binPositionFile=${binFile}.position
mapFile=${binFile}.map
binFilteredFile=${binFile}.nan.log
hdfFile=${jobDir}/${jobName}-raw.hdf5
matrixFile=${jobDir}/${jobName}-raw
chromosomeListFile=${binFile}.chromosomeList
balancedHdfFile=${jobDir}/${jobName}-iced.hdf5
factorFile=${binFile}.balanced.factors.log
balancedMatrixFile=${jobDir}/${jobName}-iced
balancedChromosomeListFile=${binFile}.balanced.chromosomeList
balancedBinPositionFile=${binFile}.balanced.position

if [[ ${ignoreDiagonal} = 0 ]]
then
	ignoreDiagonalFlag=""
else
	ignoreDiagonalFlag="-d"
fi

echo "starting ${jobName}" 1>> ${logFile} 2>> ${errorFile}

# bin the data (validPair.itx -> validPair.itx.bin)
if [[ $binSize = 0 ]]
then
	python ${fragment} -in ${validPairItxFile} -in_ref ${intervalFile} -c 2 -out ${binFile} -out_bp ${binPositionFile} -out_map ${mapFile} 1>> ${logFile} 2>> ${errorFile}
else
	python ${bin} -in ${validPairItxFile} -in_ref ${intervalFile} -c 2 -out ${binFile} -out_bp ${binPositionFile} -out_map ${mapFile} -b ${binSize} 1>> ${logFile} 2>> ${errorFile}
fi

checkForErrors

# filter the binned data (row/col)
python ${filter_1d_bins} -in ${binFile} -in_ref ${intervalFile} -in_bp ${binPositionFile} -in_map ${mapFile} -out ${binFilteredFile} -cc 6 -d ${ignoreDiagonal} 1>> ${logFile} 2>> ${errorFile}

checkForErrors

# load binned data into HDF5 (w/ filtering)
python ${bin2hdf} -in ${binFile} -out ${hdfFile} -g ${genomeName} -in_bp ${binPositionFile} -c 4 5 -cc 6 1>> ${logFile} 2>> ${errorFile}

checkForErrors

# extract RAW matrix from the filtered HDF5 (allxall)
python ${hdf2tab} -i ${hdfFile} -o ${matrixFile} -wm all__cis --maxdim ${maxdim} 1>> ${logFile} 2>> ${errorFile}

checkForErrors

# copy back raw hdf/matrix
cp ${hdfFile} ${parentJobDir}/. 2>> ${errorFile}
cp ${matrixFile}*.matrix.gz ${parentJobDir}/. 2>> ${errorFile}

checkForErrors

python ${applyNANFilter} -in ${hdfFile} -nan ${binFilteredFile} 1>> ${logFile} 2>> ${errorFile}

checkForErrors

# perform iterative correction on HDF5 file
python ${balance} -in ${hdfFile} -out ${balancedHdfFile} -f ${factorFile} ${ignoreDiagonalFlag} 1>> ${logFile} 2>> ${errorFile}

checkForErrors

# extract BALANCED matrix from HDF5 (allxall)
python ${hdf2tab} -i ${balancedHdfFile} -o ${balancedMatrixFile} -wm all__cis --maxdim ${maxdim} 1>> ${logFile} 2>> /dev/null

checkForErrors

# copy back iced hdf/matrix
cp ${balancedHdfFile} ${parentJobDir}/. 2>> ${errorFile}
cp ${balancedMatrixFile}*.matrix.gz ${parentJobDir}/. 2>> ${errorFile}

# copy back all error/log files
cp ${jobDir}/*.log ${parentJobDir}/. 2>> ${errorFile}
cp ${jobDir}/*.error ${parentJobDir}/. 2>> ${errorFile}

checkForErrors

# purge any/all loaded modules
module purge

# remove job dir
if [ $debugModeFlag = 0 ]; then rm -rf ${jobDir}; fi

checkForErrors
sleep 30

# create completion file
touch ${parentJobDir}/state/${jobName}.complete