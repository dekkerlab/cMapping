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

my %nearbyStrandBias=();
my %header2index=();
my $totalReads=0;

opendir(DIR, $inputFolder) || die "Can't opedir $inputFolder: $!\n";
while (my $file = readdir DIR) {
	next if($file =~ /^\./); # skip . and .. 
	next if($file !~ /.strandBias.log$/); # only use *.strandBias.log files
	
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
	
		my $distance = $tmp[ $header2index{ distance } ];
		my $topStrandCount = $tmp[ $header2index{ topStrand } ];
		my $bottomStrandCount = $tmp[ $header2index{ bottomStrand } ];
		my $inwardCount = $tmp[ $header2index{ inward }];
		my $outwardCount = $tmp[ $header2index{ outward } ];
		
		$nearbyStrandBias{$distance}{ topStrand } += $topStrandCount;
		$nearbyStrandBias{$distance}{ bottomStrand } += $bottomStrandCount;
		$nearbyStrandBias{$distance}{ inward } += $inwardCount;
		$nearbyStrandBias{$distance}{ outward } += $outwardCount;
		$nearbyStrandBias{$distance}{ total } += ($topStrandCount+$bottomStrandCount+$inwardCount+$outwardCount);
		
		$totalReads += ($topStrandCount+$bottomStrandCount+$inwardCount+$outwardCount);
		
	}
	close(IN);
}
closedir(DIR);

# aggregrate the strand bias data
my $distanceCutoff=0;
my $cutoffFlag=0;

open(STRANDBIASLOG,">".$jobName.".strandBias.log");
print STRANDBIASLOG "plotFlag\tdistance\ttopStrand\tbottomStrand\tinward\toutward\tsameStrand\tinwardRatio\toutwardRatio\tdifference\ttotal\ttotalReads\ttopStranndCount\tbottomStrandCount\tinwardCount\toutwardCount\n";		
foreach my $distance ( sort { $a <=> $b } keys(%nearbyStrandBias) ) {
	
	my $plotFlag=1;
	
	my $topStrandCount=0;
	$topStrandCount=$nearbyStrandBias{$distance}{ topStrand } if(exists($nearbyStrandBias{$distance}{ topStrand }));
	my $bottomStrandCount=0;
	$bottomStrandCount=$nearbyStrandBias{$distance}{ bottomStrand } if(exists($nearbyStrandBias{$distance}{ bottomStrand }));
	my $inwardCount=0;
	$inwardCount=$nearbyStrandBias{$distance}{ inward } if(exists($nearbyStrandBias{$distance}{ inward }));
	my $outwardCount=0;
	$outwardCount=$nearbyStrandBias{$distance}{ outward } if(exists($nearbyStrandBias{$distance}{ outward }));	
	
	my $total=1;
	$total=$nearbyStrandBias{$distance}{ total } if(exists($nearbyStrandBias{$distance}{ total }));	
	$total=1 if($total == 0);
	
	# only plot if at least 1% of reads fall into distance bin
	$plotFlag = 0 if((($total/$totalReads)*100) <= 0.1);
	
	my $topStrandPercent = (($topStrandCount/$total)*100);
	my $bottomStrandPercent = (($bottomStrandCount/$total)*100);
	my $inwardPercent = (($inwardCount/$total)*100);
	my $outwardPercent = (($outwardCount/$total)*100);
	my $sameStrandPercent = (((($topStrandCount+$bottomStrandCount)/2)/$total)*100);
	
	next if(($inwardPercent == 0) or ($outwardPercent == 0) or ($sameStrandPercent == 0));	
	
	my $inwardRatio=log(($inwardPercent/$sameStrandPercent))/log(2);
	my $outwardRatio=log(($outwardPercent/$sameStrandPercent))/log(2);
	my $difference=(abs($inwardRatio-$outwardRatio));

	$distanceCutoff=$distance if(($difference >= 0.5) and ($cutoffFlag == 0));
	$cutoffFlag = 1 if($difference < 0.5);
	
	print STRANDBIASLOG "$plotFlag\t$distance\t$topStrandPercent\t$bottomStrandPercent\t$inwardPercent\t$outwardPercent\t$sameStrandPercent\t$inwardRatio\t$outwardRatio\t$difference\t$total\t$totalReads\t$topStrandCount\t$bottomStrandCount\t$inwardCount\t$outwardCount\n";
	
}
close(STRANDBIASLOG);

print "$distanceCutoff\n";