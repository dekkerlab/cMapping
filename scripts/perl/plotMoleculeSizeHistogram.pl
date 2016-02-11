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

my %moleculeSizes=();
my %header2index=();

opendir(DIR, $inputFolder) || die "Can't opedir $inputFolder: $!\n";
while (my $file = readdir DIR) {
	next if($file =~ /^\./); # skip . and .. 
	next if($file !~ /.moleculeSize.log$/); # only use *.moleculeSize.log files
	
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
	
		next if(@tmp != 2);
	
		my $moleculeSize = $tmp[ $header2index{ moleculeSize } ];
		my $count = $tmp[ $header2index{ count } ];
		
		$moleculeSizes{$moleculeSize} += $count;
	}
	close(IN);
}
closedir(DIR);

my $moleculeSizeFile=$jobName.".moleculeSize.log";
my $moleculeSizePlotFile=$jobName.".moleculeSize.plot.log";


open(OUT,">".$moleculeSizeFile);
open(PLOT,">".$moleculeSizePlotFile);

print OUT "moleculeSize\tcount\n";
print PLOT "moleculeSize\n";
# log the dangling end molecule sizes
foreach my $moleculeSize ( sort { $a <=> $b } keys(%moleculeSizes) ) {
	my $count=$moleculeSizes{$moleculeSize};
	print OUT "$moleculeSize\t$count\n";
	for(my $i=0;$i<$count;$i++) {
		print PLOT "$moleculeSize\n";
	}
}
close(OUT);
close(PLOT);