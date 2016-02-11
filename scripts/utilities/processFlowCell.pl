use strict;
use English;
use File::Find;
use POSIX qw(ceil floor);
use List::Util qw(max min);
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Cwd;
use Cwd 'abs_path';

sub check_options {
	my $opts = shift;
	
	my ($codeTree,$genomeName,$hicModeFlag,$fiveCModeFlag,$keepSAM,$quietModeFlag,$assumeCisAllele,$enzyme,$splitSize,$restrictionSite,$shortMode,$snpModeFlag,$adminModeFlag,$debugModeFlag);
 
	if( defined($opts->{ codeTree }) ) {
		$codeTree = $opts->{ codeTree };
		die("Invalid codeTree! ($codeTree)\n") if(!(-d ($ENV{"HOME"}."/cMapping/$codeTree")));
	} else {
		$codeTree="prod";
	}
	
	if( defined($opts->{ genomeName }) ) {
		$genomeName = $opts->{ genomeName };
	} else {
		$genomeName="";
	}
	
	if( defined($opts->{ hicModeFlag }) ) {
		$hicModeFlag = 1;
	} else {
		$hicModeFlag=0;
	}
	
	if( defined($opts->{ fiveCModeFlag }) ) {
		$fiveCModeFlag = 1;
	} else {
		$fiveCModeFlag=0;
	}
	
	if( defined($opts->{ keepSAM }) ) {
		$keepSAM = 1;
	} else {
		$keepSAM=0;
	}
	
	if( defined($opts->{ quietModeFlag }) ) {
		$quietModeFlag = 1;
	} else {
		$quietModeFlag=0;
	}
	
	if( defined($opts->{ assumeCisAllele }) ) {
		$assumeCisAllele = 1;
	} else {
		$assumeCisAllele = 0;
	}
	
	if( defined($opts->{ enzyme }) ) {
		$enzyme = $opts->{ enzyme };
	} else {
		$enzyme = "HindIII";
	}
	
	if( defined($opts->{ splitSize }) ) {
		$splitSize = $opts->{ splitSize };
		if($splitSize < 1000000) {
			print "WARNING - using a very small split size (debug) continue? [y,n]: ";
			my $answer=<STDIN>;
			chomp($answer);
			die("exiting") if($answer ne "y");
		}
	} else {
		$splitSize=4000000;
	}
	
	if( defined($opts->{ shortMode }) ) {
		$shortMode = 1;
	} else {
		$shortMode=0;
	}
	
	if( defined($opts->{ snpModeFlag }) ) {
		$snpModeFlag = 1;
	} else {
		$snpModeFlag=0;
	}
	
	if( $opts->{ adminModeFlag } ) {
		$adminModeFlag=1;
	} else {
		$adminModeFlag=0;
	}
	
	if( $opts->{ debugModeFlag } ) {
		$debugModeFlag=1;
	} else {
		$debugModeFlag=0;
	}
	
	return($codeTree,$genomeName,$hicModeFlag,$fiveCModeFlag,$keepSAM,$quietModeFlag,$assumeCisAllele,$enzyme,$splitSize,$restrictionSite,$shortMode,$snpModeFlag,$adminModeFlag,$debugModeFlag);
}

sub getDate() {

	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
	my $time = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
	
	return($time);
}

sub getAlignmentSoftware($) {
	my $codeTree=shift;
	
	my $userHomeDirectory = getUserHomeDirectory();
	
	my %alignmentSoftware=();
	$alignmentSoftware{ bowtie2 }=$userHomeDirectory."/cMapping/".$codeTree."/aligners/bowtie/bowtie2-2.2.4/bowtie2";
	$alignmentSoftware{ novoCraft }=$userHomeDirectory."/cMapping/".$codeTree."/aligners/novocraft/3.02.00/novoalign";
	
	return(\%alignmentSoftware);
}

sub getRestrictionEnzymeSequences() {
	my %restrictionEnzymeSequences=();
	
	$restrictionEnzymeSequences{ HindIII } = "AAGCTT";
	$restrictionEnzymeSequences{ EcoRI } = "GAATTC";
	$restrictionEnzymeSequences{ NcoI } = "CCATGG";
	$restrictionEnzymeSequences{ DpnII } = "GATC";
	$restrictionEnzymeSequences{ MboI } = "GATC";
	$restrictionEnzymeSequences{ MNase } = "MNase";
	$restrictionEnzymeSequences{ BglII } = "AGATCT";
	$restrictionEnzymeSequences{ NcoI } = "CCATGG";
	
	return(\%restrictionEnzymeSequences);
}
	
sub getGenomePath($$$) {
	my $aligner=shift;
	my $genomeName=shift;
	my $restrictionSite=shift;
	
	my $userHomeDirectory = getUserHomeDirectory();
	
	my $fastaDirectory=$userHomeDirectory."/genome/fasta/".$genomeName;
	my $genomeDirectory=$userHomeDirectory."/genome/".$aligner."/".$genomeName;
	my $restrictionFragmentFile=$userHomeDirectory."/genome/restrictionFragments/".$genomeName."/".$genomeName."__".$restrictionSite.".txt";
	
	die("invalid genome directory ($genomeDirectory)\n") if(!(-d($genomeDirectory)));
	die("invalid fasta directory ($fastaDirectory)\n") if(!(-d($fastaDirectory)));
	die("invalid restriction fragment file ($restrictionFragmentFile)\n") if(!(-e($restrictionFragmentFile)));
	
	return($fastaDirectory,$restrictionFragmentFile);
}

sub getUserHomeDirectory() {
	my $userHomeDirectory = `echo \$HOME`;
	chomp($userHomeDirectory);
	return($userHomeDirectory);
}

sub getDefaultOutputFolder($$$) {
	my $adminModeFlag = shift;
	my $flowCell = shift;
	my $laneName = shift;
	
	my $userHomeDirectory = getUserHomeDirectory();
	
	my $outputFolder=$userHomeDirectory."/scratch/cData/$flowCell/$laneName";
	$outputFolder=$userHomeDirectory."/farline/HPCC/cshare/cData/$flowCell/$laneName" if($adminModeFlag == 1);
	
	return($outputFolder,$userHomeDirectory);
}

sub readFlowCellDirectory($) {
	my $dataDirectory=shift;
	$dataDirectory =~ s/\/$//;

	opendir(BIN, $dataDirectory) or die "Can't open $dataDirectory: $!";
	my @fileNames = readdir BIN ;
	close(BIN);
	my $nFiles = @fileNames;
	
	my @lanes=();
	for(my $i=0; $i<$nFiles; $i++) {
		my $dataFileName=$fileNames[$i];		
		
		next if ($dataFileName =~ /^\.\.?$/);
		
		push(@lanes,$dataFileName) if(-d $dataDirectory."/".$dataFileName);
	}
	
	return(\@lanes);
}

sub searchForFASTQ($$$$$$$) {
	my $fastqFiles=shift;
	my $dataDirectory=shift;
	$dataDirectory =~ s/\/$//;
	my $laneNum=shift;
	my $side1FastqFile=shift;
	my $side2FastqFile=shift;
	my $readLength=shift;
	my $zippedFlag=shift;
	
	opendir(BIN, $dataDirectory) or die "Can't open $dataDirectory: $!";
	my @fileNames = readdir BIN ;
	close(BIN);
	my $nFiles = @fileNames;
	
	my $index="";
	my $last_side1_dataFileName="";
	my $last_side2_dataFileName="";
	
	for(my $i=0; $i<$nFiles; $i++) {
		my ($side1File,$side2File);
		
		my $dataFileName=$fileNames[$i];		
		
		next if ($dataFileName =~ /^\.\.?$/);
		next if ($dataFileName =~ /^\./);
		
		if(-d $dataDirectory."/".$dataFileName) {
			
			searchForFASTQ($fastqFiles,$dataDirectory."/".$dataFileName,$laneNum,$side1FastqFile,$side2FastqFile,$readLength,$zippedFlag) if(($dataFileName =~ /bustard/i) or ($dataFileName =~ /gerald/i));
			
		} else {
		
			next if(($dataFileName !~ /.fq$/) and ($dataFileName !~ /_sequence.txt/) and ($dataFileName !~ /.fastq$/) and ($dataFileName !~ /.fastq.gz$/));
			
			if($dataFileName =~ /\.gz$/) {
				
				my $fastqFile=$dataDirectory."/".$dataFileName;
				my $sampleLine = `zcat $fastqFile | head -n 2 | tail -n 1`;
				chomp($sampleLine);
				my $readLength = length($sampleLine);
				my @tmp=split(/_/,$dataFileName);
				
				$index=$tmp[1] if(@tmp == 5);
				die("\nfile name error ($dataFileName | @tmp)\n") if(@tmp != 5);
				
				foreach(@tmp) { $laneNum = $_ if($_ =~ /L[0-9]{3}/); }
				$laneNum =~ s/L00//;
				
				my $tmp_dataFileName=$dataFileName;
				$tmp_dataFileName =~ s/_[0-9]{3}\.fastq\.gz/_\*\.fastq\.gz/;
				$tmp_dataFileName =~ s/\_$index\_/\_\*\_/;
				
				my $side="NA";
				$side=1 if($tmp_dataFileName =~ /_R1_/);
				$side=2 if($tmp_dataFileName =~ /_R2_/);
				
				die("Multiple file names detected!\n\t$last_side1_dataFileName vs $tmp_dataFileName") if(($side == 1) and (($last_side1_dataFileName ne "") and ($last_side1_dataFileName ne $tmp_dataFileName)));
				die("Multiple file names detected!\n\t$last_side2_dataFileName vs $tmp_dataFileName") if(($side == 2) and (($last_side2_dataFileName ne "") and ($last_side2_dataFileName ne $tmp_dataFileName)));
				
				$fastqFiles->{$side}->{"path"}=$dataDirectory."/".$tmp_dataFileName if(($side == 1) or ($side == 2));
				$fastqFiles->{$side}->{"readLength"}=$readLength if(($side == 1) or ($side == 2));
				$fastqFiles->{"laneNum"}=$laneNum;
				
				$zippedFlag=1;
				$last_side1_dataFileName=$tmp_dataFileName if($side == 1);
				$last_side2_dataFileName=$tmp_dataFileName if($side == 2);
				
			} else {
				
				my $fastqFile=$dataDirectory."/".$dataFileName;
				my $sampleLine = `head -n 2 $fastqFile | tail -n 1`;
				chomp($sampleLine);
				my $readLength = length($sampleLine);
				$laneNum=(split(/_/,$dataFileName))[1];
				
				my $side="NA";
				$side=1 if($dataFileName =~ /s_.+_1_sequence.txt/);
				$side=2 if($dataFileName =~ /s_.+_2_sequence.txt/);
				
				$fastqFiles->{$side}->{"path"}=$dataDirectory."/".$dataFileName if(($side == 1) or ($side == 2));
				$fastqFiles->{$side}->{"readLength"}=$readLength if(($side == 1) or ($side == 2));
				$fastqFiles->{"laneNum"}=$laneNum;
				
			}
			
		}
	}
	
	print STDERR "Warning - encountered single end reads! - skipping\n" if( (!exists($fastqFiles->{1})) or (!exists($fastqFiles->{2})) );
	next if( (!exists($fastqFiles->{1})) or (!exists($fastqFiles->{2})) );
	
	my $side1FastqFile=$fastqFiles->{1}->{"path"};
	my $side1ReadLength=$fastqFiles->{1}->{"readLength"};
	my $side2FastqFile=$fastqFiles->{2}->{"path"};
	my $side2ReadLength=$fastqFiles->{2}->{"readLength"};
	my $laneNum=$fastqFiles->{"laneNum"};
	
	print "\n\t\tWARNING: read lengths are not equal!\n\t\t\t(side1 - $side1ReadLength | side2 - $side2ReadLength)!\n\n" if(abs($side1ReadLength-$side2ReadLength) > 1);
	my $readLength=min($side1ReadLength,$side2ReadLength);
	
	return($fastqFiles,$dataDirectory,$laneNum,$side1FastqFile,$side2FastqFile,$readLength,$zippedFlag);

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
	
	print OUT "# cWorld processFlowCell\n";
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


sub intro() {
	print "\n";
	
	print "Tool:\t\tprocessFlowCell.pl\n";
	print "Version:\t1.0.0\n";
	print "Summary:\tbsub wrapper for dekkerlab mapping\n";
	
	print "\n";
}

sub help() {
	intro();
	
	print "Usage: perl processFlowCell.pl [OPTIONS] <pathToFlowCellDir>\n";
	
	print "\n";
	
	print "Options:\n";

	printf("\n\t%-10s %-10s %-10s\n", "-g", "[]", "genomeName, genome to align");
	printf("\n\t%-10s %-10s %-10s\n", "-c", "[]", "codeTree, which version of pipeline to use (alpha,beta,prod)");
	printf("\n\t%-10s %-10s %-10s\n", "-h", "[]", "FLAG, hic flag ");
	printf("\n\t%-10s %-10s %-10s\n", "-f", "[]", "FLAG, 5C flag");
	printf("\n\t%-10s %-10s %-10s\n", "-ks", "[]", "FLAG, keep sam files");
	printf("\n\t%-10s %-10s %-10s\n", "-short", "[]", "FLAG, use the short queue");
	printf("\n\t%-10s %-10s %-10s\n", "-sm", "[]", "FLAG, snpMode - allelic Hi-C");
	printf("\n\t%-10s %-10s %-10s\n", "-a", "[]", "FLAG, adminMode - soon to be deprecated");
	printf("\n\t%-10s %-10s %-10s\n", "-d", "[]", "FLAg, debugMode - keep all files for debug purposes");
	
	print "\n";
	
	print "Notes:";
	print "
	This script is a wrapper for bsub commands\n";
	
	print "\n";
	
	print "Contact:
	Dekker Lab
	http://my5C.umassmed.edu
	my5C.help\@umassmed.edu\n";
	
	print "\n";
	
	exit;
}


my %options;
my $results = GetOptions( \%options,'hicModeFlag|h','genomeName|g=s','fiveCModeFlag|f','keepSAM|ks','quietModeFlag|q','assumeCisAllele|aca','enzyme|e=s','splitSize|s=s','codeTree|c=s','restrictionSite|rs=s','shortMode|short','snpModeFlag|sm','adminModeFlag|a','debugModeFlag|d');
my ($codeTree,$genomeName,$hicModeFlag,$fiveCModeFlag,$keepSAM,$quietModeFlag,$assumeCisAllele,$enzyme,$splitSize,$restrictionSite,$shortMode,$snpModeFlag,$adminModeFlag,$debugModeFlag)=check_options( \%options );

my $flowCellDirectory="";
if(@ARGV == 1) {
	$flowCellDirectory=$ARGV[0];
} else {
	help();
}

my $configFileVariables={};
my $userHomeDirectory = getUserHomeDirectory();
my $cMapping = $userHomeDirectory."/cMapping/".$codeTree;

$configFileVariables=logConfigVariable($configFileVariables,"codeTree",$codeTree);
$configFileVariables=logConfigVariable($configFileVariables,"cMapping",$cMapping);
$configFileVariables=logConfigVariable($configFileVariables,"keepSAM",$keepSAM);
$configFileVariables=logConfigVariable($configFileVariables,"quietModeFlag",$quietModeFlag);
$configFileVariables=logConfigVariable($configFileVariables,"splitSize",$splitSize);
$configFileVariables=logConfigVariable($configFileVariables,"hicModeFlag",$hicModeFlag);
$configFileVariables=logConfigVariable($configFileVariables,"snpModeFlag",$snpModeFlag);
$configFileVariables=logConfigVariable($configFileVariables,"fiveCModeFlag",$fiveCModeFlag);
$configFileVariables=logConfigVariable($configFileVariables,"debugModeFlag",$debugModeFlag);

# setup scratch space
my $reduceScratchDir=$userHomeDirectory."/scratch";
my $mapScratchDir="/tmp";
$mapScratchDir=$userHomeDirectory."/scratch" if($debugModeFlag == 1);

# setup queue/timelimit for LSF
my $reduceQueue="long";
$reduceQueue="short" if(($debugModeFlag == 1) or ($shortMode == 1));
my $reduceTimeNeeded="120:00";
$reduceTimeNeeded="04:00" if(($debugModeFlag == 1) or ($shortMode ==1));
$configFileVariables=logConfigVariable($configFileVariables,"reduceQueue",$reduceQueue);
$configFileVariables=logConfigVariable($configFileVariables,"reduceTimeNeeded",$reduceTimeNeeded);

my $computeResource = getComputeResource();
$configFileVariables=logConfigVariable($configFileVariables,"computeResource",$computeResource);

if($adminModeFlag == 1) {
	print "WARNING - adminModeFlag is ON - continue? (y/n) [n] : ";
	my $response=<STDIN>;
	chomp($response);
	die("Cannot continue without valid response\n") if($response ne "y");
}

die("ERROR - must choose either -f (5C) or -h (HiC) mode option\n\n") if( (($fiveCModeFlag+$hicModeFlag) <= 0) or (($fiveCModeFlag+$hicModeFlag) >= 2) );
die("ERROR - cannot use SNP mode with -f option\n\n") if(($snpModeFlag+$fiveCModeFlag >= 2) );

$flowCellDirectory =~ s/\/$//;

my $lanesRef=readFlowCellDirectory($flowCellDirectory);
my $nLanes=@$lanesRef;

for(my $i=0;$i<$nLanes;$i++) {

	my $tmpConfigFileVariables={};
	
	my $laneName=$lanesRef->[$i];
	
	print "\n\t$laneName | process? (y,n) [n]: ";
	my $processFlag = <STDIN>;
	chomp($processFlag);
	$processFlag = "n" if($processFlag eq "");
	next if($processFlag ne "y");
	
	my @tmp=split(/\//,$flowCellDirectory);
	my $flowCellName=$tmp[@tmp-1];
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"flowCellName",$flowCellName);
	
	my $emptyHashRef={};
	my ($fastqFiles,$dataDirectory,$laneNum,$side1File,$side2File,$readLength,$zippedFlag)=searchForFASTQ($emptyHashRef,$flowCellDirectory."/".$laneName,0,"NA","NA",0,0);
	
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"flowCellName",$flowCellName);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"laneName",$laneName);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"laneNum",$laneNum);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"side1File",$side1File);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"side2File",$side2File);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"readLength",$readLength);

	print "\t\t$laneName [$laneNum]\n";
	print "\t\t(1)\t$side1File\t$readLength\n";
	print "\t\t(2)\t$side2File\t$readLength\n";	
	
	my $workDirectory = $flowCellDirectory;
	$workDirectory =~ s/$flowCellName//;
	$workDirectory =~ s/\/$//;
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"workDirectory",$workDirectory);
	
	print "\n";
	
	print "\t\treduceScratchDir [$reduceScratchDir]\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"reduceScratchDir",$reduceScratchDir);
	
	print "\t\tmapScratchDir [$mapScratchDir] :\t";
	my $userScratchDir = <STDIN>;
	chomp($userScratchDir);
	$mapScratchDir = $userScratchDir if($userScratchDir ne "");
	$mapScratchDir =~ s/\/$// if($mapScratchDir =~ /\/$/); # remove trailing / 
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"mapScratchDir",$mapScratchDir);
	print "\t\t\t$mapScratchDir\n";
	
	# assume 1 byte per ASCII.
	# 40 chars per header line
	# readLength chars per SEQ/QV line
	my $mapScratchSize = (((40*2)+($readLength*2))*($splitSize/4));
	$mapScratchSize = ceil((($mapScratchSize)/1024)/1024);
	$mapScratchSize = ($mapScratchSize * 10); #assume 10 fold input data of max /tmp usage
	print "\t\t\t".$mapScratchSize."M\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"mapScratchSize",$mapScratchSize);
	
	my $reduceScratchSize = 10000;
	print "\t\t\t".$reduceScratchSize."M\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"reduceScratchSize",$reduceScratchSize);
	
	my ($outputFolder,$userHomeDirectory)=getDefaultOutputFolder($adminModeFlag,$flowCellName,$laneName);
	if($adminModeFlag != 1) {
		print "\t\toutputFolder [$outputFolder] :\t";
		my $userOutputFolder = <STDIN>;
		chomp($userOutputFolder);
		$outputFolder = $userOutputFolder if($userOutputFolder ne "");
		$outputFolder =~ s/\/$// if($outputFolder =~ /\/$/); # remove trailing / 
		$outputFolder = $userHomeDirectory."/".$outputFolder if($outputFolder !~ /^\//);
		system("mkdir -p $outputFolder") if(!(-d $outputFolder));
		die("warning - cannot use specified outputFolder ($outputFolder)\n") if(!(-d $outputFolder));
	} else {
		print "\t\toutputFolder [$outputFolder]\n";
	}
	print "\t\t\t$outputFolder\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"outputFolder",$outputFolder);
	
	print "\t\tzipModeFlag: $zippedFlag\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"zippedFlag",$zippedFlag);
	
	my $alignmentSoftware=getAlignmentSoftware($codeTree);
	
	# alignment software choice
	my $aligner="bowtie2";	
	if(($hicModeFlag == 1) and ($snpModeFlag == 0) ) {
		print "\t\taligner (bowtie2,novoCraft) [$aligner]: ";
		my $userAligner = <STDIN>;
		chomp($userAligner);
		die("invalid aligner ($userAligner)!") if(($userAligner ne "") and (($userAligner ne "bowtie2") and ($userAligner ne "novoCraft")));
		$aligner = $userAligner if($userAligner ne "");
	} else {  # SNP mode or 5C mode
		$aligner="novoCraft";
	}
	print "\t\t\t$aligner\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"aligner",$aligner);
	
	# alignment software path choice
	my $alignmentSoftwarePath="ERROR";
	$alignmentSoftwarePath=$alignmentSoftware->{ $aligner } if(exists($alignmentSoftware->{ $aligner }));
	print "\t\talignerPath [$alignmentSoftwarePath]: ";
	my $userAlignmentSoftwarePath = <STDIN>;
	chomp($userAlignmentSoftwarePath);
	$alignmentSoftwarePath=$userAlignmentSoftwarePath if($userAlignmentSoftwarePath ne "");
	die("aligner path does not exist! {$alignmentSoftwarePath}\n") if(!(-e($alignmentSoftwarePath)));
	print "\t\t\t$alignmentSoftwarePath\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"alignmentSoftwarePath",$alignmentSoftwarePath);
		
	# alignment options choice
	my $alignmentOptions="";
	$alignmentOptions="--very-sensitive --no-hd --no-sq --mm --qc-filter" if($aligner eq "bowtie2");
	$alignmentOptions=" -r all 5 -R 30 -q 2" if(($aligner eq "novoCraft") and ($snpModeFlag == 1));
	print "\t\talignmentOptions [$alignmentOptions]: ";
	my $userAlignmentOptions = <STDIN>;
	chomp($userAlignmentOptions);
	$alignmentOptions=$userAlignmentOptions if($userAlignmentOptions ne "");
	print "\t\t\t$alignmentOptions\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"alignmentOptions",$alignmentOptions);
	
	# alignment options choice
	my $optionalSide1AlignmentOptions="";
	print "\t\toptional side1 alignmentOptions []: ";
	my $userOptionalSide1AlignmentOptions = <STDIN>;
	chomp($userOptionalSide1AlignmentOptions);
	$optionalSide1AlignmentOptions=$userOptionalSide1AlignmentOptions if($userOptionalSide1AlignmentOptions ne "");
	print "\t\t\t$optionalSide1AlignmentOptions\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"optionalSide1AlignmentOptions",$optionalSide1AlignmentOptions);
	
	# alignment options choice
	my $optionalSide2AlignmentOptions="";
	print "\t\toptional side2 alignmentOptions []: ";
	my $userOptionalSide2AlignmentOptions = <STDIN>;
	chomp($userOptionalSide2AlignmentOptions);
	$optionalSide2AlignmentOptions=$userOptionalSide2AlignmentOptions if($userOptionalSide2AlignmentOptions ne "");
	print "\t\t\t$optionalSide2AlignmentOptions\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"optionalSide2AlignmentOptions",$optionalSide2AlignmentOptions);
	
	my $minimumReadDistance=5;
	if(($aligner eq "novoCraft") and ($snpModeFlag == 1)) {
		print "\t\tminimumReadDistance [5] : ";
		my $userMinimumReadDistance = <STDIN>;
		chomp($userMinimumReadDistance);
		$minimumReadDistance = $userMinimumReadDistance if($userMinimumReadDistance ne "");
		print "\t\t\t$minimumReadDistance\n";
		$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"minimumReadDistance",$minimumReadDistance);
	}
	
	if($snpModeFlag == 1) {
		print "\t\tassumeCisAllele [on] : ";
		my $userAssumeCisAllele = <STDIN>;
		chomp($userAssumeCisAllele);
		$assumeCisAllele=0 if(($userAssumeCisAllele ne "on") and ($userAssumeCisAllele ne "") and ($userAssumeCisAllele != 1));
		print "\t\t\t$assumeCisAllele\n";
	}
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"assumeCisAllele",$assumeCisAllele);
	
	# enzyme choice 
	my $restrictionEnzymeSequences=getRestrictionEnzymeSequences();
	my $enzymeString=join(',', (keys %{$restrictionEnzymeSequences}));

	my $restructionSite="NA";
	if($hicModeFlag == 1) {
		print "\t\tenzyme (".$enzymeString.") [".$enzyme."] : ";
		my $userEnzyme = <STDIN>;
		chomp($userEnzyme);
		$enzyme=$userEnzyme if($userEnzyme ne "");
		die("Invalid Restriction Enzyme! ($enzyme)\n") if(!(exists($restrictionEnzymeSequences->{ $enzyme })));
		$restrictionSite=$restrictionEnzymeSequences->{ $enzyme };
		print "\t\t\t$enzyme / $restrictionSite\n";
	} else {
		$enzyme = "NA";
	}
	
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"enzyme",$enzyme);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"restrictionSite",$restrictionSite);
	
	my $iterativeMappingFlag=0;
	my $iterativeMappingStart=$readLength;
	my $iterativeMappingEnd=$readLength;
	my $iterativeMappingStep=5;
	
	if(($hicModeFlag == 1) and ($fiveCModeFlag == 0) and ($snpModeFlag == 0)) { #HiC data
		
		$iterativeMappingFlag=1;
		print "\t\titerative mapping mode? [on] (on|off): ";
		my $userIterativeMappingFlag = <STDIN>;
		chomp($userIterativeMappingFlag);		
		$iterativeMappingFlag = 0 if($userIterativeMappingFlag eq "off");
		print "\t\t\t".translateFlag($iterativeMappingFlag)."\n";
		
		# default iterative mapping options - if off (use full length read)
	
		if($iterativeMappingFlag == 1) {
			print "\t\t\titerativeMappingStart [25] : ";
			$iterativeMappingStart = <STDIN>;
			chomp($iterativeMappingStart);
			$iterativeMappingStart = 25 if($iterativeMappingStart eq "");
		
			print "\t\t\titerativeMappingEnd [$readLength] : ";
			$iterativeMappingEnd = <STDIN>;
			chomp($iterativeMappingEnd);
			$iterativeMappingEnd = $readLength if(($iterativeMappingEnd eq "") or ($iterativeMappingEnd < $iterativeMappingStart) or ($iterativeMappingEnd > $readLength));
		
			print "\t\t\titerativeMappingStep [5] : ";
			$iterativeMappingStep = <STDIN>;
			chomp($iterativeMappingStep);
			$iterativeMappingStep = 5 if(($iterativeMappingStep eq "") or ($iterativeMappingStep < 2));
			
			print "\t\t\t\titerativeMapping $iterativeMappingStart - $iterativeMappingEnd [$iterativeMappingStep]\n";
		}

	}
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"iterativeMappingFlag",$iterativeMappingFlag);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"iterativeMappingStart",$iterativeMappingStart);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"iterativeMappingEnd",$iterativeMappingEnd);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"iterativeMappingStep",$iterativeMappingStep);
	
	# genomeName choice
	print "\t\tgenome [".$genomeName."]: ";
	my $genome = <STDIN>;
	chomp($genome);
	
	$genomeName = $genome if($genome ne "");
	
	print "\n\tMust select a genome! ($genome | $genomeName) - skipping lane...\n\n" if($genomeName eq "");
	
	my $fastaPath="NA";
	my $restrictionFragmentPath="NA";
	if($hicModeFlag == 1) {
		($fastaPath,$restrictionFragmentPath)=getGenomePath($aligner,$genomeName,$restrictionSite);
		$restrictionFragmentPath="" if($snpModeFlag == 1);
		print "\t\t\t$fastaPath\n";
		print "\t\trestrictionFragmentPath [$restrictionFragmentPath]: ";
		if($snpModeFlag == 1) {
			my $userRestrictionFragmentPath = <STDIN>;
			chomp($userRestrictionFragmentPath);
			$userRestrictionFragmentPath = "" if(!(-e($userRestrictionFragmentPath)));
			$restrictionFragmentPath = $userRestrictionFragmentPath if($userRestrictionFragmentPath ne "");
		} else {
			print "\n";
		}
		die("invalid restriction fragment file path!\n") if(!(-e($restrictionFragmentPath)));
		print "\t\t\t$restrictionFragmentPath\n";
	}
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"restrictionFragmentPath",$restrictionFragmentPath);
	
	my $genomePath=$userHomeDirectory."/genome/$aligner/$genomeName";
	my $genomeDir=$userHomeDirectory."/genome/$aligner/$genomeName";
	if(($hicModeFlag == 1) and ($fiveCModeFlag == 0)) {
		$genomePath .= "/".$genomeName;
		die("invalid genome path! (".$genomePath."*)\n") if( (!(glob($genomePath))) and (!(glob($genomePath."*"))) );
	}
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"genomeName",$genomeName);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"genomePath",$genomePath);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"genomeDir",$genomeDir);
	
	my $indexSize=`du -b $genomeDir`;
	chomp($indexSize);
	$indexSize=(split(/\t/,$indexSize))[0];
	# add 8GB to each, to account for working memory per tile size (8)
	my $indexSizeMegabyte = 8198+(ceil(($indexSize*1.25) / 1000000)); # scale index size by 1.25 fold
	my $splitSizeMegabyte = 8192+(ceil(((500*($splitSize/4))/1000)/1000)); # assume 500 bytes per line of side1+side2 SAM
	
	my $intervalSizeMegabyte=0;
	if($hicModeFlag == 1) {
		my $intervalSize=`du -b $restrictionFragmentPath`;
		chomp($intervalSize);
		$intervalSize=(split(/\t/,$intervalSize))[0];
		$intervalSizeMegabyte = (ceil(($intervalSize*1.25) / 1000000)); # scale interval size by 1.25 fold
	}
	my $mapMemoryNeededMegabyte=max($indexSizeMegabyte,$splitSizeMegabyte,$intervalSizeMegabyte);
	my $reduceMemoryNeededMegabyte=max(($splitSizeMegabyte*2),$intervalSizeMegabyte);
	
	print "\t\t\t\t indexSizeMegabyte (".$indexSizeMegabyte."M) memory...\n";
	print "\t\t\t\t splitSizeMegabyte (".$splitSizeMegabyte."M) memory...\n";
	print "\t\t\t\t intervalSizeMegabyte (".$intervalSizeMegabyte."M) memory...\n";
	print "\t\t\t\t reduceMemoryNeededMegabyte (".$reduceMemoryNeededMegabyte."M) memory...\n";
	print "\t\t\t\t mapMemoryNeededMegabyte (".$mapMemoryNeededMegabyte."M) memory...\n";
	
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"indexSizeMegabyte",$indexSizeMegabyte);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"splitSizeMegabyte",$splitSizeMegabyte);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"intervalSizeMegabyte",$intervalSizeMegabyte);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"reduceMemoryNeededMegabyte",$reduceMemoryNeededMegabyte);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"mapMemoryNeededMegabyte",$mapMemoryNeededMegabyte);
	
	print "\t\temailTo (email address) [none]:\t";
	my $emailTo = <STDIN>;
	chomp($emailTo);
	$emailTo = "none" if(($emailTo eq "") or ($emailTo !~ /@/) or ($emailTo =~ /\s+/));
	print "\t\t\t$emailTo\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"emailTo",$emailTo);
	
	my $logDirectory=$userHomeDirectory."/cshare/cWorld-logs";
	print "\t\tlogDirectory [$logDirectory]: ";
	my $userLogDirectory = <STDIN>;
	chomp($userLogDirectory);
	$userLogDirectory =~ s/\/$//;
	$logDirectory=$userLogDirectory if(-d($userLogDirectory));
	print "\t\t\t$logDirectory\n";
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"logDirectory",$logDirectory);
	
	my $UUID=getUniqueString();
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"UUID",$UUID);
	my $jobName=$flowCellName."__".$laneName."__".$genomeName;
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"jobName",$jobName);
	
	my $configFilePath=$logDirectory."/".$UUID.".cWorld-stage1.cfg";
	print "\t\t\t$configFilePath\n";
	
	my $reduceID=getSmallUniqueString();
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"reduceID",$reduceID);
	
	my $cType="unknown";
	$cType="Hi-C" if($hicModeFlag == 1);
	$cType="5C" if($fiveCModeFlag == 1);
	die("invalid cType! ($cType)\n") if($cType eq "null");
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"cType",$cType);
	
	# calculate map time needed for LSF - assume split size is # lines not # reads (4 lines per read)
	my $mapTimeNeeded=((0.00004*$splitSize)-9.345);
	$mapTimeNeeded=((0.0003*$splitSize)+57)+720 if($snpModeFlag == 1);
	# this linear approximation is done using mm9 - bowtie (excel)
	
	my $genomeSizeFactor=max(1,($indexSizeMegabyte/3000));
	$genomeSizeFactor = log($genomeSizeFactor) if($genomeSizeFactor > 1);
	$mapTimeNeeded *= $genomeSizeFactor;
	$mapTimeNeeded *= 2 if($iterativeMappingFlag == 1);
	$mapTimeNeeded = 240 if($mapTimeNeeded < 240);
	$mapTimeNeeded = 240 if($shortMode == 1);
	my $mapTimeNeededHour = floor($mapTimeNeeded/60);
	$mapTimeNeededHour = sprintf("%02d", $mapTimeNeededHour);
	my $mapTimeNeededMinute = ($mapTimeNeeded%60);
	$mapTimeNeededMinute = sprintf("%02d", $mapTimeNeededMinute);
	my $mapQueue="short";
	$mapQueue="long" if($mapTimeNeeded > 240);
	$mapQueue="short" if($shortMode == 1);
	$mapTimeNeeded=$mapTimeNeededHour.":".$mapTimeNeededMinute;
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"mapTimeNeeded",$mapTimeNeeded);
	$tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"mapQueue",$mapQueue);
	print "\t\treduceResources\t$reduceQueue\t$reduceTimeNeeded\n";
	print "\t\tmapResources\t$mapQueue\t$mapTimeNeeded\n";
	
	printConfigFile($configFileVariables,$tmpConfigFileVariables,$configFilePath);
		
	if(($hicModeFlag == 1) and ($fiveCModeFlag == 0)) { #HiC data
		print "\n";
		print "\t\tsubmitting HiC (reduceMem=$reduceMemoryNeededMegabyte:mapMem=$mapMemoryNeededMegabyte:tmp=$mapScratchSize)...\n";
		my $return=`ssh ghpcc06 "source /etc/profile; bsub -n 2 -q $reduceQueue -R span[hosts=1] -R rusage[mem=$reduceMemoryNeededMegabyte:tmp=$reduceScratchSize] -W $reduceTimeNeeded -N -u bryan.lajoie\@umassmed.edu -J submitHiC -o /home/bl73w/lsf_jobs/LSB_%J.log -e /home/bl73w/lsf_jobs/LSB_%J.err $cMapping/scripts/submitHiC.sh $configFilePath"`;
		chomp($return);
		print "\t\t$return\n";
		print "\n";
	} elsif(($hicModeFlag == 0) and ($fiveCModeFlag == 1)) { #5C data
		print "\n";
		print "\t\tsubmitting 5C (reduceMem=$reduceMemoryNeededMegabyte:mapMem=$mapMemoryNeededMegabyte:tmp=$mapScratchSize)...\n";
		my $return=`ssh ghpcc06 "source /etc/profile; bsub -n 2 -q $reduceQueue -R span[hosts=1] -R rusage[mem=$reduceMemoryNeededMegabyte:tmp=$reduceScratchSize] -W $reduceTimeNeeded -N -u bryan.lajoie\@umassmed.edu -J submit5C -o /home/bl73w/lsf_jobs/LSB_%J.log -e /home/bl73w/lsf_jobs/LSB_%J.err $cMapping/scripts/submit5C.sh $configFilePath"`;
		chomp($return);
		print "\t\t$return\n";
		print "\n";
	}
	
}