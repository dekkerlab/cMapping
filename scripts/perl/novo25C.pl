#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {

	my $opts = shift;
	my ($jobName,$input_side1,$input_side2,$configFile);
	$jobName=$input_side1=$input_side2=$configFile="";
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		die("input jobName|jn is required.\n");
	}
	
	if( exists($opts->{ input_side1 }) ) {
		$input_side1 = $opts->{ input_side1 };
	} else {
		print "Option input_side1|s1 is required.\n";
		exit;
	}
	if( exists($opts->{ input_side2 }) ) {
		$input_side2 = $opts->{ input_side2 };
	} else {
		print "Option input_side2|s2 is required.\n";
		exit;
	}
	
	if( exists($opts->{ configFile }) ) {
		$configFile = $opts->{ configFile };
	} else {
		die("input configFile|cf is required.\n");
	}
	
	return($jobName,$input_side1,$input_side2,$configFile);
}

sub jobError($$) {
	my $errorString=shift;
	my $jobName=shift;
	
	system("echo -e '".$errorString."' > ".$jobName.".error");
	die("\n".$jobName."\n".$errorString."\n");
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

sub annotate($$$$$$) {
	my $strand1=shift;
	my $strand2=shift;
	my $match1=shift;
	my $match2=shift;
	my $offset1=shift;
	my $offset2=shift;
	
	my ($direction1,$direction2,$direction,$interaction,$interactionOffset,$distance);
	$direction1=$direction2=$direction=$interaction=$interactionOffset=$distance="";
	
	if($strand1 eq "F") {
		$direction1="->";
	} elsif($strand1 eq "R") {
		$direction1="<-";
	}
	
	if($strand2 eq "F") {
		$direction2="->";
	} elsif($strand2 eq "R") {
		$direction2="<-";
	}	
	
	my ($type1,$type2,$contig1,$contig2);
	$type1=$type2=$contig1=$contig2="";
	$type1 = 'F' if($match1 =~ m/_[L]?FOR_/g);
	$type1 = 'R' if($match1 =~ m/_[L]?REV_/g);
	$type2 = 'F' if($match2 =~ m/_[L]?FOR_/g);
	$type2 = 'R' if($match2 =~ m/_[L]?REV_/g);
	
	die("error assigning primer type! ($match1 | $type1) ($match2 | $type2)\n") if(($type1 eq "") or ($type2 eq ""));
	
	if(($type1 eq "F") and ($type2 eq "R")) {
		$direction=$direction1.".".$direction2;
		$interaction=$match1."\t".$match2;
		$interactionOffset=$match1."|".$offset1."\t".$match2."|".$offset2;
	} elsif(($type1 eq "R") and ($type2 eq "F")) {
		$direction=$direction2.".".$direction1;
		$interaction=$match2."\t".$match1;
		$interactionOffset=$match2."|".$offset2."\t".$match1."|".$offset1;
	} else {
		$direction=$direction1.".".$direction2;
		$interaction=$match1."\t".$match2;
		$interactionOffset=$match1."|".$offset1."\t".$match1."|".$offset2;
	}
	return($interaction,$interactionOffset,$direction);
}

my %options;
my $results = GetOptions( \%options,'jobName|jn=s','input_side1|s1=s','input_side2|s2=s','configFile|cf=s');
my ($jobName,$input_side1,$input_side2,$configFile);
($jobName,$input_side1,$input_side2,$configFile)=check_options( \%options );

die("configFile does not exist! ($configFile)\n") if(!(-e($configFile)));

my %log=();
open(IN,$configFile);
while(my $line = <IN>) {
	chomp($line);
	next if($line =~ /^#/);
	
	my ($field,$value)=split(/=/,$line);
	$value =~ s/"//g;
	$value="n/a" if($value eq "");
	$log{$field}=$value;
}
close(IN);

my $stats={};

$stats->{ nRawReads } = 0;
$stats->{ nRawReads } = 0;
$stats->{ noMap } = 0;
$stats->{ single } = 0;
$stats->{ bothSideMapped } = 0;
$stats->{ side1_match } = 0;
$stats->{ side2_match } = 0;
$stats->{ valid } = 0;
$stats->{ invalid } = 0;
$stats->{ fHomo } = 0;
$stats->{ rHomo } = 0;

$stats->{ same }{"->.->"} = 0;
$stats->{ same }{"->.<-"} = 0;
$stats->{ same }{"<-.<-"} = 0;
$stats->{ same }{"<-.->"} = 0;
$stats->{ different }{"->.->"} = 0;
$stats->{ different }{"->.<-"} = 0;
$stats->{ different }{"<-.->"} = 0;
$stats->{ different }{"<-.<-"} = 0;

#valid interaction
my $validPairFile=$jobName.".validPair.txt";
open(VALIDPAIR,">$validPairFile") || die "SC file error $!\n";

my $homoPairFile=$jobName.".homoPair.txt";
open(HOMOPAIR,">$homoPairFile") || die "SC file error $!\n";

###########################################
# opening the files and getting the data. 
###########################################

## ---- Get the input files ----
open (SIDE1, $input_side1) or die $!;
open (SIDE2, $input_side2) or die $!;

my $lineNum=0;
my $side1LineNum=0;
my $side2LineNum=0;
while((!eof(SIDE1)) || (!eof(SIDE2))){ 
	
# Reading both file line by line but only one line at a time.
	my $line1 = <SIDE1>;
	my $line2 = <SIDE2>;
	chomp ($line1);
	chomp ($line2);
	
	# keep reading file 1 while it is a comment line
	while(($line1 =~ /^# /) and (!eof(SIDE1))) {
		$line1 = <SIDE1>;
		chomp ($line1);
		$side1LineNum++;
	}
	# keep reading file 2 while it is a comment line
	while(($line2 =~ /^# /) and (!eof(SIDE2))) {
		$line2 = <SIDE2>;
		chomp ($line2);
		$side2LineNum++;
	}
	
	next if(($line1 =~ /^# /) and ($line2 =~ /^# /));
	
	# Get the keys and work the hash of those keys. 
	my @tmp1 = split(/\t/,$line1);
	my @tmp2 = split(/\t/,$line2);
	
	my $header1=(split(/ /,$tmp1[0]))[0];
	$header1 =~ s/\/1//;
	my $header2=(split(/ /,$tmp2[0]))[0];
	$header2 =~ s/\/2//;

	#check for side1/2 pairing via readID
	jobError("ERROR - (line # $lineNum) files are out of alignment! (".$header1." != ".$header2.")\n\t$input_side1\n\t\t$line1\n\t$input_side2\n\t\t$line2",$jobName) if($header1 ne $header2);
	
	# Define other parameters:
	my ($side1Align,$side2Align,$side1Length,$side2Length,$side1Strand,$side2Strand,$side1Offset,$side2Offset);
	$side1Align=$side2Align=$side1Length=$side2Length=$side1Strand=$side2Strand=$side1Offset=$side2Offset="";
	
	#7th column in novoOutput is the mapped position if exists
	$side1Length = length($tmp1[2]);
	$side2Length = length($tmp2[2]);
	
	if(exists($tmp1[7])) {	
		$side1Align = $tmp1[7];
		$side1Align =~ s/>//; 
		$side1Offset=$tmp1[8];
		$side1Strand = $tmp1[9];
	}
	if(exists($tmp2[7])) {
		$side2Align = $tmp2[7];
		$side2Align =~ s/>//;
		$side2Offset=$tmp2[8];
		$side2Strand = $tmp2[9];
	}
	
	my ($interaction,$interactionOffset,$direction);
	$interaction=$interactionOffset=$direction="";
	
	# Count number of mached and non matched reads.
	$stats->{ side1_match }++ if($side1Align ne "");
	$stats->{ side2_match }++ if($side2Align ne "");
	$stats->{ nRawReads }++;
	
	if(($side1Align ne "") and ($side2Align ne "")) {
		($interaction,$interactionOffset,$direction)=annotate($side1Strand,$side2Strand,$side1Align,$side2Align,$side1Offset,$side2Offset);
		my $type1="";
		my $type2="";
		$type1 = 'F' if($side1Align =~ m/_[L]?FOR_/g);
		$type1 = 'R' if($side1Align =~ m/_[L]?REV_/g);
		$type2 = 'F' if($side2Align =~ m/_[L]?FOR_/g);
		$type2 = 'R' if($side2Align =~ m/_[L]?REV_/g);
		
		die("error assigning primer type! ($side1Align | $type1) ($side2Align | $type2)\n") if(($type1 eq "") or ($type2 eq ""));
		
		if($side1Align eq $side2Align) {  
			$stats->{ same }{$direction}++;
			$stats->{ rHomo }++ if(($type1 eq "R") and ($type2 eq "R"));
			$stats->{ fHomo }++ if(($type1 eq "F") and ($type2 eq "F"));
			print HOMOPAIR "$interaction\n";
		} else {
			$stats->{ different }{$direction}++;
			if($type1 ne $type2) {
				if($direction eq "->.<-") {
					$stats->{ valid }++;
					print VALIDPAIR "$interaction\n";
				} else {
					$stats->{ error }++;
				}
			} else {
				$stats->{ rHomo }++ if(($type1 eq "R") and ($type2 eq "R"));
				$stats->{ fHomo }++ if(($type1 eq "F") and ($type2 eq "F"));
				print HOMOPAIR "$interaction\n";
			}
		}
		
		$stats->{ bothSideMapped }++;	

	} elsif(($side1Align ne "") and ($side2Align eq "")) {
		my $single=$side1Align;
		$stats->{ single }++;
	} elsif(($side1Align eq "") and ($side2Align ne "")) {
		my $single=$side2Align;
		$stats->{ single }++;
	} elsif(($side1Align eq "") and ($side2Align eq "")) {
		my $side1sequence=$tmp1[2];
		my $side2sequence=$tmp2[2];
		my $noMap=$side1sequence."\t".$side2sequence;
		$stats->{ noMap }++;
	}
	
	
	$lineNum++;
	$side1LineNum++;
	$side2LineNum++;
	
} # End of while loop.

#raw reads
my $nRawReads = 0;
$nRawReads = $stats->{ nRawReads } if(exists($stats->{ nRawReads }));

#both sides mapped - valid interaction.
my $bothSideMapped = 0;
$bothSideMapped = $stats->{ bothSideMapped } if(exists($stats->{ bothSideMapped }));

#side1
my $side1_good =  0;
$side1_good =  $stats->{ side1_match } if(exists($stats->{ side1_match }));

#side2
my $side2_good =  0;
$side2_good =  $stats->{ side2_match } if(exists($stats->{ side2_match }));

#neither side1 nor side1 mapped.
my $noMap = 0;
$noMap = $stats->{ noMap } if(exists($stats->{ noMap }));

#only 1 side mapped.
my $single = 0;
$single = $stats->{ single } if(exists($stats->{ single }));

#valud 'C' pairs.
my $valid = 0;
$valid = $stats->{ valid } if(exists($stats->{ valid }));

#impossible (error) 'C' pairs.
my $error = 0;
$error = $stats->{ error } if(exists($stats->{ error }));

#f homo
my $fHomo = 0;
$fHomo = $stats->{ fHomo } if(exists($stats->{ fHomo }));

#r homo
my $rHomo = 0;
$rHomo = $stats->{ rHomo } if(exists($stats->{ rHomo }));

#invalid
my $invalid = ($fHomo+$rHomo);

close(SIDE1);
close(SIDE2);

close(VALIDPAIR);
close(HOMOPAIR);

open(OUT,">".$jobName.".mapping.log");

print OUT "numRawReads\t".$nRawReads."\n";
print OUT "side1Mapped\t".$side1_good."\n";
print OUT "side2Mapped\t".$side2_good."\n";
print OUT "noSideMapped\t".$noMap."\n";
print OUT "oneSideMapped\t".$single."\n";
print OUT "bothSideMapped\t".$bothSideMapped."\n";
print OUT "errorPairs\t".$error."\n";
print OUT "invalidPairs\t".$invalid."\n";
print OUT "validPairs\t".$valid."\n";
print OUT "fHomo\t".$fHomo."\n";
print OUT "rHomo\t".$rHomo."\n";
print OUT "same|->.->\t".$stats->{ same }{"->.->"}."\n";
print OUT "same|->.<-\t".$stats->{ same }{"->.<-"}."\n";
print OUT "same|<-.->\t".$stats->{ same }{"<-.->"}."\n";
print OUT "same|<-.<-\t".$stats->{ same }{"<-.<-"}."\n";
print OUT "different|->.->\t".$stats->{ different }{"->.->"}."\n";
print OUT "different|->.<-\t".$stats->{ different }{"->.<-"}."\n";
print OUT "different|<-.->\t".$stats->{ different }{"<-.->"}."\n";
print OUT "different|<-.<-\t".$stats->{ different }{"<-.<-"}."\n";

close(OUT);
