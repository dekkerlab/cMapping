#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
    my $opts = shift;

    my ($jobName,$inputFolder);
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		die("input jobName|jn is required.\n");
	}
	
	if( exists($opts->{ inputFolder }) ) {
		$inputFolder = $opts->{ inputFolder };
	} else {
		die("input inputFolder|i is required.\n");
	}

	return($jobName,$inputFolder);
}
		
my %options;
my $results = GetOptions( \%options,'jobName|jn=s','inputFolder|i=s');
my ($jobName,$inputFolder)=check_options( \%options );

$inputFolder = $inputFolder."/" if($inputFolder !~ /\/$/); # tack on trailing / if not there	
die("invalid input dir! ($inputFolder)\n") if(!(-d($inputFolder)));

my %mappingLog=();

opendir(DIR, $inputFolder) || die "Can't opedir $inputFolder: $!\n";
while (my $file = readdir DIR) {
	next if($file =~ /^\./); # skip . and .. 
	next if($file !~ /.mapping.log$/); # only use *.strandBias.log files
	
	my $filePath=$inputFolder.$file;
	
	die("inputFile does not exist! ($filePath)\n") if(!(-e($filePath)));
	
	my $lineNum=0;
	open(IN,$filePath) or die "cannot open ($filePath) : $!";
	while(my $line = <IN>) {
		chomp($line);
		
		next if($line =~ /^# /);
		next if($line eq "");
		
		my @tmp=split(/\t/,$line);
		
		die("ERROR: file must be tab seperated, 2 columns\n") if(@tmp != 2);
		
		$mappingLog{ $tmp[0] } += $tmp[1];
	}
	close(IN);
}
closedir(DIR);

open(LOG,">".$jobName.".mapping.log");
foreach my $field (sort keys %mappingLog) {
	my $value=$mappingLog{$field};
	print LOG "$field\t$value\n";
}
close(LOG);
