#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
    my $opts = shift;

    my ($inputSamFile_side1,$inputSamFile_side2);
	
	if( exists($opts->{ inputSamFile_side1 }) ) {
		$inputSamFile_side1 = $opts->{ inputSamFile_side1 };
	} else {
		die("input inputSamFile_side1|i1 is required.\n");
	}
	
	if( exists($opts->{ inputSamFile_side2 }) ) {
		$inputSamFile_side2 = $opts->{ inputSamFile_side2 };
	} else {
		die("input inputSamFile_side2|i2 is required.\n");
	}

	return($inputSamFile_side1,$inputSamFile_side2);

}
	
my %options;
my $results = GetOptions( \%options,'inputSamFile_side1|i1=s','inputSamFile_side2|i2=s');
my ($inputSamFile_side1,$inputSamFile_side2)=check_options( \%options );

die("File does not exist! ($inputSamFile_side1)\n") if(!(-e($inputSamFile_side1)));
die("File does not exist! ($inputSamFile_side2)\n") if(!(-e($inputSamFile_side2)));

open(SIDE1,$inputSamFile_side1) or die "cannot open ($inputSamFile_side1) : $!";
open(SIDE2,$inputSamFile_side2) or die "cannot open ($inputSamFile_side2) : $!";
my $lineNum=1;
while((!eof(SIDE1)) || (!eof(SIDE2))) { 
	my $line1 = <SIDE1>;
	my $line2 = <SIDE2>;
	chomp ($line1);
	chomp ($line2);
	
	# split lines
	my @tmp1=split(/\t/,$line1);
	my @tmp2=split(/\t/,$line2);
	
	# XS signifies multip mapped read 0x4 signifies no matches
	my $flag_1="";
	$flag_1 = "MM" if(($line1 =~ /XS:/) or ($line1 =~ /ZS:Z:R/));
	$flag_1 = "NM" if(($tmp1[1]&0x4) or ($line1 =~ /ZS:Z:NM/));
	$flag_1 = "U" if($flag_1 eq "");
	
	my $flag_2="";
	$flag_2 = "MM" if(($line2 =~ /XS:/) or ($line2 =~ /ZS:Z:R/));
	$flag_2 = "NM" if(($tmp2[1]&0x4) or ($line2 =~ /ZS:Z:NM/));
	$flag_2 = "U" if($flag_2 eq "");
	
	$lineNum++;
	
	next if(($flag_1 ne "U") or ($flag_2 ne "U"));
	
	my %cigarHash1=();
	$cigarHash1{ M } = length($tmp1[9]);
	my $cigarString1=$tmp1[5];
	my @cigarValues1=split(/(\d+[MIDNSHP]{1})/,$cigarString1);
	for(my $i=0;$i<@cigarValues1;$i++) {
		my $cigarSubString1=$cigarValues1[$i];
		next if($cigarSubString1 eq ""); # do not know why it finds a blank everytime...
		my ($cigarScore1,$cigarField1)=split(/([MIDNSHP]{1})/,$cigarSubString1);
		$cigarHash1{$cigarField1}=$cigarScore1;
	}
	
	
	
	my %cigarHash2=();
	$cigarHash2{ M } = length($tmp2[9]);
	my $cigarString2=$tmp2[5];
	my @cigarValues2=split(/(\d+[MIDNSHP]{2})/,$cigarString2);
	for(my $i=0;$i<@cigarValues2;$i++) {
		my $cigarSubString2=$cigarValues2[$i];
		next if($cigarSubString2 eq ""); # do not know why it finds a blank everytime...
		my ($cigarScore2,$cigarField2)=split(/([MIDNSHP]{1})/,$cigarSubString2);
		$cigarHash2{$cigarField2}=$cigarScore2;
	}
	
	print "U\t$tmp1[1]\t",$tmp1[2],"\t",$tmp1[1]&0x10?(($tmp1[3]+($cigarHash1{ M }-1)),"\t\-"):($tmp1[3],"\t\+"),"\t",$tmp1[0],"\t";
	print "U\t$tmp2[1]\t",$tmp2[2],"\t",$tmp2[1]&0x10?(($tmp2[3]+($cigarHash2{ M }-1)),"\t\-"):($tmp2[3],"\t\+"),"\t",$tmp2[0],"\n";
	
	
}

close(SIDE1);
close(SIDE2);