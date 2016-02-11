#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
    my $opts = shift;

    my ($jobName,$inputValidPairFile,$debugMode);
	
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
	
	if( exists($opts->{ debugMode }) ) {
		$debugMode = 1;
	} else {
		$debugMode = 0;
	}
	
	return($jobName,$inputValidPairFile,$debugMode);

}

my %options;
my $results = GetOptions( \%options,'jobName|jn=s','inputValidPairFile|i=s','debugMode|d');
my ($jobName,$inputValidPairFile,$debugMode)=check_options( \%options );

die("File does not exist! ($inputValidPairFile)\n") if(!(-e($inputValidPairFile)));

my $previousInteractionKey="";
my $previousMoleculeKey="";

my ($interactionCount,$moleculeCount,$interactionTotal,$moleculeTotal,$totalRedundantMolecules);
$interactionCount=$moleculeCount=$interactionTotal=$moleculeTotal=$totalRedundantMolecules=0;

open(OUT,">".$jobName.".validPair.itx");

my $lineNum=1;
open (IN,$inputValidPairFile) or die $!;
while(my $line = <IN>) {
	chomp($line);
	next if(($line =~ /^#/) or ($line eq ""));
	
	my @tmp=split(/\t/,$line);
	die("Error with input file! Must have 2 columns! (".@tmp.")\n") if(@tmp != 2);
	
	my $header_1=$tmp[0];
	my $header_2=$tmp[1];
	
	my $interactionKey=$header_1."\t".$header_2;
	
	print "$interactionKey\n" if(($debugMode == 1) and ($previousInteractionKey eq ""));
	$previousInteractionKey=$interactionKey if($previousInteractionKey eq "");
	
	if($interactionKey eq $previousInteractionKey) {
		$interactionCount++;
	} else {		
		print OUT "$previousInteractionKey\t$interactionCount\n";
		$interactionTotal += $interactionCount;
		
		print "$interactionKey\n" if($debugMode == 1);
		$interactionCount=1;
	}

	
	$previousInteractionKey=$interactionKey;
	
	$lineNum++;
	
	
}
close(IN);

print OUT "$previousInteractionKey\t$interactionCount\n";
$interactionTotal += $interactionCount;
		
close(OUT);

print "$interactionTotal";