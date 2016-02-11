#! /usr/bin/perl
use warnings;
use strict;
use IO::Handle;
use POSIX qw(ceil floor);
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

## Checks the options to the program
sub check_options {
	my $opts = shift;

	my ($cDataDir,$genomeName,$codeTree,$customBinSize,$maxdim,$adminMode,$experimentPrefix,$debugModeFlag);
	
	if( $opts->{ cDataDir } ) {
		$cDataDir = $opts->{ cDataDir };
	} else {
		$cDataDir=$ENV{"HOME"}."/farline/HPCC/cshare/cData/";
	}
	
	if( $opts->{ genomeName } ) {
		$genomeName = $opts->{ genomeName };
	} else {
		die("Option genomeName|g is required.");
	}
	
	if( defined($opts->{ codeTree }) ) {
		$codeTree = $opts->{ codeTree };
		die("Invalid codeTree! ($codeTree)\n") if(!(-d ($ENV{"HOME"}."/cMapping/$codeTree")));
	} else {
		$codeTree="prod";
	}
	
	if( defined($opts->{ customBinSize }) ) {
		$customBinSize = $opts->{ customBinSize };
	} else {
		$customBinSize="10000000,2500000,1000000,500000,250000,100000,40000";
	}
	
	if( defined($opts->{ maxdim }) ) {
		$maxdim = $opts->{ maxdim };
	} else {
		$maxdim=4000;
	}
	
	if( $opts->{ adminMode } ) {
		$adminMode=1;
	} else {
		$adminMode=0;
	}
	
	if( defined($opts->{ experimentPrefix }) ) {
		$experimentPrefix = $opts->{ experimentPrefix };
	} else {
		$experimentPrefix="";
	}	
	
	if( $opts->{ debugModeFlag } ) {
		$debugModeFlag=1;
	} else {
		$debugModeFlag=0;
	}
	
	
	return($cDataDir,$genomeName,$codeTree,$customBinSize,$maxdim,$adminMode,$experimentPrefix,$debugModeFlag);
}

sub readConfigFile($) {
	my $configFile=shift;
	
	my %log=();
	
	# get config log info
	open(IN,$configFile);
	while(my $line = <IN>) {
		chomp($line);
		next if($line =~ /^#/);
		next if($line eq "");
		
		my ($field,$value)=split(/=/,$line);
		$value =~ s/"//g;

		$log{$field}=$value;
	}
	close(IN);
	
	return(\%log);
}
		
sub getDate() {

	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
	my $time = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
	
	return($time);
}
	
sub getGenomePath($$) {
	my $genomeName=shift;
	my $restrictionSite=shift;
	
	my $userHomeDirectory = getUserHomeDirectory();
	
	my $fastaDirectory=$userHomeDirectory."/genome/fasta/".$genomeName;
	my $restrictionFragmentFile=$userHomeDirectory."/genome/restrictionFragments/".$genomeName."/".$genomeName."__".$restrictionSite.".txt";
	
	die("invalid fasta directory ($fastaDirectory)\n") if(!(-d($fastaDirectory)));
	die("invalid restriction fragment file ($restrictionFragmentFile)\n") if(!(-e($restrictionFragmentFile)));
	
	return($fastaDirectory,$restrictionFragmentFile);
}

sub getUserHomeDirectory() {
	my $userHomeDirectory = `echo \$HOME`;
	chomp($userHomeDirectory);
	return($userHomeDirectory);
}

sub getDefaultOutputFolder($) {
	my $adminModeFlag = shift;
	
	my $userHomeDirectory = getUserHomeDirectory();
	
	my $outputFolder=$userHomeDirectory."/scratch/hicData/";
	$outputFolder=$userHomeDirectory."/cshare/hicData/" if($adminModeFlag == 1);
	
	return($outputFolder,$userHomeDirectory);
}

sub commify {
   (my $num = shift) =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g; 
   return $num; 
}

sub storeMapping($$$) {
	my $mappingData={};
	$mappingData=shift;
	my $file=shift;
	my $flowCell=shift;
	
	my $nRenamed=0;
	my ($line);
	open(MAPPING,$file);
	while($line = <MAPPING>) {
		chomp($line);
		
		next if($line eq "");
		
		my ($origLaneName,$newLaneName)=split(/\t/,$line);
		
		my $laneKey=$flowCell."/".$origLaneName;
		$nRenamed++;
		
		$mappingData->{$laneKey}=$newLaneName;
		#print "\t$laneKey -> $newLaneName\n";
		
	}
	close(MAPPING);
	
	return($mappingData);
}	
	
sub findMappingFiles($$$$) {
	my $mappingData={};
	$mappingData=shift;
	my $cDataDir=shift;
	my $parentDir=shift;
	my $genomeName=shift;
	
	$parentDir .= "/" if($parentDir !~ /\/$/);
	
	opendir(my $dir, $parentDir) || die "can't opendir $parentDir: $!";
	
	for my $eachFile (readdir($dir)) {
		next if ($eachFile =~ /^..?$/);
		
		my $file = $parentDir .$eachFile;
		if( -d $file) {
			&findMappingFiles($mappingData,$cDataDir,$file,$genomeName);
		} else {
			my $strippedFilePath = $file;
			$strippedFilePath =~ s/$cDataDir//;
			my $flowCell = (split(/\//,$strippedFilePath))[0];
			
			next if(($flowCell eq "LIVE") or ($flowCell eq "FREEZES"));
			
			my $laneName = (split(/\//,$strippedFilePath))[1];
			
			if($laneName eq "mapping") {
				$mappingData=storeMapping($mappingData,$file,$flowCell);
				print "\t$file\n";
				next;
			}
			
		}
	}   
	
	return($mappingData);
}

sub findDataFiles($$$$$$) {
	my $laneData={};
	$laneData=shift;
	my $mappingData={};
	$mappingData=shift;
	my $cDataDir=shift;
	my $parentDir=shift;
	my $genomeName=shift;
	my $restrictionFragmentPath=shift;
	
	$parentDir .= "/" if($parentDir !~ /\/$/);
	
	opendir(my $dir, $parentDir) || die "can't opendir $parentDir: $!";
	
	for my $eachFile (readdir($dir)) {
		next if ($eachFile =~ /^..?$/);
		
		my $file = $parentDir .$eachFile;
		if( -d $file) {
			&findDataFiles($laneData,$mappingData,$cDataDir,$file,$genomeName,$restrictionFragmentPath);
		} else {
			my $strippedFilePath = $file;
			$strippedFilePath =~ s/$cDataDir//;
			my $flowCell = (split(/\//,$strippedFilePath))[0];
			my $laneName = (split(/\//,$strippedFilePath))[1];
			
			next if($laneName eq "mapping");
			
			my @tmp = split(/\//,$strippedFilePath);
			my $fileName = $tmp[@tmp-1];

			
			next if($fileName !~ /.validPair.txt.gz$/);
			
			my $laneName2 = (split(/__/,$fileName))[2];
			my @tmp2 = split(/\./,$laneName2);
			my $genome = $tmp2[0];
			my $fileType = $tmp2[1];
			my $fileExtension = $tmp2[-1];
			
			next if($genome ne $genomeName);
			
			if($flowCell."__".$laneName."__".$genome.".validPair.txt.gz" ne $fileName) {
				print "\n";
				print "error with file format...\n";
				print "\t".$fileName."\n";
				print "\t".$flowCell."__".$laneName."__".$genome.".validPair.txt.gz\n";
				print "\n";
				exit;
			}
			
			my $configFileName=$flowCell."__".$laneName."__".$genome.".cfg";
			my $configFilePath=$parentDir.$configFileName;
			die("Config file does not exist! ($configFileName)\n") if(!(-e($configFilePath)));
			
			my $log=readConfigFile($configFilePath);
			my $configRestrictionFragmentPath="NA";
			$configRestrictionFragmentPath=$log->{ restrictionFragmentPath };
			
			next if($restrictionFragmentPath ne $configRestrictionFragmentPath);
			
			my $correctedLaneName=$laneName;
			$correctedLaneName =~ s/^Sample_//;
			$correctedLaneName=(split(/_/,$correctedLaneName))[0];
			$correctedLaneName = (split(/\./,$correctedLaneName))[0];
			$correctedLaneName = $mappingData->{$flowCell."/".$laneName} if(exists($mappingData->{$flowCell."/".$laneName}));
			$correctedLaneName =~ s/\.//g;
			
			
			push(@{$laneData->{$correctedLaneName}->{$fileType}},$file);

		}
	}   
	
	return($laneData,$mappingData);
}

sub processCustomBinSize($) {
	my $customBinSize=shift;
	
    my $binSizes="NA";
	my $binLabels="NA";

	if($customBinSize eq "") {
		print "\t[C]\tnone\n";
		return($binSizes,$binLabels) if($customBinSize eq "");
	}
	
    my $binLabel="C";
	my @tmp=split(/,/,$customBinSize);
	for(my $i=0;$i<@tmp;$i++) {
		my $binSize=$tmp[$i];
		print "\t[C]\t".commify($binSize)."\n";
		
		$binSizes=$binSizes.",".$binSize if($binSizes ne "NA");
		$binSizes=$binSize if($binSizes eq "NA");
		
		$binLabels=$binLabels.",".$binLabel if($binLabels ne "NA");
		$binLabels=$binLabel if($binLabels eq "NA");
	}
	
	return($binSizes,$binLabels);
}

sub getRestrictionEnzymeSequences() {
	my %restrictionEnzymeSequences=();
	
	$restrictionEnzymeSequences{ HindIII } = "AAGCTT";
	$restrictionEnzymeSequences{ EcoRI } = "GAATTC";
	$restrictionEnzymeSequences{ NcoI } = "CCATGG";
	$restrictionEnzymeSequences{ DpnII } = "GATC";
	$restrictionEnzymeSequences{ MNase } = "MNase";
	$restrictionEnzymeSequences{ BglII } = "AGATCT";
	$restrictionEnzymeSequences{ NcoI } = "CCATGG";
	
	return(\%restrictionEnzymeSequences);
}
	
sub logConfigVariable($$$) {
	my $configFileVariables=shift;
	my $configVariableName=shift;
	my $configVariableValue=shift;
	
	$configFileVariables->{$configVariableName}=$configVariableValue;
	
	return($configFileVariables);
}

sub printConfigFile($$$) {
	my $configFileVariables=shift;
	my $tmpConfigFileVariables=shift;
	my $configFileName=shift;
	
	open(OUT,">".$configFileName);
	
	my $time=getDate();
	my $userHomeDirectory=getUserHomeDirectory();
	
	print OUT "# cWorld combineHiC\n";
	print OUT "# my5C.umassmed.edu\n";
	print OUT "# $time\n";
	print OUT "# $userHomeDirectory\n";
	print OUT "# ".$configFileVariables->{ computeResource}."\n";
	print OUT "# initial variables\n";
	
	for my $variableName ( sort {$a cmp $b} keys %{$configFileVariables}) {
		my $variableValue=$configFileVariables->{$variableName};
		print OUT $variableName."="."\"$variableValue\"\n";
	}
	
	for my $variableName ( sort {$a cmp $b} keys %{$tmpConfigFileVariables}) {
		my $variableValue=$tmpConfigFileVariables->{$variableName};
		print OUT $variableName."="."\"$variableValue\"\n";
	}
	
	print OUT "# dynamic variables\n";
	
	close(OUT);
}

sub getBinModes($$) {
	my $tmpBinSizes=shift;
	my $tmpBinLabels=shift;
    
	my @tmpBinSizesArr=split(/,/,$tmpBinSizes);
	my @tmpBinLabelsArr=split(/,/,$tmpBinLabels);
	
	my $nTmpBinSizes=@tmpBinSizesArr;
	my $nTmpBinLabels=@tmpBinLabelsArr;
	die("ERROR - mismatch between binSizes and binLabels! ($nTmpBinSizes vs $nTmpBinLabels)\n") if($nTmpBinSizes != $nTmpBinLabels);
	
	my $nTmpBins=$nTmpBinSizes=$nTmpBinLabels;
	
	my @binSizesArr=();
	my @binLabelsArr=();
	my @binModesArr=();
	
	for(my $i=0;$i<$nTmpBins;$i++) {
		my $binSize=$tmpBinSizesArr[$i];
		my $binLabel=$tmpBinLabelsArr[$i];
		
		print "\t\t[$binLabel]\t".commify($binSize)."\t ice mode [genome] (remove,genome,chr): ";
		my $binMode="genome";
		my $userBinMode=<STDIN>;		
		chomp($userBinMode);
		$binMode=$userBinMode if(($userBinMode ne "") and (($userBinMode eq "genome") or ($userBinMode eq "chr") or ($userBinMode eq "remove")));
		print "\t\t\t$binMode\n";
		
		next if($binMode eq "remove");
		
		push(@binSizesArr,$binSize);
		push(@binLabelsArr,$binLabel);
		push(@binModesArr,$binMode);

	}
	
	my $binSizes=join(",", @binSizesArr); 
	my $binLabels=join(",", @binLabelsArr); 
	my $binModes=join(",", @binModesArr); 

	return($binSizes,$binLabels,$binModes);
}
	

sub getUniqueString() {
	my $UUID = `uuidgen`;
	chomp($UUID);
	return($UUID);
}

sub getSmallUniqueString() {
	my $UUID=`uuidgen | rev | cut -d '-' -f 1`;
	chomp($UUID);
	return($UUID);
}

sub getComputeResource() {
	my $hostname = `hostname`;
	chomp($hostname);
	return($hostname);
}

sub translateFlag($) {
	my $flag=shift;
	
	my $response="off";
	$response="on" if($flag == 1);	
	return($response);
}

sub getNumberOfLines($) {
	my $inputFile=shift;
	
	my $nLines = 0;
	
	if(($inputFile =~ /\.gz$/) and (!(-T($inputFile)))) {
		my $matrixInfo=`zcat '$inputFile' | head -n 1 | cut -f 1`;
		chomp($matrixInfo);
		if($matrixInfo =~ /(\d+)x(\d+)/) {
			my ($nRows,$nCols) = split(/x/,$matrixInfo);
			$nLines = $nRows;
		} else { 
			$nLines = `zcat '$inputFile' | grep -v "# " | wc -l`;
		}
	} else {
		$nLines = `grep -v "# " '$inputFile' | wc -l`;
	}

	chomp($nLines);
	$nLines=(split(/ /,$nLines))[0];	
	
	return($nLines);
}

my %options;
my $results = GetOptions( \%options,'cDataDir|i=s','genomeName|g=s','codeTree|c=s','maxdim|m=s','customBinSize|C=s','adminMode|a','experimentPrefix|ep=s','debugModeFlag|d');

my ($cDataDir,$genomeName,$codeTree,$customBinSize,$maxdim,$adminMode,$experimentPrefix,$debugModeFlag)=check_options( \%options );

my $configFileVariables={};

print "\n";
print "cDataDir (-i)\t$cDataDir\n";
print "genomeName (-g)\t\t$genomeName\n";
print "codeTree (-c)\t$codeTree\n";
print "maxdim (-md)\t$maxdim\n";
print "customBinSize (-C)\t$customBinSize\n";
print "adminMode (-a [FLAG])\t$adminMode\n";
print "experimentPrefix\t$experimentPrefix\n";
print "debugModeFlag\t$debugModeFlag\n";
print "\n";

my $userHomeDirectory = getUserHomeDirectory();
my $cMapping = $userHomeDirectory."/cMapping/".$codeTree;

$configFileVariables=logConfigVariable($configFileVariables,"cDataDir",$cDataDir);
$configFileVariables=logConfigVariable($configFileVariables,"genomeName",$genomeName);
$configFileVariables=logConfigVariable($configFileVariables,"codeTree",$codeTree);
$configFileVariables=logConfigVariable($configFileVariables,"cMapping",$cMapping);
$configFileVariables=logConfigVariable($configFileVariables,"customBinSize",$customBinSize);
$configFileVariables=logConfigVariable($configFileVariables,"debugModeFlag",$debugModeFlag);
$configFileVariables=logConfigVariable($configFileVariables,"maxdim",$maxdim);

my $computeResource = getComputeResource();
$configFileVariables=logConfigVariable($configFileVariables,"computeResource",$computeResource);

# setup scratch space
my $reduceScratchDir=$userHomeDirectory."/scratch";
my $mapScratchDir="/tmp";
$mapScratchDir=$userHomeDirectory."/scratch" if($debugModeFlag == 1);

# setup queue/timelimit for LSF
my $combineQueue="long";
$combineQueue="short" if($debugModeFlag == 1);
my $combineTimeNeeded="240:00";
$combineTimeNeeded="04:00" if($debugModeFlag == 1);
my $combineMemoryNeeded=8192;

if($adminMode == 1) {
	print "WARNING - adminMode is ON - continue? (y/n) [n] : ";
	my $response=<STDIN>;
	chomp($response);
	die("Cannot continue without valid response\n") if($response ne "y");
}

# enzyme choice 
my $restrictionEnzymeSequences=getRestrictionEnzymeSequences();
my $enzymeString=join(',', (keys %{$restrictionEnzymeSequences}));

my ($enzyme,$restrictionSite);
$enzyme="HindIII";
print "enzyme (".$enzymeString.") [".$enzyme."] : ";
my $userEnzyme = <STDIN>;
chomp($userEnzyme);
$enzyme=$userEnzyme if($userEnzyme ne "");
die("Invalid Restriction Enzyme! ($enzyme)\n") if(!(exists($restrictionEnzymeSequences->{ $enzyme })));
$restrictionSite=$restrictionEnzymeSequences->{ $enzyme };
print "\t$enzyme / $restrictionSite\n";
$configFileVariables=logConfigVariable($configFileVariables,"enzyme",$enzyme);
$configFileVariables=logConfigVariable($configFileVariables,"restrictionSite",$restrictionSite);

my ($fastaPath,$restrictionFragmentPath)=getGenomePath($genomeName,$restrictionSite); 
print "\t$fastaPath\n";
$configFileVariables=logConfigVariable($configFileVariables,"fastaPath",$fastaPath);

print "\nrestrictionFragmentPath [$restrictionFragmentPath]: ";
my $userRestrictionFragmentPath = <STDIN>;
chomp($userRestrictionFragmentPath);
$userRestrictionFragmentPath = "" if(!(-e($userRestrictionFragmentPath)));
$restrictionFragmentPath = $userRestrictionFragmentPath if($userRestrictionFragmentPath ne "");
die("invalid restriction fragment file path!\n") if(!(-e($restrictionFragmentPath)));
print "\t$restrictionFragmentPath\n";

print "\nsearching for mapping files...\n";
my $mappingData={};
($mappingData)=findMappingFiles($mappingData,$cDataDir,$cDataDir,$genomeName);
print "\tdone.\n";

$configFileVariables=logConfigVariable($configFileVariables,"fastaDir",$fastaPath);

print "\nprocessing custom bin sizes...\n";
my ($binSizes,$binLabels)=processCustomBinSize($customBinSize);

print "\nsearching for cData files...\n";
my $laneData={};
($laneData,$mappingData)=findDataFiles($laneData,$mappingData,$cDataDir,$cDataDir,$genomeName,$restrictionFragmentPath);

foreach my $sampleName ( keys %$laneData ) {
	
	my $tmpConfigFileVariables={};
	
	print "\nsampleName: ".$sampleName."\n";
	print "\tskipping\n" if(($experimentPrefix ne "") and ($sampleName !~ /$experimentPrefix/));
	next if(($experimentPrefix ne "") and ($sampleName !~ /$experimentPrefix/));
	
	my @tmpArray=@{$laneData->{$sampleName}->{ validPair }};
	my $arraySize=@tmpArray;
	
	my $totalFileSizeMegabyte=0;
	for(my $i=0;$i<$arraySize;$i++) {
		my $cFile=$tmpArray[$i];
		my @tmp=split(/\//,$cFile);
		my $flowCell=$tmp[@tmp-3];
		my $laneName=$tmp[@tmp-2];

		my $fileSize=`du -b $cFile`;
		chomp($fileSize);
		$fileSize=(split(/\t/,$fileSize))[0];
		my $fileSizeMegabyte = ceil($fileSize / 1000000);
		$totalFileSizeMegabyte += $fileSizeMegabyte;
		print "\t(".commify($fileSizeMegabyte)."M)\t$flowCell\t$laneName\n";
	}
	
	die("error with sample name ($sampleName) (cannot contain [.]) - exiting\n") if($sampleName =~ /\./);
	
	print "\n\tprocess? (".commify($totalFileSizeMegabyte)."M) (y/n) [n]:\t";
	my $option = <>;
	chomp $option;
		
	if($option ne "y") {
		print "\tskipping...\n";
		next;
	} 

	print "\n\trestrictionFragmentPath [$restrictionFragmentPath]: ";
	my $userRestrictionFragmentPath = <STDIN>;
	chomp($userRestrictionFragmentPath);
	$userRestrictionFragmentPath = "" if(!(-e($userRestrictionFragmentPath)));
	$restrictionFragmentPath = $userRestrictionFragmentPath if($userRestrictionFragmentPath ne "");
	die("invalid restriction fragment file path!\n") if(!(-e($restrictionFragmentPath)));
	print "\t\t$restrictionFragmentPath\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"restrictionFragmentPath",$restrictionFragmentPath);
	
	$configFileVariables=logConfigVariable($configFileVariables,"combineQueue",$combineQueue);
	$configFileVariables=logConfigVariable($configFileVariables,"combineTimeNeeded",$combineTimeNeeded);
	$configFileVariables=logConfigVariable($configFileVariables,"combineMemoryNeeded",$combineMemoryNeeded);

	print "\n";
	
	# get the mode for each resolution - cis/genome
	my $binModes="";
	($binSizes,$binLabels,$binModes)=getBinModes($binSizes,$binLabels);
	print "\n";
	print "\t\tbinSizes\t$binSizes\n";
	print "\t\tbinLabels\t$binLabels\n";
	print "\t\tbinModes\t$binModes\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"binSizes",$binSizes);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"binLabels",$binLabels);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"binModes",$binModes);
	
	print "\n\tignoreDiagonal [0] :\t";
	my $userIgnoreDiagonal = <STDIN>;
	chomp($userIgnoreDiagonal);
	my $ignoreDiagonal = 0;
	$ignoreDiagonal = $userIgnoreDiagonal if(($userIgnoreDiagonal =~ (/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/)) and ($userIgnoreDiagonal > 0));
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"ignoreDiagonal",$ignoreDiagonal);
	print "\t\t$ignoreDiagonal\n";
	
	print "\n\tsameStrandOnly [n] :\t";
	my $userSameStrand = <STDIN>;
	chomp($userSameStrand);
	my $sameStrand = "n";
	$sameStrand = $userSameStrand if($userSameStrand eq "y");
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"sameStrand",$sameStrand);
	print "\t\t$sameStrand\n";
	
	print "\n";
	
	my ($outputFolder,$userHomeDirectory)=getDefaultOutputFolder($adminMode);
	my $userOutputFolder = "";
	if($adminMode != 1) {
		print "\toutputFolder [$outputFolder] :\t";
		$userOutputFolder = <STDIN>;
		chomp($userOutputFolder);
		$outputFolder = $userOutputFolder if($userOutputFolder ne "");
		$outputFolder .= "/" if($outputFolder !~ /\/$/);
		$outputFolder = $userHomeDirectory."/".$outputFolder if($outputFolder !~ /^\//);
		system("mkdir -p $outputFolder") if(!(-d $outputFolder));
		die("warning - cannot use specified outputFolder ($outputFolder)\n") if(!(-d $outputFolder));
	} else {
		print "\toutputFolder [$outputFolder]\n";
	}
	print "\t\t$outputFolder\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"outputFolder",$outputFolder);
	
	print "\n";
	
	print "\treduceScratchDir [$reduceScratchDir]\n";
	print "\tmapScratchDir [$mapScratchDir] :\t";
	my $userScratchDir = <STDIN>;
	chomp($userScratchDir);
	$mapScratchDir = $userScratchDir if($userScratchDir ne "");
	$mapScratchDir =~ s/\/$// if($mapScratchDir =~ /\/$/); # remove trailing / 
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"mapScratchDir",$mapScratchDir);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"reduceScratchDir",$reduceScratchDir);
	print "\t\t$mapScratchDir\n";
	
	print "\n";
	
	my $logDirectory=$userHomeDirectory."/cshare/cWorld-logs";
	print "\tlogDirectory [$logDirectory]: ";
	my $userLogDirectory = <STDIN>;
	chomp($userLogDirectory);
	$userLogDirectory =~ s/\/$//;
	$logDirectory=$userLogDirectory if(-d($userLogDirectory));
	print "\t\t$logDirectory\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"logDirectory",$logDirectory);
	
	my $UUID=getUniqueString();
	my $configFilePath=$logDirectory."/".$UUID.".cWorld-stage2.cfg";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"UUID",$UUID);
	print "\t\t$configFilePath\n";
	my $reduceID=getSmallUniqueString();
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"reduceID",$reduceID);
	
	print "\n";	
	
	my $jobName=$sampleName."__".$genomeName;
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"jobName",$jobName);
	
	print "\tprocessing ($jobName)...\n";
		
	my $cFileString="";
	for(my $i=0;$i<$arraySize;$i++) {
		my $cFile=$tmpArray[$i];
		$cFileString .= "," . $cFile if($cFileString ne "");
		$cFileString = $cFile if($cFileString eq "");
	}
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"inputFileString",$cFileString);
	
	printConfigFile($configFileVariables,$tmpConfigFileVariables,$configFilePath);
	
	print "\n";
	print "\tsubmitting map HiC ($combineMemoryNeeded)...\n";
	my $return=`ssh ghpcc06 "source /etc/profile; bsub -n 2 -q $combineQueue -R span[hosts=1] -R rusage[mem=$combineMemoryNeeded] -W $combineTimeNeeded -N -u bryan.lajoie\@umassmed.edu -J combineHiCWrapper -o /home/bl73w/lsf_jobs/LSB_%J.log -e /home/bl73w/lsf_jobs/LSB_%J.err $cMapping/scripts/combineHiCWrapper.sh $configFilePath"`;
	chomp($return);
	print "\t$return\n";
	print "\n";
		
}