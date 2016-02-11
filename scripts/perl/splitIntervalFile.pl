#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
    my $opts = shift;

    my ($jobName,$inputIntervalFile,$splitMode);
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		die("input jobName|jn is required.\n");
	}
	
	if( exists($opts->{ inputIntervalFile }) ) {
		$inputIntervalFile = $opts->{ inputIntervalFile };
	} else {
		die("input inputIntervalFile|i is required.\n");
	}
	
	if( exists($opts->{ splitMode }) ) {
		$splitMode = $opts->{ splitMode };
	} else {
		$splitMode = "chr";
	}
	
	return($jobName,$inputIntervalFile,$splitMode);

}

sub getPrimerNameInfo($) {
	my $primerName=shift;
	
	my @tmp=();
	my $tmpSize=0;
	
	my ($subName,$assembly,$coords);
	$subName=$assembly=$coords="NA";	
	@tmp=split(/\|/,$primerName);
	$tmpSize=scalar @tmp;
	($subName,$assembly,$coords)=split(/\|/,$primerName) if($tmpSize == 3);	
	#badFormat($primerName,$primerName,'primerName is not in proper format...') if($tmpSize != 3);
	
	my ($chromosome,$pos);
	$chromosome=$pos="NA";	
	@tmp=split(/:/,$coords);
	$tmpSize=scalar @tmp;
	($chromosome,$pos)=split(/:/,$coords) if($tmpSize == 2);
	#badFormat($coords,$coords,'coordinates are not in proper format...') if($tmpSize != 2);
	
	my ($region);
	$region=$chromosome;
	@tmp=split(/_/,$subName);
	$tmpSize=scalar @tmp;
	$region=$tmp[1] if(($tmpSize == 5) and ($tmp[0] eq "5C"));
	
	my ($start,$end);
	$start=$end=0;
	@tmp=split(/-/,$pos);
	$tmpSize=scalar @tmp;
	($start,$end)=split(/-/,$pos) if($tmpSize == 2);
	#badFormat($pos,$pos,'position is not in proper format...') if($tmpSize != 2);
	
	my $size=(($end-$start)+1); # add to for 1-based positioning
	my $midpoint=(($end+$start)/2);
		
	my %primerObject=();
	$primerObject{ subName }=$subName;
	$primerObject{ assembly }=$assembly;
	$primerObject{ chromosome }=$chromosome;
	$primerObject{ region }=$region;
	$primerObject{ start }=$start;
	$primerObject{ end }=$end;
	$primerObject{ midpoint }=$midpoint;
	$primerObject{ size }=$size;
	
	return(\%primerObject);
	
}

sub header2group($$) {
	my $header=shift;
	my $extractBy=shift;
	
	my $headerObject=getPrimerNameInfo($header);
	
	my $chromosome=$headerObject->{ chromosome };
	my $subName=$headerObject->{ subName };
		
	my @tmp=split(/-/,$chromosome);
	my $group="amb";
	$group=$tmp[1] if(@tmp == 2);
	
	my $liteChromosome=$chromosome;
	$liteChromosome =~ s/-$group//;
	
	my $subMatrix="NA";
	$subMatrix=$subName if($extractBy eq "name");
	$subMatrix=$chromosome if($extractBy eq "chr");
	$subMatrix=$liteChromosome if($extractBy eq "liteChr");
	$subMatrix=$group if($extractBy eq "group");
	
	return($subMatrix);
}

my %options;
my $results = GetOptions( \%options,'jobName|jn=s','inputIntervalFile|i=s','splitMode|sm=s');
my ($jobName,$inputIntervalFile,$splitMode)=check_options( \%options );

die("File does not exist! ($inputIntervalFile)\n") if(!(-e($inputIntervalFile)));

my $previousGroup="NA";
my $groupString="";
my ($OUT);

my $lineNum=1;
open (IN,$inputIntervalFile) or die $!;
while(my $line = <IN>) {
	chomp($line);
	next if(($line =~ /^#/) or ($line eq ""));
	
	my @tmp=split(/\t/,$line);
	my $chromosome=$tmp[0];
	my $header=$tmp[3];
	
	my $group=header2group($header,$splitMode);
	
	if($previousGroup ne $group) {
		close($OUT) if($lineNum != 1);
		open($OUT,">".$jobName."__".$group.".txt");
		
		$groupString .= ",".$group if($groupString ne "");
		$groupString = $group if($groupString eq "");
		
	}
	
	$previousGroup=$group;
	print $OUT "$line\n";
	
}
close(IN);

close($OUT);

print "$groupString";