#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
	my $opts = shift;

	my ($jobName,$interactionLogFile,$mappingLogFile,$pcrDupeLogFile,$alleleLogFile,$configFile);
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		die("input jobName|jn is required.\n");
	}
	
	if( exists($opts->{ interactionLogFile }) ) {
		$interactionLogFile = $opts->{ interactionLogFile };
	} else {
		die("input interactionLogFile|ilf is required.\n");
	}
	
	if( exists($opts->{ mappingLogFile }) ) {
		$mappingLogFile = $opts->{ mappingLogFile };
	} else {
		die("input mappingLogFile|mlf is required.\n");
	}
	
	if( exists($opts->{ pcrDupeLogFile }) ) {
		$pcrDupeLogFile = $opts->{ pcrDupeLogFile };
	} else {
		die("input pcrDupeLogFile|pdlf is required.\n");
	}
	
	if( exists($opts->{ alleleLogFile }) ) {
		$alleleLogFile = $opts->{ alleleLogFile };
	} else {
		die("input alleleLogFile|alf is required.\n");
	}

	if( exists($opts->{ configFile }) ) {
		$configFile = $opts->{ configFile };
	} else {
		die("input configFile|cf is required.\n");
	}
	
	return($jobName,$interactionLogFile,$mappingLogFile,$pcrDupeLogFile,$alleleLogFile,$configFile);
}

sub round($;$) {
	my $num=shift;  #the number to work on
	my $digs_to_cut=shift || 0;  # the number of digits after 
  
	my $roundedNum=$num;
	
	if($digs_to_cut == 0) {
		$roundedNum = int($num+0.5);
	} else {
		$roundedNum = sprintf("%.".($digs_to_cut)."f", $num) if($num =~ /\d+\.(\d){$digs_to_cut,}/);
	}
	
	return($roundedNum);
}

sub commify($) {
	my $num=shift;
	$num =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g; 
	return $num; 
}

sub baseName($) {
	my $fileName=shift;
	
	my $shortName=(split(/\//,$fileName))[-1];
	
	return($shortName);
}	

sub getDate() {

	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
	my $time = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
	
	return($time);
}

my %options;
my $results = GetOptions( \%options,'jobName|jn=s','interactionLogFile|ilf=s','mappingLogFile|mlf=s','pcrDupeLogFile|pdlf=s','alleleLogFile|alf=s','configFile|cf=s');
my ($jobName,$interactionLogFile,$mappingLogFile,$pcrDupeLogFile,$alleleLogFile,$configFile)=check_options( \%options );

die("interactionLogFile does not exist! ($interactionLogFile)\n") if(!(-e($interactionLogFile)));
die("mappingLogFile does not exist! ($mappingLogFile)\n") if(!(-e($mappingLogFile)));
die("pcrDupeLogFile does not exist! ($pcrDupeLogFile)\n") if(!(-e($pcrDupeLogFile)));
die("alleleLogFile does not exist! ($alleleLogFile)\n") if(!(-e($alleleLogFile)));
die("configFile does not exist! ($configFile)\n") if(!(-e($configFile)));

my %log=();
$log{ bounded } = 0;
$log{ internal } = 0;
$log{ cis__validPair } = 0;
$log{ trans__validPair } = 0;
$log{ inward } = 0;
$log{ outward } = 0;
$log{ topStrand } = 0;
$log{ bottomStrand } = 0;
$log{ unMapped } = 0;
$log{ singleSide } = 0;
$log{ selfCircle } = 0;
$log{ danglingEnd } = 0;
$log{ error } = 0;

# get config log info
open(IN,$configFile);
while(my $line = <IN>) {
	chomp($line);
	next if($line =~ /^#/);
	
	my ($field,$value)=split(/=/,$line);
	$value =~ s/"//g;
	$value="n/a" if($value eq "");
	$log{$field}=$value;
}
close(IN);

# get mapping log info
open(IN,$mappingLogFile);
while(my $line = <IN>) {
	chomp($line);
	next if($line =~ /^#/);
	
	my ($field,$value)=split(/\t/,$line);
	
	$log{$field}=$value;
}
close(IN);

# get pcr dupe log file
open(IN,$pcrDupeLogFile);
while(my $line = <IN>) {
	chomp($line);
	next if($line =~ /^#/);
	
	my ($field,$value)=split(/\t/,$line);

	$log{$field}=$value;
}
close(IN);

# get allele log info
my %alleleChoices=();
open(IN,$alleleLogFile);
while(my $line = <IN>) {
	chomp($line);
	next if($line =~ /^#/);
	
	my ($field,$value)=split(/\t/,$line);

	$alleleChoices{$field}=1;
	
	$log{$field}=$value;
}
close(IN);


my %header2index=();

my $lineNum=0;
open(IN,$interactionLogFile) or die "cannot open ($interactionLogFile) : $!";
while(my $line = <IN>) {
	chomp($line);
	
	next if($line =~ /^# /);
	next if($line eq "");
	
	if($lineNum == 0) {
		my @headers=split(/\t/,$line);
		for(my $i=0;$i<@headers;$i++) {
			my $header=$headers[$i];
			$header2index{$header}=$i;
		}
		$lineNum++;
		next;
	} 

	my @tmp=split(/\t/,$line);
	
	my $interactionCategory = $tmp[ $header2index{ interactionCategory } ];
	my $interactionClassification = $tmp[ $header2index{ interactionClassification } ];
	my $interactionType = $tmp[ $header2index{ interactionType } ];
	my $interactionSubType = $tmp[ $header2index{ interactionSubType }];
	my $directionClassification = $tmp[ $header2index{ directionClassification } ];
	my $count = $tmp[ $header2index{ count } ];
	
	$interactionClassification = $interactionClassification."__".$interactionType;
	$log{$interactionCategory} += $count;
	$log{$interactionClassification} += $count;
	$log{$interactionType} += $count;
	$log{$interactionSubType} += $count;
	$log{$directionClassification} += $count;
				
}
close(IN);

my $time = getDate();

open(OUT,">".$jobName.".end.mappingLog.txt");

print OUT "General\n";
print OUT "time\t".$time."\n";	
print OUT "cType\t".$log{ cType }."\n";
print OUT "logDirectory\t".$log{ logDirectory }."\n";
print OUT "UUID\t".$log{ UUID }."\n";
print OUT "cMapping\t".$log{ cMapping }."\n";
print OUT "computeResource\t".$log{ computeResource }."\n";
print OUT "reduceResources\t".$log{ reduceQueue }." / ".$log{ reduceTimeNeeded }."\n";
print OUT "mapResources\t".$log{ mapQueue }." / ".$log{ mapTimeNeeded }."\n";
print OUT "reduceScratchDir\t".$log{ reduceScratchDir }."\n";
print OUT "mapScratchDir\t".$log{ mapScratchDir }."\n";
print OUT "mapScratchSize\t".$log{ mapScratchSize }."M\n";
print OUT "nCPU\t".commify(ceil(($log{ nReads }*4)/$log{ splitSize }))."\n";
print OUT "reduceMemoryNeeded\t".commify($log{ reduceMemoryNeededMegabyte })."M\n";
print OUT "mapMemoryNeeded\t".commify($log{ mapMemoryNeededMegabyte })."M\n";
print OUT "debugMode\ton\n" if($log{ debugModeFlag } == 1);
print OUT "snpMode\ton\n" if($log{ snpModeFlag } == 1);

print OUT "\nDataset\n";
print OUT "jobName\t".$log{ jobName }."\n";
print OUT "flowCell\t".$log{ flowCellName }."\n";
print OUT "laneName\t".$log{ laneName }."\n";
print OUT "laneNum\t".$log{ laneNum }."\n";
print OUT "side1File\t".baseName($log{ side1File })."\n";
print OUT "side2File\t".baseName($log{ side2File })."\n";
print OUT "readLength\t".$log{ readLength }."\n";
print OUT "qvEncoding\t".$log{ qvEncoding }."\n";
print OUT "numReads\t".commify($log{ nReads })."\n";

print OUT "\nAlignment Options\n";
print OUT "splitSize\t".commify($log{ splitSize })."\n";
print OUT "splitSizeMegabyte\t".commify($log{ splitSizeMegabyte })."M\n";
print OUT "aligner\t".$log{ aligner }."\n";
print OUT "alignmentSoftwarePath\t".$log{ alignmentSoftwarePath }."\n";
print OUT "alignmentOptions\t".$log{ alignmentOptions }."\n";
print OUT "side1AlignmentOptions\t".$log{ optionalSide1AlignmentOptions }."\n";
print OUT "side2AlignmentOptions\t".$log{ optionalSide2AlignmentOptions }."\n";
print OUT "snp-minimumReadDistance\t".$log{ minimumReadDistance }."\n" if($log{ snpModeFlag } == 1);
print OUT "assumeCisAllele\t".$log{ assumeCisAllele }."\n" if($log{ snpModeFlag } == 1);
print OUT "enzyme\t".$log{ enzyme }."\n";
print OUT "restrictionSite\t".$log{ restrictionSite }."\n";
print OUT "restrictionFragmentFile\t".$log{ restrictionFragmentPath }."\n";
print OUT "genome\t".$log{ genomeName }."\n";
print OUT "genomePath\t".$log{ genomePath }."\n";
print OUT "genomeSize\t".commify($log{ indexSizeMegabyte })."M\n";

my $iterativeMapping="off";
$iterativeMapping="on" if($log{ iterativeMappingFlag } == 1);
print OUT "\nIterative Mapping Options\n";
print OUT "iterativeMapping\t".$iterativeMapping."\n";
print OUT "iterativeMappingStart\t".$log{ iterativeMappingStart }."\n";
print OUT "iterativeMappingEnd\t".$log{ iterativeMappingEnd }."\n";
print OUT "iterativeMappingStep\t".$log{ iterativeMappingStep }."\n";

my $side1_totalReads=0;
$side1_totalReads += $log{$_} for grep /^ML_side1_/, keys %log;
my $side2_totalReads=0;
$side2_totalReads += $log{$_} for grep /^ML_side2_/, keys %log;

print OUT "\nMapping Statistics\n";
print OUT "side1TotalReads\t".commify($side1_totalReads)."\n";
print OUT "side1NoMap\t".commify($log{ ML_side1_NM })."\t".round((($log{ ML_side1_NM }/$side1_totalReads)*100),2)."\n";
print OUT "side1MultiMap\t".commify($log{ ML_side1_MM })."\t".round((($log{ ML_side1_MM }/$side1_totalReads)*100),2)."\n";
print OUT "side1UniqueMap\t".commify($log{ ML_side1_U })."\t".round((($log{ ML_side1_U }/$side1_totalReads)*100),2)."\n";
print OUT "side2TotalReads\t".commify($side2_totalReads)."\n";
print OUT "side2NoMap\t".commify($log{ ML_side2_NM })."\t".round((($log{ ML_side2_NM }/$side2_totalReads)*100),2)."\n";
print OUT "side2MultiMap\t".commify($log{ ML_side2_MM })."\t".round((($log{ ML_side2_MM }/$side2_totalReads)*100),2)."\n";
print OUT "side2UniqueMap\t".commify($log{ ML_side2_U })."\t".round((($log{ ML_side2_U }/$side2_totalReads)*100),2)."\n";

die("side1/side2/nReads not equal!") if(($side1_totalReads != $side2_totalReads) and ($side1_totalReads != $log{ nReads }));
my $totalReads=$side1_totalReads=$side2_totalReads;
my $bothSideMapped=$log{ inward }+$log{ outward }+$log{ topStrand }+$log{ bottomStrand };
my $sameFragment=$log{ selfCircle}+$log{ danglingEnd }+$log{ error };

print OUT "\nHi-C Library Quality Metrics\n";
print OUT "totalReads\t".commify($totalReads)."\n";
print OUT "unMapped\t".commify($log{ unMapped })."\t".round((($log{ unMapped }/$totalReads)*100),2)."\n";
print OUT "singleSided\t".commify($log{ singleSide })."\t".round((($log{ singleSide }/$totalReads)*100),2)."\n";
print OUT "bothSideMapped\t".commify($bothSideMapped)."\t".round((($bothSideMapped/$totalReads)*100),2)."\n";
print OUT "sameFragment\t".commify($sameFragment)."\t".round((($sameFragment/$bothSideMapped)*100),2)."\n";
print OUT "selfCircle\t".commify($log{ selfCircle })."\t".round((($log{ selfCircle }/$bothSideMapped)*100),2)."\n";
print OUT "danglingEnd\t".commify($log{ danglingEnd })."\t".round((($log{ danglingEnd }/$bothSideMapped)*100),2)."\n";
print OUT "bounded\t".commify($log{ bounded })."\t".round((($log{ bounded }/$log{ danglingEnd })*100),2)."\n";
print OUT "internal\t".commify($log{ internal })."\t".round((($log{ internal }/$log{ danglingEnd })*100),2)."\n";
print OUT "error\t".commify($log{ error })."\t".round((($log{ error }/$bothSideMapped)*100),2)."\n";
print OUT "validPair\t".commify($log{ validPair })."\t".round((($log{ validPair }/$bothSideMapped)*100),2)."\n";
print OUT "cis\t".commify($log{ cis__validPair })."\t".round((($log{ cis__validPair }/$log{ validPair })*100),2)."\n";
print OUT "trans\t".commify($log{ trans__validPair })."\t".round((($log{ trans__validPair }/$log{ validPair})*100),2)."\n";

if($log{ snpModeFlag } == 1) {
	print OUT "\nAllele Override Statistics\n";
	foreach my $field (sort keys %alleleChoices) {
		next if($field =~ /^chrPair__/);
		
		my $count=$log{$field};
		
		print OUT "$field\t".commify($count)."\t".round((($count/$bothSideMapped)*100),2)."\n";
	}
	my $totalAlleleOverride=($log{ side1_allele}+$log{ side2_allele});
	print OUT "totalAlleleOverride\t".commify($totalAlleleOverride)."\t".round((($totalAlleleOverride/$bothSideMapped)*100),2)."\n";
}

print OUT "\nHi-C Library Redundancy Metrics\n";

print OUT "validPair\t".commify($log{ validPair })."\t".round((($log{ validPair }/$log{ validPair })*100),2)."\n";
print OUT "totalMolecules\t".commify($log{ moleculeTotal })."\t".round((($log{ moleculeTotal }/$log{ validPair })*100),2)."\n";
print OUT "redundantInteractions\t".commify($log{ totalRedundantMolecules })."\t".round((($log{ totalRedundantMolecules }/$log{ validPair})*100),2)."\n";
print OUT "nonRedundantInteractions\t".commify($log{ interactionTotal })."\t".round((($log{ interactionTotal }/$log{ validPair })*100),2)."\n";
print OUT "percentRedundant\t".round((($log{ totalRedundantMolecules }/$log{ moleculeTotal })*100),2)."%\n";

close(OUT);
