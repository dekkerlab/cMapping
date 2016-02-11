#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
    my $opts = shift;

    my ($jobName,$inputValidPairFile,$sameStrandFlag,$debugMode);
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		die("input jobName|jn is required.\n");
	}
	
	if( exists($opts->{ inputValidPairFile }) ) {
		$inputValidPairFile = $opts->{ inputValidPairFile };
	} else {
		die("input inputValidPairFile|i is required.\n");
	}
	
	if( exists($opts->{ sameStrandFlag }) ) {
		$sameStrandFlag = 1;
	} else {
		$sameStrandFlag = 0;
	}
	
	if( exists($opts->{ debugMode }) ) {
		$debugMode = 1;
	} else {
		$debugMode = 0;
	}
	
	return($jobName,$inputValidPairFile,$sameStrandFlag,$debugMode);

}

sub outputWrapper($;$) {
	# required
	my $outputFile=shift;
	# optional
	my $outputCompressed=0;
	$outputCompressed=shift if @_;
	
	$outputCompressed = 1 if($outputFile =~ /\.gz$/);
	$outputFile .= ".gz" if(($outputFile !~ /\.gz$/) and ($outputCompressed == 1));
	$outputFile = "| gzip -c > '".$outputFile."'" if(($outputFile =~ /\.gz$/) and ($outputCompressed == 1));
	$outputFile = ">".$outputFile if($outputCompressed == 0);
	
	return($outputFile);
}

sub inputWrapper($) {
	my $inputFile=shift;
	
	$inputFile = "gunzip -c '".$inputFile."' | " if(($inputFile =~ /\.gz$/) and (!(-T($inputFile))));
	
	return($inputFile);
}

my %options;
my $results = GetOptions( \%options,'jobName|jn=s','inputValidPairFile|i=s','sameStrandFlag|ss','debugMode|d');
my ($jobName,$inputValidPairFile,$sameStrandFlag,$debugMode)=check_options( \%options );

die("File does not exist! ($inputValidPairFile)\n") if(!(-e($inputValidPairFile)));

my $previousInteractionKey="";
my $previousMoleculeKey="";

my ($interactionCount,$moleculeCount,$validPairCount,$interactionTotal,$moleculeTotal,$totalRedundantMolecules);
$interactionCount=$moleculeCount=$validPairCount=$interactionTotal=$moleculeTotal=$totalRedundantMolecules=0;

open(OUT,outputWrapper($jobName.".validPair.itx.gz"));

my $lineNum=1;
open (IN,inputWrapper($inputValidPairFile)) or die $!;
while(my $line = <IN>) {
	chomp($line);
	next if(($line =~ /^#/) or ($line eq ""));
	
	my @tmp=split(/\t/,$line);
	die("Error with input file! Must have 12 columns! (".@tmp.")\n") if(@tmp != 12);
	
	my $chromosome_1=$tmp[1];
	my $readPos_1=$tmp[2];
	my $strand_1=$tmp[3];
	my $readID_1=$tmp[4];
	my $fragmentIndex_1=$tmp[5];
	
	my $chromosome_2=$tmp[7];
	my $readPos_2=$tmp[8];
	my $strand_2=$tmp[9];
	my $readID_2=$tmp[10];
	my $fragmentIndex_2=$tmp[11];
	
	$validPairCount++;
	
	# keep only same strand pairs if SS mode enabled
	next if(($sameStrandFlag == 1) and ($strand_1 ne $strand_2));
	
	die("$lineNum : frag1>frag2\n\t$fragmentIndex_1 > $fragmentIndex_2\n\n$line\n") if($fragmentIndex_1 > $fragmentIndex_2);
	
	my $interactionKey=$fragmentIndex_1."\t".$fragmentIndex_2;
	my $moleculeKey=$fragmentIndex_1."@".$readPos_1."\t".$fragmentIndex_2."@".$readPos_2;
	
	print "$interactionKey\n" if(($debugMode == 1) and ($previousInteractionKey eq ""));
	$previousInteractionKey=$interactionKey if($previousInteractionKey eq "");
	
	if($interactionKey eq $previousInteractionKey) {
		if($moleculeKey ne $previousMoleculeKey) {
			
			print "\t$previousMoleculeKey\t$moleculeCount\n" if(($debugMode == 1) and ($previousMoleculeKey ne ""));
			$interactionCount++;
		}
		$moleculeCount++;
	} else {		
		print OUT "$previousInteractionKey\t$interactionCount\n";
		$interactionTotal += $interactionCount;
		$moleculeTotal += $moleculeCount;
	
		print "\t$previousMoleculeKey\t$moleculeCount\n"  if($debugMode == 1);
		my $numRedundantMolecules=($moleculeCount-$interactionCount);
		print "\t\t$interactionCount\t$moleculeCount\t($numRedundantMolecules)\n\n" if($debugMode == 1);
		
		print "$interactionKey\n" if($debugMode == 1);
		$interactionCount=1;
		$moleculeCount=1;
		
		$totalRedundantMolecules += $numRedundantMolecules;
	}
	
	$previousInteractionKey=$interactionKey;
	$previousMoleculeKey=$moleculeKey;
	
	$lineNum++;
	
	
}
close(IN);

print OUT "$previousInteractionKey\t$interactionCount\n";
$interactionTotal += $interactionCount;
$moleculeTotal += $moleculeCount;
my $numRedundantMolecules=($moleculeCount-$interactionCount);
$totalRedundantMolecules += $numRedundantMolecules;
		
print "\t$previousMoleculeKey\n" if($debugMode == 1);
print "\t\t$interactionCount\t$moleculeCount\n" if($debugMode == 1);

close(OUT);

print "validPairCount\t$validPairCount\n" if($debugMode == 1);
print "moleculeTotal\t$moleculeTotal\n" if($debugMode == 1);
print "interactionTotal\t$interactionTotal\n" if($debugMode == 1);
print "totalRedundantMolecules\t$totalRedundantMolecules\n" if($debugMode == 1);

# log the number of molecules/interactions
open(PCRDUPE,">".$jobName.".pcrDupe.log");
print PCRDUPE "validPairCount\t$validPairCount\n";
print PCRDUPE "moleculeTotal\t$moleculeTotal\n";
print PCRDUPE "interactionTotal\t$interactionTotal\n";
print PCRDUPE "totalRedundantMolecules\t$totalRedundantMolecules\n";
close(PCRDUPE);

print "$interactionTotal";