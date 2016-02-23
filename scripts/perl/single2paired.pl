#!/usr/bin/perl -w
use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);
use List::Util qw[min max];
use Cwd 'abs_path';
use Cwd;

sub check_options {
    my $opts = shift;

    my ($inputFastQFile,$totalReadLength);
	
	if( exists($opts->{ inputFastQFile }) ) {
		$inputFastQFile = $opts->{ inputFastQFile };
	} else {
		die("Option inputFastQFile|i is required.\n");
	}
	
	if( exists($opts->{ totalReadLength }) ) {
		$totalReadLength = $opts->{ totalReadLength };
	} else {
		die("Option totalReadLength|trl is required.\n");
	}
	
	return($inputFastQFile,$totalReadLength);
}

sub getFileName($) {
	my $fileName=shift;
	
	my $shortName=(split(/\//,$fileName))[-1];
	$shortName =~ s/\.gz$//;
	
	return($shortName);
}	

sub getShortFileName($) {
	my $fileName=shift;
	
	$fileName=(split(/\//,$fileName))[-1];
    my $shortName=(split(/__/,$fileName))[0];
    $shortName=(split(/\./,$shortName))[0];
	
	return($shortName);
}	

sub getFilePath($) {
	my $filePath=shift;
	
	my $shortName=(split(/\//,$filePath))[-1];
	$filePath =~ s/$shortName//;	
	
	return($filePath);
}	

sub baseName($) {
	my $fileName=shift;
	
	my $shortName=(split(/\//,$fileName))[-1];
	
	return($shortName);
}	

my %options;
my $results = GetOptions( \%options,'inputFastQFile|i=s','totalReadLength|trl=s');

my ($inputFastQFile,$totalReadLength)=check_options( \%options );

print "\n";
print "--- inputs ---\n";
print "inputFastQFile (-i)\t$inputFastQFile\n";
print "totalReadLength (-trl)\t$totalReadLength\n";
print "--- inputs ---\n";
print "\n";

die("\ninputFastQFile ($inputFastQFile) does not exist!\n\n") if(!(-e $inputFastQFile));

my $inputFastQFileName=getFileName($inputFastQFile);
my $inputFastQFilePath=getFilePath($inputFastQFile);

my $side1FastQFile=$inputFastQFile."__s1";
my $side2FastQFile=$inputFastQFile."__s2";

my @tmpArr=split(/_/,(split(/\./,$inputFastQFileName))[0]);
if(@tmpArr == 5) {
	my $name=$tmpArr[0];
	my $index=$tmpArr[1];
	my $laneNum=$tmpArr[2];
	my $sideNum=$tmpArr[3];
	my $tileNum=$tmpArr[4];
	
	$side1FastQFile=$name."_".$index."_".$laneNum."_R1_".$tileNum.".fastq";
	$side2FastQFile=$name."_".$index."_".$laneNum."_R2_".$tileNum.".fastq";
}

$side1FastQFile=$side1FastQFile.".gz";
$side2FastQFile=$side2FastQFile.".gz";

print "writing PE files...\n";
print "\t$side1FastQFile\n";
print "\t$side2FastQFile\n";

$side1FastQFile = ">".$side1FastQFile if($side1FastQFile !~ /\.gz$/);
$side1FastQFile = "| gzip -c > '".$side1FastQFile."'" if($side1FastQFile =~ /\.gz$/);
open(OUT1,$side1FastQFile);

$side2FastQFile = ">".$side2FastQFile if($side2FastQFile !~ /\.gz$/);
$side2FastQFile = "| gzip -c > '".$side2FastQFile."'" if($side2FastQFile =~ /\.gz$/);
open(OUT2,$side2FastQFile);

my $lineNum=0;

my ($header1,$header2,$seq,$filterFlag,$qual);

$inputFastQFile = "gunzip -c '".$inputFastQFile."' | " if(($inputFastQFile =~ /\.gz$/) and (!(-T($inputFastQFile))));

open(IN,$inputFastQFile);
while(my $line = <IN>) {
	chomp($line);

	if(($lineNum % 4) == 0) {
		if($lineNum != 0) {

			my $seqLen=length($seq);
			my $name1_1=$header1."/1";
			my $name1_2=$header2;
			$name1_2.="/1" if($name1_2 ne "+");
			
			my $name2_1=$header1."/2";
			my $name2_2=$header2;
			$name2_2.="/2" if($name2_2 ne "+");
			
			print OUT1 "$name1_1\n".substr($seq,0,($totalReadLength/2))."\n$name1_2\n".substr($qual,0,($totalReadLength/2))."\n" if(($lineNum != 0) and ($filterFlag eq "N"));
			
			my $side2Sequence=substr($seq,($totalReadLength/2),($totalReadLength-($totalReadLength/2)));
			$side2Sequence=reverse($side2Sequence);
			$side2Sequence =~ tr/ACGTacgt/TGCAtgca/;
			my $side2Quality=substr($qual,($totalReadLength/2),($totalReadLength-($totalReadLength/2)));
			$side2Quality=reverse($side2Quality);
			
			print OUT2 "$name2_1\n".$side2Sequence."\n$name2_2\n".$side2Quality."\n" if(($lineNum != 0) and ($filterFlag eq "N"));
		}
		
		my @tmp=split(/ /,$line);
		$header1=$tmp[0];
		$filterFlag=(split(/\:/,$tmp[1]))[1];
		
	} elsif(($lineNum % 4) == 1) {
		$seq=$line;
	} elsif(($lineNum % 4) == 2) {
		$header2=$line;
	} elsif(($lineNum % 4) == 3) {
		$qual=$line;
	}
	$lineNum++;
}

my $seqLen=length($seq);
my $name1_1=$header1."/1";
my $name1_2=$header2;
$name1_2.="/1" if($name1_2 ne "+");

my $name2_1=$header1."/2";
my $name2_2=$header2;
$name2_2.="/2" if($name2_2 ne "+");

print OUT1 "$name1_1\n".substr($seq,0,($totalReadLength/2))."\n$name1_2\n".substr($qual,0,($totalReadLength/2))."\n" if(($lineNum != 0) and ($filterFlag eq "N"));

my $side2Sequence=substr($seq,($totalReadLength/2),($totalReadLength-($totalReadLength/2)));
$side2Sequence=reverse($side2Sequence);
$side2Sequence =~ tr/ACGTacgt/TGCAtgca/;
my $side2Quality=substr($qual,($totalReadLength/2),($totalReadLength-($totalReadLength/2)));
$side2Quality=reverse($side2Quality);

print OUT2 "$name2_1\n".$side2Sequence."\n$name2_2\n".$side2Quality."\n" if(($lineNum != 0) and ($filterFlag eq "N"));