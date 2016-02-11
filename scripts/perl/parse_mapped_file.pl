#! /usr/bin/perl

=head1 NAME

parse_mapped_file.pl - Description

=head1 SYNOPSIS

USAGE: parse_mapped_file.pl
    --inputFastQFile|ir=/path/to/read/file
	--inputSamFile|is=/path/to/mapped/file
	--iter|iter = iteration/to/trim
	--side|side = side1/or/side2/file
	--outputDir|o = output/directory/for/output/files

=head1 HOW_TO_RUN

perl scripts/parse_mapped_file.pl -ir=inputSamFiles/s_3_1_sequence.txt.0.sam.noMap.fastq -im=inputSamFiles/s_3_1_sequence.txt.25.sam -o=output_mapped_files/ -iter=25 -side=1

=head1 OPTIONS

B<--inputSamFile,-im> 
REQUIRED. A file describing the sequencing mapping file with all the necessary fields mentioned in the DESCRIPTION section.

B<--inputFastQFile,-ir>
REQUIRED. FastQ reads file.

B<--iter,-iter>
Truncation length(trimmed to 25bp/30bp/...) at each iteration.

B<--side,-side>
side1 or side2 file from the sequencing data

B<--outputDir,-o>
Output files are in the file format mentioned in the DESCRIPTION section.

=head1  DESCRIPTION

Parse_mapped_file.pl will take a SAM file and output 3 files.

Here is a brief description of the SAM fields:
   1) Name of read that aligned
   2) Sum of all applicable flags. Flags relevant to Bowtie are:
      1   = The read is one of a pair
      2   = The alignment is one end of a proper paired-end alignment
      4   = The read has no reported alignments
      8   = The read is one of a pair and has no reported alignments
      16  = The alignment is to the reverse reference strand
      32  = The other mate in the paired-end alignment is aligned to the reverse reference strand
      64  = The read is mate 1 in a pair
      128 = The read is mate 2 in a pair
      Thus, an unpaired read that aligns to the reverse reference strand will have flag 16. A paired-end read that aligns and is the first mate in the pair will have flag 83 (= 64 + 16 + 2 + 1).
   3) Name of reference sequence where alignment occurs
   4) 1-based offset into the forward reference strand where leftmost character of the alignment occurs
   5) Mapping quality
   6) CIGAR string representation of alignment
   7) Name of reference sequence where mate's alignment occurs. Set to = if the mate's reference sequence is the same as this alignment's, or * if there is no mate.
   8) 1-based offset into the forward reference strand where leftmost character of the mate's alignment occurs. Offset is 0 if there is no mate.
   9) Inferred fragment size. Size is negative if the mate's alignment occurs upstream of this alignment. Size is 0 if there is no mate.
   10) Read sequence (reverse-complemented if aligned to the reverse strand)
   11) ASCII-encoded read qualities (reverse-complemented if the read aligned to the reverse strand). The encoded quality values are on the Phred quality scale and the encoding is ASCII-offset by 33 (ASCII char !), similarly to a FASTQ file.
   12) Optional fields. Fields are tab-separated. bowtie2 outputs zero or more of these optional fields for each alignment, depending on the type of the alignment:
      AS:i:<N> Alignment score. Can be negative. Can be greater than 0 in --local mode (but not in --end-to-end mode). Only present if SAM record is for an aligned read.
      XS:i:<N> Alignment score for second-best alignment. Can be negative. Can be greater than 0 in --local mode (but not in --end-to-end mode). Only present if the SAM record is for an aligned read and more than one alignment was found for the read.
      YS:i:<N> Alignment score for opposite mate in the paired-end alignment. Only present if the SAM record is for a read that aligned as part of a paired-end alignment.
      XN:i:<N> The number of ambiguous bases in the reference covering this alignment. Only present if SAM record is for an aligned read.
      XM:i:<N> The number of mismatches in the alignment. Only present if SAM record is for an aligned read.
      XO:i:<N> The number of gap opens, for both read and reference gaps, in the alignment. Only present if SAM record is for an aligned read.
      XG:i:<N> The number of gap extensions, for both read and reference gaps, in the alignment. Only present if SAM record is for an aligned read.
      NM:i:<N> The edit distance; that is, the minimal number of one-nucleotide edits (substitutions, insertions and deletions) needed to transform the read string into the reference string. Only present if SAM record is for an aligned read.
      YF:Z:<N> String indicating reason why the read was filtered out. See also: Filtering. Only appears for reads that were filtered out.
          YF:Z:LN: the read was filtered becuase it had length less than or equal to the number of seed mismatches set with the -N option.
          YF:Z:NS: the read was filtered because it contains a number of ambiguous characters (usually N or .) greater than the ceiling specified with --n-ceil.
          YF:Z:SC: the read was filtered because the read length and the match bonus (set with --ma) are such that the read can't possibly earn an alignment score greater than or equal to the threshold set with --score-min
          YF:Z:QC: the read was filtered because it was marked as failing quality control and the user specified the --qc-filter option. This only happens when the input is in Illumina's QSEQ format (i.e. when --qseq is specified) and the last (11th) field of the read's QSEQ record contains 1.
          If a read could be filtered for more than one reason, the value YF:Z flag will reflect only one of those reasons.
      MD:Z:<S> A string representation of the mismatched reference bases in the alignment. See SAM format specification for details. Only present if SAM record is for an aligned read.

    Here is a brief description of the 3 output files:
    1. Mapped file:
      1) Name
      2) Sequence
      3) +
      4) Quality values on Phred quality scale

   2. noMap file:
      SAM format described above

   3. Log file:
      A log file with all the statistics mentioned.

=head1  INPUT

   The input mapped file in SAM format:
   @HD     VN:1.0  SO:unsorted
   @SQ     SN:gi|350280536|gb|JF719728.1|  LN:5666
   @PG     ID:bowtie2      PN:bowtie2      VN:2.0.0-beta6
   2:1101:1011:2132:N      4       *       0       0       *       *       0       0       NGAACCAAACAGGCAAAAAATTTNGNNNNNNNNNNNNNNNNNNNNNNNNNN     #0;@@@@@?@@@?@@@@@@??@@############################     YT:Z:UU YF:Z:NS
   2:1101:1226:2139:Y      0       gi|350280536|gb|JF719728.1|     3656    40      51M     *       0       0       NGAATCAAAAAGAGCTTACTAAAATGCAACTGGACAATCAGAAAGAGATTN     #11ADDEFHHFHFHIHGHEHIGIJGGIJJJJIJHGIJGIIGGGHIIJJFH#     AS:i:-2 XN:i:0  XM:i:2  XO:i:0  XG:i:0 NM:i:2MD:Z:0A49G0      YT:Z:UU

=head1 OUTPUT

   The noMap output file format:
   @2:1101:1011:2132:N
   NGAACCAAACAGGCAAAAAATTTNGNNNNNNNNNNNNNNNNNNNNNNNNNN
   +
   #0;@@@@@?@@@?@@@@@@??@@############################

=head1  CONTACT

    Gaurav Jain
    gaurav.jain@umassmed.edu
	Bryan Lajoie
	bryan.lajoie@umassmed.edu

=cut


use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Data::Dumper;
use POSIX qw(ceil floor);

## --- Checks the options to the program ---
sub check_options {
	my $opts = shift;
	
	my ($inputFastQFile,$inputSamFile,$inputFileName,$iter,$side,$outputDir);
	
	if( $opts->{'inputFastQFile'} ) {
	    $inputFastQFile = $opts->{'inputFastQFile'};
	} else {
	    die("Option inputFastQFile|ir is required.");
	}
	
	if( $opts->{'inputSamFile'} ) {
	    $inputSamFile = $opts->{'inputSamFile'};
	} else {
	    die("Option inputSamFile|is is required.");
	}
	
	if( $opts->{'inputFileName'} ) {
	    $inputFileName = $opts->{'inputFileName'};
	} else {
	    die("Option inputFileName|in is required.");
	}
				
	if( $opts->{'outputDir'} ) {
	    $outputDir = $opts->{'outputDir'};
		$outputDir =~ s/\/$//; #remove the last /
		$outputDir .= "/";
	} else {
	    $outputDir = "";
	}
	
	if( $opts->{'iter'} ) {
	    $iter = $opts->{'iter'};
	} else {
	    die("Option iter is required.");
	}
	
	if( $opts->{'side'} ) {
	    $side = $opts->{'side'};
		die("ERROR: Wrong side. Expected(1 or 2). You have entered: $side\n") if $side !~ /[1|2]/;
	} else {
	    die("Option side is required.");
	}
	
	return($inputFastQFile,$inputSamFile,$inputFileName,$iter,$side,$outputDir);
}

my %options;
my $results = GetOptions( \%options,'inputFastQFile|if=s','inputSamFile|is=s','inputFileName|in=s','outputDir|o=s','side|side=s','iter|iter=s');
my ($inputFastQFile,$inputSamFile,$inputFileName,$iter,$side,$outputDir)=check_options( \%options );

my $noMap_output_file = $outputDir.$inputFileName.".i".$iter.".noMap.fastq";
my $mappedOutputFile = $outputDir.$inputFileName.".i".$iter.".mapped.sam";
my $unMappedOutputFile = $outputDir.$inputFileName.".i".$iter.".unMapped.sam";
my $log_file   = $outputDir.$inputFileName.".i".$iter.".log";
my $stats_file   = $outputDir.$inputFileName.".i".$iter.".stats";
my $log_header = $outputDir."iterativeMapping.header";

open (my $NOMAP, ">$noMap_output_file") or die "Can not open output file: $noMap_output_file :$!";
open (my $MAPPED, ">$mappedOutputFile") or die "Can not open output file: $mappedOutputFile :$!";
open (my $UNMAPPED, ">$unMappedOutputFile") or die "Can not open output file: $unMappedOutputFile :$!";
open (my $LOG, ">$log_file") or die "Can not open output file: $log_file :$!";
open (my $STATS, ">$stats_file") or die "Can not open output file: $stats_file :$!";

# if header file does not exit then create one. If exists, skip.
unless (-e $log_header) {
	open (my $LOGHEADER, ">$log_header") or die "Can not open output file: $log_header :$!";
	print $LOGHEADER "Side\tIteration\tTOTALreads\tZeroAlignedNo\tOneAlignedNo\tOnePlusAlignedNo\tOneMinusAlignedNo\tMultipleAlignedNo\tZeroAlignedPc\tOneAlignedPc\tOnePlusAlignedPc\tOneMinusAlignedPc\tMultipleAlignedPc\n";
	close $LOGHEADER;
}

open (my $INREAD, $inputFastQFile) or die "Can not open file: $inputFastQFile :$!";
open (my $SAM, $inputSamFile) or die "Can not open file: $inputSamFile :$!";

my $noMap_no = 0;
my $plus_mapping_no  = 0;
my $minus_mapping_no = 0;
my $repeat_no = 0;
my $total_reads=0;

my $lineNum=0;
while(my $mappedLine = <$SAM>){
	chomp($mappedLine);
	$lineNum++;
	
	next if(($mappedLine =~ m/^\"/) or ($mappedLine eq "") or ($mappedLine =~ /^\s*$/)); #skip blank lines
	next if($mappedLine =~ /^@/); # skip any possible SAM header lines
	
	$total_reads++;
	my $flag = (split(/\t/,$mappedLine))[1];
	
	# skip any non-mapped / repeat alignments
	if((($mappedLine =~ /XS:/) || ($flag == 4)) || ($flag >= 256)) {
	
		# If the option XS exists, this means its a non-unique alignment.i.e matched to more than one once
		my $name    = (split(/\t/,$mappedLine))[0];
		my $seq     = (split(/\t/,$mappedLine))[9];
		my $quality = (split(/\t/,$mappedLine))[10];
		
		for(my $i=0;$i<4;$i++) {
			my $readLine=<$INREAD>;
			chomp($readLine);
			
			# remove extra identifiers from name
			my $mappedName=$name;
			$mappedName =~ s/^@//;
			$mappedName =~ s/\/1//;
			$mappedName =~ s/\/2//;
			$mappedName = (split(/ /,$mappedName))[0];
			
			# remove extra identifiers from name
			my $readLineName=$readLine;
			$readLineName =~ s/^@//;
			$readLineName =~ s/\/1//;
			$readLineName =~ s/\/2//;
			$readLineName = (split(/ /,$readLineName))[0];
		
			die("\nERROR: $readLineName != $mappedName\n\tlineNum: $lineNum\n\tinputReadFile: $inputFastQFile\n\tinputMappedFile: $inputSamFile\n\tside: $side\n\titeration: $iter\n\n") if(($i == 0) and ($readLineName ne $mappedName)); 
			print $NOMAP "$readLine\n";
		}
		
		print $UNMAPPED "$mappedLine\n";
		
		$noMap_no++  if $flag == 4;
		$repeat_no++ if $mappedLine =~ /XS/;
		
	} elsif(($flag == 0) or ($flag == 16)) {
	
		$plus_mapping_no++ if($flag == 0);
		$minus_mapping_no++ if($flag == 16);
		print $MAPPED "$mappedLine\n";
		
		# cycle through 4 lines of the read file
		for(my $i=0;$i<4;$i++) {
			my $readLine=<$INREAD>;
		}
		
	} else { # any other case
		
		die("\nERROR: ($inputSamFile)\n\tfound invalid SAM flag ($flag) @ line # $lineNum...\n$mappedLine\n\n");
		
	}
}

# Gathering stats
my $mapping_no = $plus_mapping_no + $minus_mapping_no;
my ($zeroPC,$onePC,$PonePC,$MonePC,$morePC);
$zeroPC=$onePC=$PonePC=$MonePC=$morePC=0;
if($total_reads != 0) {
	$zeroPC = sprintf("%2.2f",$noMap_no*100/$total_reads);
	$onePC  = sprintf("%2.2f",$mapping_no*100/$total_reads);
	$PonePC = sprintf("%2.2f",$plus_mapping_no*100/$total_reads);
	$MonePC = sprintf("%2.2f",$minus_mapping_no*100/$total_reads);
	$morePC = sprintf("%2.2f",$repeat_no*100/$total_reads);
}

print $LOG "\n\@______ FINAL STATS(iteration=$iter) _______\@\n";
print $LOG "$total_reads\tTotal reads\n";
print $LOG "$noMap_no\t0 aligned reads\t($zeroPC\%)\n";
print $LOG "$mapping_no\texactly 1 aligned reads\t($onePC\%)\n";
print $LOG "$plus_mapping_no\texactly 1 aligned reads mapped to positive reference strand\t($PonePC\%)\n";
print $LOG "$minus_mapping_no\texactly 1 aligned reads mapped to reverse  reference strand\t($MonePC\%)\n";
print $LOG "$repeat_no\t>1 aligned reads\t($morePC\%)\n\n";

# Print to the log file
print $STATS "$side\t$iter\t$total_reads\t$noMap_no\t$mapping_no\t$plus_mapping_no\t$minus_mapping_no\t$repeat_no\t$zeroPC\t$onePC\t$PonePC\t$MonePC\t$morePC\n";

close $SAM;
close $NOMAP;
close $MAPPED;
close $UNMAPPED;
close $STATS;
close $LOG;

