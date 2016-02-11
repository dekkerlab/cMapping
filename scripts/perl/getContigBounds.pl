#!/usr/bin/perl -w
use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

sub check_options {
    my $opts = shift;

    my ($inputFragmentFile);
	
	if( exists($opts->{ inputFragmentFile }) ) {
		$inputFragmentFile = $opts->{ inputFragmentFile };
	} else {
		print "\nERROR: Option inputFragmentFile|i is required.\n";
		help();
	}
    
	return($inputFragmentFile);
}

sub intro() {
	print "\n";
	
	print "Tool:\t\tgetContigBound.pl\n";
	print "Version:\t1.0.0\n";
	print "Summary:\tget contig start/end from a restriction fragment file\n";
	
	print "\n";
}

sub help() {
	intro();
	
	print "Usage: perl getContigBound.pl [OPTIONS] -i <inputFragmentFile>\n";
	
	print "\n";
		
	print "Required:\n";
	printf("\n\t%-10s %-10s %-10s\n", "-i", "[]", "input fragment file");
	
	print "\n";
	
	print "Options:\n";
	
	print "\n";
	
	print "Notes:";
	print "
	This program outputs the start/end of each contig in a restriction fragment file\n";
	
	print "\n";
	
	print "Contact:
	Dekker Lab
	http://my5C.umassmed.edu
	my5C.help\@umassmed.edu\n";
	
	print "\n";
	
	exit;
}

my %options;
my $results = GetOptions( \%options,'inputFragmentFile|i=s');

#user Inputs
my ($inputFragmentFile)=check_options( \%options );

intro();

print "\n";
print "inputFragmentFile (-i)\t$inputFragmentFile\n";
print "\n";


die("inputFragmentFile ($inputFragmentFile) does not exist!") if(!(-e $inputFragmentFile));

my $genomeName=(split(/\//,$inputFragmentFile))[-1];
$genomeName=(split(/__/,$genomeName))[0];

my $contigBoundFile=$genomeName.".contigBounds.txt";

open(OUT,">".$contigBoundFile) || die("\nERROR: Could not open file ($contigBoundFile)\n\t$!\n\n");

my $lastContig="NA";
my $startContig=-1;
my $endContig=-1;

open(IN,$inputFragmentFile) || die("\nERROR: Could not open file ($inputFragmentFile)\n\t$!\n\n");
while(my $line = <IN>) {
	chomp($line);
	
	my @tmp=split(/\t/,$line);
	my $contig=$tmp[0];
	my $start=$tmp[1];
	my $end=$tmp[2];
	
	if($contig ne $lastContig) {
		print "$lastContig\t$startContig\t$endContig\n" if($lastContig ne "NA");
		print OUT "$lastContig\t$startContig\t$endContig\n" if($lastContig ne "NA");
		$startContig=$start;
	} else {
		$endContig=$end;
	}
	$lastContig=$contig;
}
print "$lastContig\t$startContig\t$endContig\n";
print OUT "$lastContig\t$startContig\t$endContig\n";

close(IN);

close(OUT);
