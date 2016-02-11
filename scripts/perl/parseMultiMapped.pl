#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

sub check_options {
    my $opts = shift;

    my ($inputSamFile,$outputSamFile,$debugMode,$minimumReadDistance);
	
	if( exists($opts->{ inputSamFile }) ) {
		$inputSamFile = $opts->{ inputSamFile };
	} else {
		die("input inputSamFile|is is required.\n");
	}
	
	if( exists($opts->{ outputSampFile }) ) {
		$outputSamFile = $opts->{ outputSamFile };
	} else {
		$outputSamFile = $inputSamFile;
		$outputSamFile =~ s/\.sam$//;
		$outputSamFile .= ".condensed.sam";
	}
	
	if( exists($opts->{ debugMode }) ) {
		$debugMode = 1;
	} else {
		$debugMode = 0;
	}
	
	if( exists($opts->{ minimumReadDistance }) ) {
		$minimumReadDistance = $opts->{ minimumReadDistance };
	} else {
		$minimumReadDistance = 5;
	}
	
	return($inputSamFile,$outputSamFile,$debugMode,$minimumReadDistance);
}
	
sub trashAlignment($$) {
	my $readLine=shift;
	my $debugMode=shift;
		
	my @tmp=split(/\t/,$readLine);
	my $nColumns=@tmp;
	
	my $tmp_readID=$tmp[0]; # same for all readID
	my $tmp_flag=4; # set to 4 (flag for unmapped)
	my $tmp_rname="*"; # set to * (entry for unmapped)
	my $tmp_pos=0; # set to 0 (entry for unmapped)
	my $tmp_mapq=$tmp[4]; # same for all readID
	my $tmp_cigar="*"; # set to *
	my $tmp_rnext="*"; # set to *
	my $tmp_pnext=0; # set to 0
	my $tmp_tlen=0; # set to 0
	my $tmp_seq=$tmp[9]; # same for all readID
	my $tmp_qual=$tmp[10]; # same for all readID
		
	my %readTags=();
	for(my $f=11;$f<$nColumns;$f++) {
		my $tmp_field=$tmp[$f];
		my ($tmp_tag,$tmp_type,$tmp_value)=split(/\:/,$tmp_field);
		$readTags{$tmp_tag}{ type }=$tmp_type;
		$readTags{$tmp_tag}{ value }=$tmp_value;
		$readTags{$tmp_tag}{ fullField }=$tmp_field;
	}
	
	my $pgFlag=$readTags{ PG }{ fullField }; # flag for alligner (assume always the same)
	my $zsFlag="ZS:Z:R";  #set flag for repeat alignment (cannot assume always exists)
	my $nhFlag=$readTags{ NH }{ fullField }; # flag for # of alignments (assume always the same)
	
	my $trashedReadLine="$tmp_readID\t$tmp_flag\t$tmp_rname\t$tmp_pos\t$tmp_mapq\t$tmp_cigar\t$tmp_rnext\t$tmp_pnext\t$tmp_tlen\t$tmp_seq\t$tmp_qual\t$pgFlag\t$zsFlag\t$nhFlag";
	my $tmp_ZQscore=$readTags{ ZQ }{ value };
	$trashedReadLine="$tmp_readID\t$tmp_flag\t$tmp_rname\t$tmp_pos\t$tmp_mapq\t$tmp_cigar\t$tmp_ZQscore" if($debugMode == 1);
	
	return($trashedReadLine);

}

sub filterAlignment($$$) {
	my $readLine=shift;
	my $uniqueFlag=shift;
	my $debugMode=shift;
		
	my @tmp=split(/\t/,$readLine);
	my $nColumns=@tmp;
	
	my $tmp_readID=$tmp[0]; # same for all readID
	my $tmp_flag=$tmp[1]; # should be 0 || 16 (flag for unique [first readID line])
	my $tmp_rname=$tmp[2]; # removset to * (entry for unmapped)
	$tmp_rname=(split(/-/,$tmp[2]))[0] if($uniqueFlag == 0); # if non-unique -> ambigious mapping! remove SNP info
	my $tmp_pos=$tmp[3];
	my $tmp_mapq=$tmp[4]; 
	my $tmp_cigar=$tmp[5];
	my $tmp_rnext="*"; # set to *
	my $tmp_pnext=0; # set to 0 
	my $tmp_tlen=0; # set to 0 
	my $tmp_seq=$tmp[9]; # same for all readID
	my $tmp_qual=$tmp[10]; # same for all readID
		
	my %readTags=();
	for(my $f=11;$f<$nColumns;$f++) {
		my $tmp_field=$tmp[$f];
		my ($tmp_tag,$tmp_type,$tmp_value)=split(/\:/,$tmp_field);
		$readTags{$tmp_tag}{ type }=$tmp_type;
		$readTags{$tmp_tag}{ value }=$tmp_value;
		$readTags{$tmp_tag}{ fullField }=$tmp_field;
	}

	my $pgFlag=$readTags{ PG }{ fullField }; # flag for alligner (assume always the same)
	my $asFlag=$readTags{ AS }{ fullField }; # flag for # of alignments (assume always the same)
	my $uqFlag=$readTags{ UQ }{ fullField }; # flag for # of alignments (assume always the same)
	my $nmFlag=$readTags{ NM }{ fullField }; # flag for # of alignments (assume always the same)
	my $mdFlag=$readTags{ MD }{ fullField }; # flag for # of alignments (assume always the same)

	my $filteredReadLine="$tmp_readID\t$tmp_flag\t$tmp_rname\t$tmp_pos\t$tmp_mapq\t$tmp_cigar\t$tmp_rnext\t$tmp_pnext\t$tmp_tlen\t$tmp_seq\t$tmp_qual\t$pgFlag\t$asFlag\t$uqFlag\t$nmFlag\t$mdFlag";
	my $tmp_ZQscore=$readTags{ ZQ }{ value };
	$filteredReadLine="$tmp_readID\t$tmp_flag\t$tmp_rname\t$tmp_pos\t$tmp_mapq\t$tmp_cigar\t$tmp_ZQscore" if($debugMode == 1);
	
	return($filteredReadLine);

}


sub selectBestAlignment($$$$) {
	my $readBufferRef=shift;
	my $readID=shift;
	my $minimumReadDistance=shift;
	my $debugMode=shift;
	my $nReads=@$readBufferRef;
	
	my $seq="NA";
	my $qual="NA";
	
	# if only 1 alignment for readID - return as best
	print "$readID\t$nReads\n" if($debugMode == 1);
	
	return($readBufferRef->[0]) if($nReads == 1);
	
	my $bestAlignmentLine="";
	my $bestAlignmentScore=-1;
	my $bestAlignmentKey="";
	my $bestAlignmentPos="";
	
	my $uniqueFlag=0; 
	my $ambigiousFlag=0;
	
	# assuming reads are pre-sorted by score (highest->lowest)
	for(my $i=0;$i<$nReads;$i++) {
		my $readLine=$readBufferRef->[$i];
	
		my @tmp=split(/\t/,$readLine);
		my $nColumns=@tmp;
	
		my $tmp_readID=$tmp[0];
		my $tmp_flag=$tmp[1];
		my $tmp_rname=$tmp[2];
		my $tmp_pos=$tmp[3];
		my $tmp_key=$tmp_rname."@".$tmp_pos;
		my $tmp_mapq=$tmp[4];
		my $tmp_cigar=$tmp[5];
		my $tmp_rnext=$tmp[6];
		my $tmp_pnext=$tmp[7];
		my $tmp_tlen=$tmp[8];
		my $tmp_seq=$tmp[9];
		my $tmp_qual=$tmp[10];
		
		my %readTags=();
		for(my $f=11;$f<$nColumns;$f++) {
			my $tmp_field=$tmp[$f];
			my ($tmp_tag,$tmp_type,$tmp_value)=split(/\:/,$tmp_field);
			$readTags{$tmp_tag}{ type }=$tmp_type;
			$readTags{$tmp_tag}{ value }=$tmp_value;
			$readTags{$tmp_tag}{ fullField }=$tmp_field;
		}
		
		my $tmp_ZQscore="NA";
		$tmp_ZQscore=$readTags{ ZQ }{ value } if(exists($readTags{ ZQ }));
		my $tmp_alignmentSoftware="NA";
		$tmp_alignmentSoftware=$readTags{ PG }{ fullField } if(exists($readTags{ ZS }));
		
		print "\t\t$tmp_readID [$tmp_seq]\t$tmp_flag\t$tmp_rname\t$tmp_pos\t$tmp_mapq\t$tmp_cigar\t$tmp_ZQscore\n" if($debugMode == 1);
		
		$bestAlignmentLine=$readLine if($i == 0);
		$bestAlignmentScore=$tmp_ZQscore if($i == 0);
		$bestAlignmentKey=$tmp_rname."@".$tmp_pos if($i == 0);
		$bestAlignmentPos=$tmp_pos if($i == 0);
		
		$uniqueFlag=1 if((abs($tmp_ZQscore-$bestAlignmentScore) >= $minimumReadDistance) and ($i != 0));
		
		$bestAlignmentLine=$readLine if($tmp_ZQscore > $bestAlignmentScore); # technically impossible if sorted
		
		return(trashAlignment($readLine,$debugMode)) if((($tmp_key eq $bestAlignmentKey) and ($tmp_ZQscore == $bestAlignmentScore)) and ($i != 0));
		return(trashAlignment($readLine,$debugMode)) if((($tmp_pos ne $bestAlignmentPos) and ($tmp_ZQscore == $bestAlignmentScore)) and ($i != 0));
		
		$ambigiousFlag=1 if(($tmp_key ne $bestAlignmentKey) and ($tmp_ZQscore == $bestAlignmentScore));
		
		$bestAlignmentKey=$tmp_rname."@".$tmp_pos if($tmp_ZQscore >= $bestAlignmentScore);
		$bestAlignmentPos=$tmp_pos if($tmp_ZQscore >= $bestAlignmentScore);
		$bestAlignmentScore=$tmp_ZQscore if($tmp_ZQscore > $bestAlignmentScore);
		
		#next if($uniqueFlag == 1);
		
	}
	
	return(filterAlignment($bestAlignmentLine,$uniqueFlag,$debugMode));
	
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
my $results = GetOptions( \%options,'inputSamFile|is=s','outputSamFile|os=s','debugMode|d','minimumReadDistance|mrd=s');
my ($inputSamFile,$outputSamFile,$debugMode,$minimumReadDistance)=check_options( \%options );

if($debugMode == 1) {
	print "\n";
	print "--- inputs ---\n";
	print "inputSamFile (-is)\t$inputSamFile\n";
	print "outputSamFile (-os)\t$outputSamFile\n";
	print "debugMode [FLAG] (-d)\t$debugMode\n";
	print "minimumReadDistance (-mrd) [5]\t$minimumReadDistance\n";
	print "--- inputs ---\n";
	print "\n";
}

die("File does not exist! ($inputSamFile)\n") if(!(-e($inputSamFile)));

open(OUT,">".$outputSamFile) or die("cannot open ($outputSamFile): $!") if($debugMode == 0);
open(IN,$inputSamFile) or die("cannot open ($inputSamFile): $!");

my $lastReadID="NA";
my @readBuffer=();

while(my $line = <IN>) {
	chomp ($line);
	next if($line =~ /^@/);
	
	my @tmp=split(/\t/,$line);	
	my $readID=$tmp[0];
	
	
	if($lastReadID eq "NA") {
		@readBuffer=();
		push(@readBuffer,$line);
	} elsif($lastReadID eq $readID) {
		push(@readBuffer,$line);
	} elsif($lastReadID ne $readID) {
		my $bestAlignment=selectBestAlignment(\@readBuffer,$lastReadID,$minimumReadDistance,$debugMode);
		print "\t* $bestAlignment\n\n" if($debugMode == 1);
		print OUT "$bestAlignment\n" if($debugMode == 0);
		@readBuffer=();
		push(@readBuffer,$line);
	}
	$lastReadID=$readID;
}

# and perform the final read
my $bestAlignment=selectBestAlignment(\@readBuffer,$lastReadID,$minimumReadDistance,$debugMode);
print "\t* $bestAlignment\n\n" if($debugMode == 1);
print OUT "$bestAlignment\n" if($debugMode == 0);