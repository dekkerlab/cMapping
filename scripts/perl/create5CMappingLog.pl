#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
	my $opts = shift;

	my ($jobName,$mappingLogFile,$configFile);
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		die("input jobName|jn is required.\n");
	}
	
	if( exists($opts->{ mappingLogFile }) ) {
		$mappingLogFile = $opts->{ mappingLogFile };
	} else {
		die("input mappingLogFile|mlf is required.\n");
	}
	
	if( exists($opts->{ configFile }) ) {
		$configFile = $opts->{ configFile };
	} else {
		die("input configFile|cf is required.\n");
	}
	
	return($jobName,$mappingLogFile,$configFile);
}

sub round($;$) {
	my $num=shift;  #the number to work on
	my $digs_to_cut=shift || 0;  #the number of digits after 
	
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
my $results = GetOptions( \%options,'jobName|jn=s','mappingLogFile|mlf=s','configFile|cf=s');
my ($jobName,$mappingLogFile,$configFile)=check_options( \%options );

die("mappingLogFile does not exist! ($mappingLogFile)\n") if(!(-e($mappingLogFile)));
die("configFile does not exist! ($configFile)\n") if(!(-e($configFile)));

my %log=();

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

#get mapping log info
open(IN,$mappingLogFile);
while(my $line = <IN>) {
	chomp($line);
	next if($line =~ /^#/);
	
	my ($field,$value)=split(/\t/,$line);
	
	$log{$field}=$value;
}
close(IN);

my $time = getDate();

open(OUT,">".$jobName.".end.mappingLog.txt");

print OUT "General\n";
print OUT "time\t".$time."\n";	
print OUT "cType\t".$log{ cType }."\n";
print OUT "logDirectory\t".$log{ logDirectory }."\n";
print OUT "UUID\t".$log{ UUID }."\n";
print OUT "codeTree\t".$log{ codeTree }."\n";
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
print OUT "enzyme\t".$log{ enzyme }."\n";
print OUT "restrictionSite\t".$log{ restrictionSite }."\n";
print OUT "restrictionFragmentFile\t".$log{ restrictionFragmentPath }."\n";
print OUT "genome\t".$log{ genomeName }."\n";
print OUT "genomePath\t".$log{ genomePath }."\n";
print OUT "genomeSize\t".commify($log{ indexSizeMegabyte })."M\n";

print OUT "\nMapping Statistics\n";
my $numRawReads=$log{ numRawReads };
print OUT "numRawReads\t".commify($log{ numRawReads })."\n";
print OUT "side1Mapped\t".commify($log{ side1Mapped })."\t".round((($log{ side1Mapped }/$numRawReads)*100),2)."\n";
print OUT "side2Mapped\t".commify($log{ side2Mapped })."\t".round((($log{ side2Mapped }/$numRawReads)*100),2)."\n";
print OUT "noSideMapped\t".commify($log{ noSideMapped })."\t".round((($log{ noSideMapped }/$numRawReads)*100),2)."\n";
print OUT "oneSideMapped\t".commify($log{ oneSideMapped})."\t".round((($log{ oneSideMapped }/$numRawReads)*100),2)."\n";
print OUT "bothSideMapped\t".commify($log{ bothSideMapped })."\t".round((($log{ bothSideMapped }/$numRawReads)*100),2)."\n";
print OUT "errorPairs\t".commify($log{ errorPairs })."\t".round((($log{ errorPairs }/$numRawReads)*100),2)."\n";
print OUT "invalidPairs\t".commify($log{ invalidPairs })."\t".round((($log{ invalidPairs }/$numRawReads)*100),2)."\n";
print OUT "validPairs\t".commify($log{ validPairs })."\t".round((($log{ validPairs }/$numRawReads)*100),2)."\n";

print OUT "\nMapping Artifacts\n";
print OUT "fHomo\t".commify($log{ fHomo })."\t".round((($log{ fHomo }/$numRawReads)*100),2)."\n";
print OUT "rHomo\t".commify($log{ rHomo })."\t".round((($log{ rHomo }/$numRawReads)*100),2)."\n";

print OUT "\nAdvanced\n";
print OUT "same|->.->\t".commify($log{"same|->.->"})."\n";
print OUT "same|->.<-\t".commify($log{"same|->.<-"})."\n";
print OUT "same|<-.->\t".commify($log{"same|<-.->"})."\n";
print OUT "same|<-.<-\t".commify($log{"same|<-.<-"})."\n";
print OUT "different|->.->\t".commify($log{"different|->.->"})."\n";
print OUT "different|->.<-\t".commify($log{"different|->.<-"})."\n";
print OUT "different|<-.->\t".commify($log{"different|<-.->"})."\n";
print OUT "different|<-.<-\t".commify($log{"different|<-.<-"})."\n";

close(OUT);
