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

my %log=();

my %header2index=();

opendir(DIR, $inputFolder) || die "Can't opedir $inputFolder: $!\n";
while (my $file = readdir DIR) {
	next if($file =~ /^\./); # skip . and .. 
	next if($file !~ /.interaction.log$/); # only use *.strandBias.log files
	
	my $filePath=$inputFolder.$file;
	
	die("inputFile does not exist! ($filePath)\n") if(!(-e($filePath)));
	
	my $lineNum=0;
	open(IN,$filePath) or die "cannot open ($filePath) : $!";
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
		
		$log{$interactionCategory}{$interactionClassification}{$interactionType}{$interactionSubType}{$directionClassification} += $count;
				
	}
	close(IN);
}
closedir(DIR);

# log all interaction assignment data
open(LOG,">".$jobName.".interaction.log");
print LOG "interactionCategory\tinteractionClassification\tinteractionType\tinteractionSubType\tdirectionClassification\tcount\n";		
foreach my $interactionCategory (sort keys %log) {
	foreach my $interactionClassification (sort keys %{$log{$interactionCategory}}) {
		foreach my $interactionType (sort keys %{$log{$interactionCategory}{$interactionClassification}}) {
			foreach my $interactionSubType (sort keys %{$log{$interactionCategory}{$interactionClassification}{$interactionType}}) {
				foreach my $directionClassification (sort keys %{$log{$interactionCategory}{$interactionClassification}{$interactionType}{$interactionSubType}}) {
					my $count=$log{$interactionCategory}{$interactionClassification}{$interactionType}{$interactionSubType}{$directionClassification};
					print LOG "$interactionCategory\t$interactionClassification\t$interactionType\t$interactionSubType\t$directionClassification\t$count\n";
				}
			}
		}
	}
}
close(LOG);