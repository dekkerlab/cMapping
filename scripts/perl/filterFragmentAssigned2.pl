#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
    my $opts = shift;

    my ($jobName,$inputFragmentAssignedFile_side1,$inputFragmentAssignedFile_side2,$minMoleculeSize,$maxMoleculeSize,$boundedLimit);
	
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
	
	if( exists($opts->{ minMoleculeSize }) ) {
		$minMoleculeSize = $opts->{ minMoleculeSize };
	} else {
		$minMoleculeSize=50;
	}
	
	if( exists($opts->{ maxMoleculeSize }) ) {
		$maxMoleculeSize = $opts->{ maxMoleculeSize };
	} else {
		$maxMoleculeSize = 450;
	}
	
	if( exists($opts->{ boundedLimit }) ) {
		$boundedLimit = $opts->{ boundedLimit };
	} else {
		$boundedLimit = 5;
	}
	
	return($jobName,$inputFragmentAssignedFile_side1,$inputFragmentAssignedFile_side2,$minMoleculeSize,$maxMoleculeSize,$boundedLimit);

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

sub flipSides($$) {
	my $line1=shift;
	my $line2=shift;
	
	my @tmp1=split(/\t/,$line1);
	my @tmp2=split(/\t/,$line2);
	
	# side 1 read information
	my $mappingType_1=$tmp1[0];
	my $mappingBitFlag_1=$tmp1[1];
	my $chromosome_1=$tmp1[2];
	my $readPos_1=$tmp1[3];
	my $strand_1=$tmp1[4];
	my $readID_1=$tmp1[5];
	my $fragmentIndex_1=$tmp1[6];
	my $fragmentStartPos_1=$tmp1[7];
	my $fragmentEndPos_1=$tmp1[8];
	
	# side 2 read information
	my $mappingType_2=$tmp2[0];
	my $mappingBitFlag_2=$tmp2[1];
	my $chromosome_2=$tmp2[2];
	my $readPos_2=$tmp2[3];
	my $strand_2=$tmp2[4];
	my $readID_2=$tmp2[5];
	my $fragmentIndex_2=$tmp2[6];
	my $fragmentStartPos_2=$tmp2[7];
	my $fragmentEndPos_2=$tmp2[8];
	
	return($line1,$line2) if(($fragmentIndex_1 eq ".") or ($fragmentIndex_2 eq "."));
	
	if($fragmentIndex_1 == $fragmentIndex_2) {
		if($readPos_1 < $readPos_2) {
			return($line1,$line2);
		} else {
			return($line2,$line1);
		}
	} else { # non equal frag index
		if($fragmentIndex_1 < $fragmentIndex_2) {
			return($line1,$line2);
		} else {
			return($line2,$line1);
		}
	}
	
	die("ERROR!");
}

sub getDirection($$) {
	my $strand_1=shift;
	my $strand_2=shift;
	
	my $direction_1 = strand2direction($strand_1);
	my $direction_2 = strand2direction($strand_2);
	
	my $direction = $direction_1."__".$direction_2;
	
	my $directionClassification="NA";
	$directionClassification="topStrand" if($direction eq "->__->");
	$directionClassification="bottomStrand" if($direction eq "<-__<-");
	$directionClassification="inward" if($direction eq "->__<-");
	$directionClassification="outward" if($direction eq "<-__->");
	
	return($direction,$directionClassification);
}
	
sub logMappingData($$$$) {
	my $side1ReadArrayRef=shift;
	my $side2ReadArrayRef=shift;
	my $mappingLog=shift;
	my $interactionType=shift;
	
	# side 1 read information
	my $mappingType_1=$side1ReadArrayRef->[0];
	my $mappingBitFlag_1=$side1ReadArrayRef->[1];
	my $chromosome_1=$side1ReadArrayRef->[2];
	my $readPos_1=$side1ReadArrayRef->[3];
	my $strand_1=$side1ReadArrayRef->[4];
	my $readID_1=$side1ReadArrayRef->[5];
	my $fragmentIndex_1=$side1ReadArrayRef->[6];
	my $fragmentStartPos_1=$side1ReadArrayRef->[7];
	my $fragmentEndPos_1=$side1ReadArrayRef->[8];
	
	# side 2 read information
	my $mappingType_2=$side2ReadArrayRef->[0];
	my $mappingBitFlag_2=$side2ReadArrayRef->[1];
	my $chromosome_2=$side2ReadArrayRef->[2];
	my $readPos_2=$side2ReadArrayRef->[3];
	my $strand_2=$side2ReadArrayRef->[4];
	my $readID_2=$side2ReadArrayRef->[5];
	my $fragmentIndex_2=$side2ReadArrayRef->[6];
	my $fragmentStartPos_2=$side2ReadArrayRef->[7];
	my $fragmentEndPos_2=$side2ReadArrayRef->[8];
	
	$mappingLog->{ ML_side1 }->{$mappingType_1}++;
	$mappingLog->{ ML_side2 }->{$mappingType_2}++;
	
	return($mappingLog);
}
		
sub annotateInteraction($$$) {
	my $side1ReadArrayRef=shift;
	my $side2ReadArrayRef=shift;
	my $boundedLimit=shift;
	
	# side 1 read information
	my $mappingType_1=$side1ReadArrayRef->[0];
	my $mappingBitFlag_1=$side1ReadArrayRef->[1];
	my $chromosome_1=$side1ReadArrayRef->[2];
	my $readPos_1=$side1ReadArrayRef->[3];
	my $strand_1=$side1ReadArrayRef->[4];
	my $readID_1=$side1ReadArrayRef->[5];
	my $fragmentIndex_1=$side1ReadArrayRef->[6];
	my $fragmentStartPos_1=$side1ReadArrayRef->[7];
	my $fragmentEndPos_1=$side1ReadArrayRef->[8];
	
	# side 2 read information
	my $mappingType_2=$side2ReadArrayRef->[0];
	my $mappingBitFlag_2=$side2ReadArrayRef->[1];
	my $chromosome_2=$side2ReadArrayRef->[2];
	my $readPos_2=$side2ReadArrayRef->[3];
	my $strand_2=$side2ReadArrayRef->[4];
	my $readID_2=$side2ReadArrayRef->[5];
	my $fragmentIndex_2=$side2ReadArrayRef->[6];
	my $fragmentStartPos_2=$side2ReadArrayRef->[7];
	my $fragmentEndPos_2=$side2ReadArrayRef->[8];

	my $interactionCategory="NA";
	my $interactionClassification="NA";
	my $interactionType="NA";
	my $interactionSubType="NA";
	
	# handle unmapped + singleSideMapped cases
	return("bad",$interactionClassification,"unMapped",$interactionSubType) if(($fragmentIndex_1 eq ".") and ($fragmentIndex_2 eq "."));
	return("bad",$interactionClassification,"singleSide",$interactionSubType) if(($fragmentIndex_1 eq ".") xor ($fragmentIndex_2 eq "."));
	
	$interactionClassification = "cis" if($chromosome_1 eq $chromosome_2);
	$interactionClassification = "trans" if($chromosome_1 ne $chromosome_2);
	
	# assume both reads are mapped now
	if($fragmentIndex_1 == $fragmentIndex_2) {
		# if same frag, and same strand -> error
		
		if($strand_1 eq $strand_2) { # same strand
			return ("bad",$interactionClassification,"error",$interactionSubType);
		} else { #different strand
		
			if( (($strand_1 eq "+") and ($strand_2 eq "-")) and ($readPos_1 < $readPos_2) ) { # dangling end 1-> <-2
				my $boundedFlag=0;
				$interactionSubType="internal";
				
				$boundedFlag = 1 if( (($readPos_1-$fragmentStartPos_1) <= $boundedLimit) or (($fragmentEndPos_2-$readPos_2) <= $boundedLimit) );
				$interactionSubType="bounded" if($boundedFlag == 1);
				
				return ("bad",$interactionClassification,"danglingEnd",$interactionSubType);
			} elsif( (($strand_1 eq "-") and ($strand_2 eq "+")) and ($readPos_2 < $readPos_1) ) { # dangling end 2-> <-1
				my $boundedFlag=0;
				$interactionSubType="internal";
				
				$boundedFlag = 1 if( (($readPos_2-$fragmentStartPos_1) <= $boundedLimit) or (($fragmentEndPos_1-$readPos_1) <= $boundedLimit) );
				$interactionSubType="bounded" if($boundedFlag == 1);
				
				return ("bad",$interactionClassification,"danglingEnd",$interactionSubType);
			} elsif( (($strand_1 eq "+") and ($strand_2 eq "-")) and ($readPos_1 >= $readPos_2) ) { # self circle 2<- ->1
				return ("bad",$interactionClassification,"selfCircle",$interactionSubType) 
			} elsif( (($strand_1 eq "-") and ($strand_2 eq "+")) and ($readPos_2 >= $readPos_1) ) { # self circle 1<- ->2
				return ("bad",$interactionClassification,"selfCircle",$interactionSubType) 
			} else {
				print "\n";
				print "$chromosome_1\t$readPos_1\t$strand_1\t$readID_1\t$fragmentIndex_1\t$fragmentStartPos_1\t$fragmentEndPos_1\n";
				print "$chromosome_2\t$readPos_2\t$strand_2\t$readID_2\t$fragmentIndex_2\t$fragmentStartPos_2\t$fragmentEndPos_2\n";
				print "\n";
				die("invalid case!");
			}
		}
	} else {
		return("good",$interactionClassification,"validPair",$interactionSubType);
	}
	
	die("error with classifying interaction!");
}

sub strand2direction($) {
	my $mappingStrand=shift;
	
	die("invalid strand! ($mappingStrand)\n") if(($mappingStrand ne "-") and ($mappingStrand ne "+") and ($mappingStrand ne "."));
	
	my $direction="NA";
	$direction="->" if($mappingStrand eq "+");
	$direction="<-" if($mappingStrand eq "-");
	
	return($direction);
}	
	
	
sub getMoleculeSize($$$$$) {
	my $side1ReadArrayRef=shift;
	my $side2ReadArrayRef=shift;
	my $interactionType=shift;
	my $minMoleculeSize=shift;
	my $maxMoleculeSize=shift;
	
	# side 1 read information
	my $mappingType_1=$side1ReadArrayRef->[0];
	my $mappingBitFlag_1=$side1ReadArrayRef->[1];
	my $chromosome_1=$side1ReadArrayRef->[2];
	my $readPos_1=$side1ReadArrayRef->[3];
	my $strand_1=$side1ReadArrayRef->[4];
	my $readID_1=$side1ReadArrayRef->[5];
	my $fragmentIndex_1=$side1ReadArrayRef->[6];
	my $fragmentStartPos_1=$side1ReadArrayRef->[7];
	my $fragmentEndPos_1=$side1ReadArrayRef->[8];
	
	# side 2 read information
	my $mappingType_2=$side2ReadArrayRef->[0];
	my $mappingBitFlag_2=$side2ReadArrayRef->[1];
	my $chromosome_2=$side2ReadArrayRef->[2];
	my $readPos_2=$side2ReadArrayRef->[3];
	my $strand_2=$side2ReadArrayRef->[4];
	my $readID_2=$side2ReadArrayRef->[5];
	my $fragmentIndex_2=$side2ReadArrayRef->[6];
	my $fragmentStartPos_2=$side2ReadArrayRef->[7];
	my $fragmentEndPos_2=$side2ReadArrayRef->[8];
	
	my $moleculeSize=-1;
	
	if($interactionType eq "danglingEnd") {
		
		$moleculeSize = ($readPos_2-$readPos_1);
		die("invalid moleculeSize ($moleculeSize)\n") if($moleculeSize < 0);
		
	} elsif($interactionType eq "selfCircle") {
		
		my $side1_distance=($readPos_1 - $fragmentStartPos_1);
		die("invalid side1_distance ($side1_distance)\n") if($side1_distance < 0);
		
		my $side2_distance=($fragmentEndPos_2 - $readPos_2);
		die("invalid side2_distance ($side2_distance)\n") if($side2_distance < 0);
		
		$moleculeSize = ($side1_distance+$side2_distance);
		die("invalid moleculeSize ($moleculeSize)\n") if($moleculeSize < 0);
		
	} elsif($interactionType eq "validPair") {
		
		my $side1_distance=-1;
		$side1_distance=($fragmentEndPos_1-$readPos_1) if($strand_1 eq "+");
		$side1_distance=($readPos_1-$fragmentStartPos_1) if($strand_1 eq "-");
		die("invalid side1_distance ($side1_distance)\n") if($side1_distance < 0);
		
		my $side2_distance=-2;
		$side2_distance=($fragmentEndPos_2-$readPos_2) if($strand_2 eq "+");
		$side2_distance=($readPos_2-$fragmentStartPos_2) if($strand_2 eq "-");
		die("invalid side2_distance ($side2_distance)\n") if($side2_distance < 0);
		
		$moleculeSize = ($side1_distance+$side2_distance);
		die("invalid moleculeSize ($moleculeSize)\n") if($moleculeSize < 0);
		
	}
	
	my $moleculeSizeFlag="good";
	$moleculeSizeFlag = "bad" if(($moleculeSize < $minMoleculeSize) or ($moleculeSize > $maxMoleculeSize));
	
	return($moleculeSize,$moleculeSizeFlag);
}

sub getInteractionDistance($$$;$) {
	my $side1ReadArrayRef=shift;
	my $side2ReadArrayRef=shift;
	my $interactionType=shift;
	#optional
	my $cisApproximateFactor=shift || 1;
	
	# side 1 read information
	my $mappingType_1=$side1ReadArrayRef->[0];
	my $mappingBitFlag_1=$side1ReadArrayRef->[1];
	my $chromosome_1=$side1ReadArrayRef->[2];
	my $readPos_1=$side1ReadArrayRef->[3];
	my $strand_1=$side1ReadArrayRef->[4];
	my $readID_1=$side1ReadArrayRef->[5];
	my $fragmentIndex_1=$side1ReadArrayRef->[6];
	my $fragmentStartPos_1=$side1ReadArrayRef->[7];
	my $fragmentEndPos_1=$side1ReadArrayRef->[8];
	
	# side 2 read information
	my $mappingType_2=$side2ReadArrayRef->[0];
	my $mappingBitFlag_2=$side2ReadArrayRef->[1];
	my $chromosome_2=$side2ReadArrayRef->[2];
	my $readPos_2=$side2ReadArrayRef->[3];
	my $strand_2=$side2ReadArrayRef->[4];
	my $readID_2=$side2ReadArrayRef->[5];
	my $fragmentIndex_2=$side2ReadArrayRef->[6];
	my $fragmentStartPos_2=$side2ReadArrayRef->[7];
	my $fragmentEndPos_2=$side2ReadArrayRef->[8];
	
	my $realInteractionDistance=-1;
	my $interactionDistance=-1;
	my $fragmentDistance=-1;
	
	if(($interactionType eq "validPair") and ($chromosome_1 eq $chromosome_2)) {
		$realInteractionDistance = ($fragmentStartPos_2 - $fragmentEndPos_1);
		$fragmentDistance = ($fragmentIndex_2-$fragmentIndex_1);
	}
		
	#transform dist into approximate dist if necessary
	$interactionDistance = floor($realInteractionDistance/$cisApproximateFactor) if(($realInteractionDistance != -1) and ($realInteractionDistance != 0)); #do not re-scale if TRANS or SELF
	
	return($realInteractionDistance,$interactionDistance,$fragmentDistance);
}

sub condenseLine($) {
	my $readArrayRef=shift;
	
	# side 1 read information
	my $mappingType=$readArrayRef->[0];
	my $mappingBitFlag=$readArrayRef->[1];
	my $chromosome=$readArrayRef->[2];
	my $readPos=$readArrayRef->[3];
	my $strand=$readArrayRef->[4];
	my $readID=$readArrayRef->[5];
	my $fragmentIndex=$readArrayRef->[6];
	my $fragmentStartPos=$readArrayRef->[7];
	my $fragmentEndPos=$readArrayRef->[8];
	
	my $condensedLine = "$mappingType\t$chromosome\t$readPos\t$strand\t$readID\t$fragmentIndex";

	return($condensedLine);
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
my $results = GetOptions( \%options,'jobName|jn=s','inputFragmentAssignedFile_side1|i1=s','inputFragmentAssignedFile_side2|i2=s','minMoleculeSize|min=s','stdevMolecuelSize|max=s','boundedLimit|bl=s');
my ($jobName,$inputFragmentAssignedFile_side1,$inputFragmentAssignedFile_side2,$minMoleculeSize,$maxMoleculeSize,$boundedLimit)=check_options( \%options );

my $cisApproximateFactor=1000;

die("File does not exist! ($inputFragmentAssignedFile_side1)\n") if(!(-e($inputFragmentAssignedFile_side1)));
die("File does not exist! ($inputFragmentAssignedFile_side2)\n") if(!(-e($inputFragmentAssignedFile_side2)));

my %nearbyStrandBias=();
my %moleculeSizes=();

my %log=();
my %categoryChoices = ('good' => 1,'bad' => 1);
my %classificationChoices = ('NA' => 1,'cis' => 1,'trans' => 1);
my %typeChoices = ('singleSide' => 1,'unMapped' => 1,'danglingEnd' => 1,'error' => 1,'selfCircle' => 1,'validPair' => 1);
my %subTypeChoices = ('NA' => 1,'bounded' => 1,'internal' => 1);
my %directionChoices = ('inward' => 1,'outward' => 1,'topStrand' => 1,'bottomStrand' => 1,'NA' => 1);

my $mappingLog={};
$mappingLog->{ ML_side1 }->{ U }=0;
$mappingLog->{ ML_side1 }->{ MM }=0;
$mappingLog->{ ML_side1 }->{ NM }=0;
$mappingLog->{ ML_side2 }->{ U }=0;
$mappingLog->{ ML_side2 }->{ MM }=0;
$mappingLog->{ ML_side2 }->{ NM }=0;

my $validPairFile=$jobName.".validPair.txt.gz";

open(VALIDPAIR,outputWrapper($validPairFile)) or die "cannot open (".$validPairFile.") : $!";

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
	
	die("invalid line 1 format! ($line1)\n") if(@tmp1 != 9);
	die("invalid line 2 format! ($line2)\n") if(@tmp2 != 9);
	
	my $header1=(split(/ /,$tmp1[5]))[0];
	$header1 =~ s/#\/1//;
	$header1 =~ s/\/1//;
	my $header2=(split(/ /,$tmp2[5]))[0];
	$header2 =~ s/#\/2//;
	$header2 =~ s/\/2//;

	#check for side1/2 pairing via readID
	die("ERROR - (line # $lineNum) files are out of alignment! (".$header1." != ".$header2.")\n\t$inputFragmentAssignedFile_side1\n\t\t$line1\n\t$inputFragmentAssignedFile_side2\n\t\t$line2") if($header1 ne $header2);
	
	# orient the reads to 5' is on left (startPos/chr)
	($line1,$line2)=flipSides($line1,$line2);

	# split lines
	@tmp1=split(/\t/,$line1);
	@tmp2=split(/\t/,$line2);
	
	# get the interaction type
	my ($interactionCategory,$interactionClassification,$interactionType,$interactionSubType)=annotateInteraction(\@tmp1,\@tmp2,$boundedLimit);
	my ($direction,$directionClassification)=getDirection($tmp1[4],$tmp2[4]);
	
	my ($moleculeSize,$moleculeSizeFlag)=getMoleculeSize(\@tmp1,\@tmp2,$interactionType,$minMoleculeSize,$maxMoleculeSize);
	$moleculeSizes{$moleculeSize}++ if($interactionType eq "danglingEnd");
    print "$moleculeSize\n$line1\n$line2\n\n" if(($interactionType eq "danglingEnd") and ($moleculeSize < 50));
	
	my ($realInteractionDistance,$interactionDistance,$fragmentDistance)=getInteractionDistance(\@tmp1,\@tmp2,$interactionType,$cisApproximateFactor);
	$nearbyStrandBias{$interactionDistance}{$directionClassification}++ if(($realInteractionDistance >= 0) and ($realInteractionDistance <= 1000000));
 
	$mappingLog=logMappingData(\@tmp1,\@tmp2,$mappingLog,$interactionType);
	
	$log{$interactionCategory}{$interactionClassification}{$interactionType}{$interactionSubType}{$directionClassification}++;
	
	my $condensedLine1=condenseLine(\@tmp1);
	my $condensedLine2=condenseLine(\@tmp2);
	print VALIDPAIR "$condensedLine1\t$condensedLine2\n" if($interactionCategory eq "good");

	$lineNum++;
}

close(VALIDPAIR);

# aggregrate results

# log the dangling end molecule sizes
open(MOLECULESIZE,">".$jobName.".moleculeSize.log");
print MOLECULESIZE "moleculeSize\tcount\n";
foreach my $moleculeSize ( sort { $a <=> $b } keys(%moleculeSizes) ) {
	my $count=$moleculeSizes{$moleculeSize};
	print MOLECULESIZE "$moleculeSize\t$count\n";
}
close(MOLECULESIZE);


# validate choice hash encompasses all possible options
foreach my $interactionCategory (sort keys %log) {
	foreach my $interactionClassification (sort keys %{$log{$interactionCategory}}) {
		foreach my $interactionType (sort keys %{$log{$interactionCategory}{$interactionClassification}}) {
			foreach my $interactionSubType (sort keys %{$log{$interactionCategory}{$interactionClassification}{$interactionType}}) {
				foreach my $directionClassification (sort keys %{$log{$interactionCategory}{$interactionClassification}{$interactionType}{$interactionSubType}}) {
					die("interactionCategory ($interactionCategory) does not exist in choice hash!\n") if(!(exists($categoryChoices{$interactionCategory})));
					die("interactionClassification ($interactionClassification) does not exist in choice hash!\n") if(!(exists($classificationChoices{$interactionClassification})));
					die("interactionType ($interactionType) does not exist in choice hash!\n") if(!(exists($typeChoices{$interactionType})));
					die("interactionSubType ($interactionSubType) does not exist in choice hash!\n") if(!(exists($subTypeChoices{$interactionSubType})));
					die("directionClassification ($directionClassification) does not exist in choice hash!\n") if(!(exists($directionChoices{$directionClassification})));					
				}
			}
		}
	}
}
# log all interaction assignment data
open(LOG,">".$jobName.".interaction.log");
print LOG "interactionCategory\tinteractionClassification\tinteractionType\tinteractionSubType\tdirectionClassification\tcount\n";		
foreach my $interactionCategory (sort keys %categoryChoices) {
	foreach my $interactionClassification (sort keys %classificationChoices) {
		foreach my $interactionType (sort keys %typeChoices) {
			foreach my $interactionSubType (sort keys %subTypeChoices) {
				foreach my $directionClassification (sort keys %directionChoices) {
					my $count=0;
					next if(!(exists($log{$interactionCategory}{$interactionClassification}{$interactionType}{$interactionSubType}{$directionClassification})));
					$count=$log{$interactionCategory}{$interactionClassification}{$interactionType}{$interactionSubType}{$directionClassification} if(exists($log{$interactionCategory}{$interactionClassification}{$interactionType}{$interactionSubType}{$directionClassification}));
					print LOG "$interactionCategory\t$interactionClassification\t$interactionType\t$interactionSubType\t$directionClassification\t$count\n";
				}
			}
		}
	}
}

# log all mapping data
my $colNum=0;
open(MAPPINGLOG,">".$jobName.".mapping.log");
foreach my $side (sort keys %{$mappingLog}) {
	foreach my $value (sort keys %{$mappingLog->{$side}}) {
		print MAPPINGLOG "\t".$side."_".$value if($colNum != 0);
		print MAPPINGLOG $side."_".$value if($colNum == 0);
		$colNum++;
	}
}
print MAPPINGLOG "\n";
$colNum=0;
foreach my $side (sort keys %{$mappingLog}) {
	foreach my $value (sort keys %{$mappingLog->{$side}}) {
		my $count=$mappingLog->{$side}->{$value};
		print MAPPINGLOG "\t".$count if($colNum != 0);
		print MAPPINGLOG $count if($colNum == 0);
		$colNum++;
	}
}
print MAPPINGLOG "\n";
close(MAPPINGLOG);

# aggregrate the strand bias data
open(STRANDBIASLOG,">".$jobName.".strandBias.log");
print STRANDBIASLOG "distance\ttopStrand\tbottomStrand\tinward\toutward\n";		
foreach my $distance ( sort { $a <=> $b } keys(%nearbyStrandBias) ) {
		
	my $topStrandCount=0;
	$topStrandCount=$nearbyStrandBias{$distance}{ topStrand } if(exists($nearbyStrandBias{$distance}{ topStrand }));
	my $bottomStrandCount=0;
	$bottomStrandCount=$nearbyStrandBias{$distance}{ bottomStrand } if(exists($nearbyStrandBias{$distance}{ bottomStrand }));
	my $inwardCount=0;
	$inwardCount=$nearbyStrandBias{$distance}{ inward } if(exists($nearbyStrandBias{$distance}{ inward }));
	my $outwardCount=0;
	$outwardCount=$nearbyStrandBias{$distance}{ outward } if(exists($nearbyStrandBias{$distance}{ outward }));	
		
	print STRANDBIASLOG "$distance\t$topStrandCount\t$bottomStrandCount\t$inwardCount\t$outwardCount\n";
	
}
close(STRANDBIASLOG);
