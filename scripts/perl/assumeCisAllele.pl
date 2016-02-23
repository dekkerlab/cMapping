#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
    my $opts = shift;

    my ($jobName,$inputFragmentAssignedFile_side1,$inputFragmentAssignedFile_side2);
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		die("input jobName|jn is required.\n");
	}
	
	if( exists($opts->{ inputFragmentAssignedFile_side1 }) ) {
		$inputFragmentAssignedFile_side1 = $opts->{ inputFragmentAssignedFile_side1 };
	} else {
		die("input inputFragmentAssignedFile_side1|i1 is required.\n");
	}
	
	if( exists($opts->{ inputFragmentAssignedFile_side2 }) ) {
		$inputFragmentAssignedFile_side2 = $opts->{ inputFragmentAssignedFile_side2 };
	} else {
		die("input inputFragmentAssignedFile_side2|i2 is required.\n");
	}
	
	return($jobName,$inputFragmentAssignedFile_side1,$inputFragmentAssignedFile_side2);
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

sub assumeCisAllele($$) {
	my $side1ReadArrayRef=shift;
	my $side2ReadArrayRef=shift;
	
	my $chromosome_1=$side1ReadArrayRef->[2];
	my $chromosome_2=$side2ReadArrayRef->[2];
	
	my $side1CisOverrideFlag=0;
	my $side1CisOverrideAllele = "NA";
	my $side2CisOverrideFlag=0;
	my $side2CisOverrideAllele = "NA";
	
	# if identical allelic mapping - done
	return($side1ReadArrayRef,$side2ReadArrayRef,$side1CisOverrideFlag,$side2CisOverrideFlag,$side1CisOverrideAllele,$side2CisOverrideAllele) if($chromosome_1 eq $chromosome_2);
	
	# chromosome names are not equal
	
	# check to see if amb chromosomes are same?
	my @chromosome_1_arr=split(/-/,$chromosome_1);
	my @chromosome_2_arr=split(/-/,$chromosome_2);
	
	die("\nERROR:  improper allelic chromosome name format ($chromosome_1)\n") if(@chromosome_1_arr > 2);
	die("\nERROR:  improper allelic chromosome name format ($chromosome_2)\n") if(@chromosome_2_arr > 2);
	
	my $ambChromosome_1=$chromosome_1_arr[0];
	my $allelicChromosome_1=$chromosome_1_arr[1];
	my $ambChromosome_2=$chromosome_2_arr[0];
	my $allelicChromosome_2=$chromosome_2_arr[1];
	
	# if trans, return
	return($side1ReadArrayRef,$side2ReadArrayRef,$side1CisOverrideFlag,$side2CisOverrideFlag,$side1CisOverrideAllele,$side2CisOverrideAllele) if($ambChromosome_1 ne $ambChromosome_2);

	# must be cis now
	die("\nERROR:  non-identical amb chromosomes\n") if($ambChromosome_1 ne $ambChromosome_2);
	my $ambChromosome=$ambChromosome_1=$ambChromosome_2;
	
	# if neither is amb, return
	return($side1ReadArrayRef,$side2ReadArrayRef,$side1CisOverrideFlag,$side2CisOverrideFlag,$side1CisOverrideAllele,$side2CisOverrideAllele) if(($chromosome_1 ne $ambChromosome) and ($chromosome_2 ne $ambChromosome));

	# chromsomes are same, 1 allelic and 1 amb
	
	if($chromosome_1 eq $ambChromosome) { # 1 is amb, 2 is allelic 
		$side1ReadArrayRef->[2] = $side1ReadArrayRef->[2]."-".$allelicChromosome_2;
		$side1CisOverrideFlag=1 if($side1ReadArrayRef->[2] ne $chromosome_1);
	} elsif($chromosome_2 eq $ambChromosome) { # 2 is amb, 1 is allelic
		$side2ReadArrayRef->[2] = $side2ReadArrayRef->[2]."-".$allelicChromosome_1;
		$side2CisOverrideFlag=1 if($side2ReadArrayRef->[2] ne $chromosome_2);
	} else {
		die("\nERROR:  invalid allelic override case! ($chromosome_1 vs $chromosome_2)\n");
	}
	
	$side1CisOverrideAllele = (split(/-/,$side1ReadArrayRef->[2]))[-1] if($side1CisOverrideFlag == 1);
	push(@$side1ReadArrayRef,"CW:AO:".$side1CisOverrideAllele) if($side1CisOverrideFlag == 1);
	
	$side2CisOverrideAllele = (split(/-/,$side2ReadArrayRef->[2]))[-1] if($side2CisOverrideFlag == 1);
	push(@$side2ReadArrayRef,"CW:AO:".$side2CisOverrideAllele) if($side2CisOverrideFlag == 1);  #orig has a bug here, was == 2...
		
	return($side1ReadArrayRef,$side2ReadArrayRef,$side1CisOverrideFlag,$side2CisOverrideFlag,$side1CisOverrideAllele,$side2CisOverrideAllele);
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
my $results = GetOptions( \%options,'jobName|jn=s','inputFragmentAssignedFile_side1|i1=s','inputFragmentAssignedFile_side2|i2=s');
my ($jobName,$inputFragmentAssignedFile_side1,$inputFragmentAssignedFile_side2)=check_options( \%options );

die("File does not exist! ($inputFragmentAssignedFile_side1)\n") if(!(-e($inputFragmentAssignedFile_side1)));
die("File does not exist! ($inputFragmentAssignedFile_side2)\n") if(!(-e($inputFragmentAssignedFile_side2)));

my %alleleOverrideLog=();
$alleleOverrideLog{ side1_allele }=0;
$alleleOverrideLog{ side2_allele }=0;

open(OUTSIDE1,">".$inputFragmentAssignedFile_side1.".cisAlleled.sam");
open(OUTSIDE2,">".$inputFragmentAssignedFile_side2.".cisAlleled.sam");

open(SIDE1,$inputFragmentAssignedFile_side1) or die "cannot open ($inputFragmentAssignedFile_side1) : $!";
open(SIDE2,$inputFragmentAssignedFile_side2) or die "cannot open ($inputFragmentAssignedFile_side2) : $!";
my $lineNum=1;
while((!eof(SIDE1)) || (!eof(SIDE2))) { 
	my $line1 = <SIDE1>;
	my $line2 = <SIDE2>;
	chomp ($line1);
	chomp ($line2);
	
	# split lines
	my @tmp1=split(/\t/,$line1);
	my @tmp2=split(/\t/,$line2);
	
	#check for side1/2 pairing via readID
	die("ERROR - (line # $lineNum) files are out of alignment! (".$tmp1[0]." != ".$tmp2[0].")\n\t$line1\n\t$line2\n") if($tmp1[0] ne $tmp2[0]);
	
	# assign all allele|ambigious interactions as cis allele|allele
	if(($tmp1[2] ne "*") and ($tmp2[2] ne "*")) { # if both sides are mapped - assume cis allele | override
		
		my $overrideFlag="";
		my ($tmp1Ref,$tmp2Ref,$side1CisOverrideFlag,$side2CisOverrideFlag,$side1CisOverrideAllele,$side2CisOverrideAllele)=assumeCisAllele(\@tmp1,\@tmp2);
		$alleleOverrideLog{ side1_allele }++ if($side1CisOverrideFlag == 1);
		$alleleOverrideLog{ side2_allele }++ if($side2CisOverrideFlag == 1);
		
		$alleleOverrideLog{ "side1_allele_".$side1CisOverrideAllele}++ if($side1CisOverrideFlag == 1);
		$alleleOverrideLog{ "side2_allele_".$side2CisOverrideAllele}++ if($side2CisOverrideFlag == 1);
		
		@tmp1=@$tmp1Ref;
		@tmp2=@$tmp2Ref;
		
		$overrideFlag="__OR" if(($side1CisOverrideFlag + $side2CisOverrideFlag) == 1);
		my $chrInteraction="chrPair__".$tmp1[2]."__".$tmp2[2].$overrideFlag;
		
		$line1="";
		for(my $i=0;$i<@tmp1;$i++) {
			$line1 .= $tmp1[$i];
			$line1 .= "\t" if($i != @tmp1);
		}
		
		$line2="";
		for(my $i=0;$i<@tmp2;$i++) {
			$line2 .= $tmp2[$i];
			$line2 .= "\t" if($i != @tmp2);
		}
		
		$alleleOverrideLog{ $chrInteraction }++;
		
	}
	
	print OUTSIDE1 "$line1\n";
	print OUTSIDE2 "$line2\n";
	
	$lineNum++;
}

close(SIDE1);
close(SIDE2);

close(OUTSIDE1);
close(OUTSIDE2);

# log allele override stats
open(ALLELELOG,">".$jobName.".alleleOverride.log");
print ALLELELOG "field\tcount\n";
foreach my $field (sort keys %alleleOverrideLog) {
	my $count=$alleleOverrideLog{$field};
	print ALLELELOG "$field\t$count\n";
}
close(ALLELELOG);