#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
    my $opts = shift;

    my ($inputSamFile_side1,$inputSamFile_side2,$jobName);
	
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
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		$jobName = "single";
	}

	return($inputSamFile_side1,$inputSamFile_side2,$jobName);

}

sub reOrient($$) {
	my $line1=shift;
	my $line2=shift;
	
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
	
	return($line1,$line2) if($flag_1 eq "U");
	return($line2,$line1) if($flag_2 eq "U");
	
	die("error");
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
my $results = GetOptions( \%options,'inputSamFile_side1|i1=s','inputSamFile_side2|i2=s','jobName|jn=s');
my ($inputSamFile_side1,$inputSamFile_side2,$jobName)=check_options( \%options );

die("File does not exist! ($inputSamFile_side1)\n") if(!(-e($inputSamFile_side1)));
die("File does not exist! ($inputSamFile_side2)\n") if(!(-e($inputSamFile_side2)));

open(NMMM,outputWrapper($jobName."__NMMM.fastq"));
open(U,outputWrapper($jobName."__U.sam"));

open(SIDE1,inputWrapper($inputSamFile_side1)) or die "cannot open ($inputSamFile_side1) : $!";
open(SIDE2,inputWrapper($inputSamFile_side2)) or die "cannot open ($inputSamFile_side2) : $!";
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
	
	next if($flag_1 eq $flag_2);
	next if(($flag_1 ne "U") and ($flag_2 ne "U"));
	
	($line1,$line2)=reOrient($line1,$line2) if($flag_2 eq "U");
	
	@tmp1=split(/\t/,$line1);
	@tmp2=split(/\t/,$line2);
	
	# XS signifies multip mapped read 0x4 signifies no matches
	$flag_1="";
	$flag_1 = "MM" if(($line1 =~ /XS:/) or ($line1 =~ /ZS:Z:R/));
	$flag_1 = "NM" if(($tmp1[1]&0x4) or ($line1 =~ /ZS:Z:NM/));
	$flag_1 = "U" if($flag_1 eq "");
	
	$flag_2="";
	$flag_2 = "MM" if(($line2 =~ /XS:/) or ($line2 =~ /ZS:Z:R/));
	$flag_2 = "NM" if(($tmp2[1]&0x4) or ($line2 =~ /ZS:Z:NM/));
	$flag_2 = "U" if($flag_2 eq "");
	
	my %cigarHash=();
	$cigarHash{ M } = length($tmp1[9]);
	my $cigarString=$tmp1[5];
	my @cigarValues=split(/(\d+[MIDNSHP]{1})/,$cigarString);
	for(my $i=0;$i<@cigarValues;$i++) {
		my $cigarSubString=$cigarValues[$i];
		next if($cigarSubString eq ""); # do not know why it finds a blank everytime...
		my ($cigarScore,$cigarField)=split(/([MIDNSHP]{1})/,$cigarSubString);
		$cigarHash{$cigarField}=$cigarScore;
	}
	
	my $readID_2=$tmp2[0];
	my $seq_2=$tmp2[9];
	my $qv_2=$tmp2[10];
	
	print NMMM "@"."$readID_2\n$seq_2\n+\n$qv_2\n";
	print U "$line1\n";
	
	
}

close(SIDE1);
close(SIDE2);

close(NMMM);
close(U);
