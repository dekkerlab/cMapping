use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use bytes;

sub check_options {
    my $opts = shift;
    my ($inputFile,$groupSize,$splitSize,$outputDir);
	$inputFile=$groupSize=$splitSize=$outputDir="";
 
	if( defined($opts->{'inputFile'}) ) {
		$inputFile = $opts->{'inputFile'};
    } else {
		print "Option inputFile|i is required.\n";
		exit;
    }
	
	if( defined($opts->{'groupSize'}) ) {
		$groupSize = $opts->{'groupSize'};
		if($groupSize < 1) { 
			print "Invalid Group Size - please specify number >= 1\n";
			exit;
		}
    } else {
		$groupSize=1;
    }
	
	if( defined($opts->{'splitSize'}) ) {
		$splitSize = $opts->{'splitSize'};
    } else {
		$splitSize=500000;
    }
	
	if( defined($opts->{'outputDir'}) ) {
		$outputDir = $opts->{'outputDir'};
		$outputDir =~ s/\/$//;
    } else {
		print "Option outputDir|o is required.\n";
		exit;
    }
	
	return($inputFile,$groupSize,$splitSize,$outputDir);
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
my $results = GetOptions( \%options,'inputFile|i=s','groupSize|g=s','splitSize|s=s','outputDir|o=s');

################# GLOBALS ##################################
my ($inputFile,,$groupSize,$splitSize,$outputDir);
($inputFile,$groupSize,$splitSize,$outputDir)=check_options( \%options );


my $line = "";
my $totalBytes=0;
my $splitInc=0;
my @tmp=split(/\//,$inputFile);
my $outputFileName=$tmp[@tmp-1];
$outputFileName =~ s/\.gz$//; # remove .gz extension

my $lineNum=0;
my $splitLines=0;

my $outputFile=$outputDir."/".$outputFileName.".c".$splitInc.".gz";
open(OUT,outputWrapper($outputFile));

open (IN,inputWrapper($inputFile)) or die $!;
while($line = <IN>) {
	
	next if($line eq "");
	next if($line =~ /^# /);
	
	if( ($groupSize == 4) and ((($lineNum % $groupSize) == 0) or (($lineNum % $groupSize) == 2)) ) {
		
		if(($line !~ /^\@/) and ($line !~ /^\+/)) {
			print "$lineNum - $splitLines - $splitInc - $line\n";
			print "error - file is out of sync...exiting\n";
			exit;
		}
		
		$line =~ s/#0\/1/#/;
		$line =~ s/#0\/2/#/;
		
	}
	
	if( ($splitLines >= $splitSize) and (($lineNum % $groupSize) == 0) ) { # if we are > $splitSize and the $groupSize condition is met
		$splitLines=0;
		$splitInc++;
		close(OUT);
		$outputFile=$outputDir."/".$outputFileName.".c".$splitInc.".gz";
		open(OUT,outputWrapper($outputFile));
	}
	
	$splitLines++;
	$lineNum++;
	print OUT $line;
		
}
close(IN);

close(OUT);
print ($splitInc);
