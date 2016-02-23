
#! /usr/bin/perl
use warnings;
use strict;
use IO::Handle;
use POSIX qw(ceil floor);
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

## Checks the options to the program
sub check_options {
    my $opts = shift;

	my ($configFile);
	
	if( $opts->{'configFile'} ) {
		$configFile = $opts->{'configFile'};
	} else {
		die("Option configFile|lf is required.");
	}

    
	return($configFile);
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
my $results = GetOptions( \%options,'configFile|cf=s');
my ($configFile)=check_options( \%options );

die("configFile does not exist! ($configFile)\n") if(!(-e($configFile)));

my %log=();

# get config log info
open(IN,$configFile);
while(my $line = <IN>) {
	chomp($line);
	next if($line =~ /^#/);
	
	my ($field,$value)=split(/=/,$line);
	$value =~ s/"//g;

	$log{$field}=$value;
}
close(IN);

my $time=getDate();

my $logFile=$log{ logFile };

open(OUT,">",$logFile);

print OUT "# combineHiC\n";
print OUT "# time\t".$time."\n";
print OUT "# logDirectory\t".$log{ logDirectory }."\n";
print OUT "# UUID\t".$log{ UUID }."\n";
print OUT "# cMapping\t".$log{ cMapping }."\n";
print OUT "# computeResource\t".$log{ computeResource }."\n";
print OUT "# combineQueue\t".$log{ combineQueue }."\n";
print OUT "# combineTimeNeeded\t".$log{ combineTimeNeeded }."\n";
print OUT "# combineMemoryNeeded\t".$log{ combineMemoryNeeded }."\n";
print OUT "# jobName\t".$log{ jobName }."\n";
print OUT "# fastaDir\t".$log{ fastaDir }."\n";
print OUT "# fastaPath\t".$log{ fastaPath }."\n";
print OUT "# enzyme\t".$log{ enzyme }."\n";
print OUT "# restrictionFragmentPath\t".$log{ restrictionFragmentPath }."\n";
print OUT "# binSizes\t".$log{ binSizes }."\n";
print OUT "# binLabels\t".$log{ binLabels }."\n";
print OUT "# binModes\t".$log{ binModes }."\n";
print OUT "# outputFolder\t".$log{ outputFolder }."\n";
print OUT "# debugMode\ton\n" if($log{ debugModeFlag } == 1);
print OUT "# \n";

my $inputFileString=$log{ inputFileString };
my @tmp=split(/\,/,$inputFileString);
my $numLanes=@tmp;
print OUT "# numLanes\t$numLanes\n";
for(my $i=0;$i<$numLanes;$i++) {
	print OUT "# lane #".$i."\t".$tmp[$i]."\n";
}

close(OUT);


