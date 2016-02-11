#! /usr/bin/perl

=head1 NAME

collapse_stats_file.pl - Description

=head1 SYNOPSIS

USAGE: collapse_stats_file.pl
	--input_file|i = /path/to/concatenated/stats/file
    --side|s=side

=head1 HOW_TO_RUN

perl scripts/collapse_stats_file.pl -i=output_mapped_files/s_3_1_sequence.txt.25.stats -s 1

=head1 OPTIONS

B<--input_file,-i> 
REQUIRED. *.stat file for any iteration that need to be collapse in the file format mentioned in the DESCRIPTION section.

B<--side,-s>
side of read

=head1  DESCRIPTION

collapse_stats_file.pl  will take a *.stats file for a particular iteration(25,30,35,...) by summing/averaging up the same iteration value.

=head1  INPUT

   The input stats file :
   1       25      2500    555     1908    669     1239    37      22.20   76.32   26.76   49.56   1.48
   1       25      2500    512     1947    655     1292    41      20.48   77.88   26.20   51.68   1.64
   1       25      2500    483     1975    704     1271    42      19.32   79.00   28.16   50.84   1.68
   1       25      2500    511     1947    714     1233    42      20.44   77.88   28.56   49.32   1.68
   1       25      2500    503     1967    707     1260    30      20.12   78.68   28.28   50.40   1.20
   1       25      2500    531     1936    707     1229    33      21.24   77.44   28.28   49.16   1.32
   1       25      2500    479     1979    681     1298    42      19.16   79.16   27.24   51.92   1.68
   1       25      2500    522     1935    687     1248    43      20.88   77.40   27.48   49.92   1.72
   1       25      2500    538     1917    694     1223    45      21.52   76.68   27.76   48.92   1.80
   1       25      2500    517     1932    748     1184    51      20.68   77.28   29.92   47.36   2.04

=head1 OUTPUT

   1       25      2500    555     1908    669     1239    37      22.20   76.32   26.76   49.56   1.48


=head1  CONTACT

    Gaurav Jain
    gaurav.jain@umassmed.edu

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Data::Dumper;
use POSIX qw(ceil floor);

my %options;
my $results = GetOptions( \%options,
                          'input_file|i=s',
						  'side|s=s');
						  
################# GLOBALS ##################################
my $input_file;
my $side;
############################################################
&check_options( \%options );

my @tmp=split(/\//,$input_file);
my $inputFileName=$tmp[@tmp-1];
my $path="";
$path = join '/', @tmp[0..$#tmp-1] if(@tmp > 1);
$path .= "/" if(@tmp > 1);
$inputFileName =~ /^(.*?)\.txt\.(.*?)$/; # s_3_1_sequence.txt.25.stats
my $output_file = $path."iterativeMapping.".$side.".".$2;

open (my $STATS, ">$output_file") or die "Can not open output file: $output_file :$!";

my @cols;
my $total_lines = 0;
open (my $IN, $input_file) or die "Can not open file: $input_file :$!";
while(my $line = <$IN>){
	# 1       25      2500    555     1908    669     1239    37      22.20   76.32   26.76   49.56   1.48
	# 1       25      2500    512     1947    655     1292    41      20.48   77.88   26.20   51.68   1.64
	# 1       25      2500    483     1975    704     1271    42      19.32   79.00   28.16   50.84   1.68
	# 1       25      2500    511     1947    714     1233    42      20.44   77.88   28.56   49.32   1.68
	chomp($line);
	next if(($line =~ m/^\#/) or (($line =~ m/^\"/))or ($line eq "")or ($line =~ /^\s*$/));
	
	$total_lines++;
	my @row = split(/\t/, $line);
	for(my $i=0; $i < 2; $i++){
		$cols[$i] = $row[$i];
	}

	for(my $i=2; $i < @row; $i++){
		$cols[$i] += $row[$i];
	}
}

# now average the colums from (length/2)+1 - length
my $len = scalar @cols;
# since col4(555,512,...)to col8(37,41,....) is the sum and 
# col9 to col13 are the percentages of those colums. 
# Thats why to get col9 = starting avg column number we do this.  
my $avg_start = (($len-3)/2)+3; 
for(my $i=$avg_start; $i < $len; $i++){
	$cols[$i] /= $total_lines;
}

# Print to output file
my $print_str = "";
for(my $i=0; $i < $len; $i++){
	$print_str.=$cols[$i]."\t";
}

#remove last \t and add \n
$print_str =~ s/\t$//;
print $STATS "$print_str\n";

## --- Checks the options to the program ---
sub check_options {
	my $opts = shift;

	if( $opts->{'input_file'} ) {
	    $input_file = $opts->{'input_file'};
	} else {
	    die("Option input_file|i is required.");
	}
	
	if( $opts->{'side'} ) {
	    $side = $opts->{'side'};
	} else {
	    die("Option side|s is required.");
	}
}
