#! /usr/bin/perl

=head1 NAME

get_bins_from_fasta.pl - Description

=head1 SYNOPSIS

USAGE: get_bins_from_fasta.pl
	--input_fasta_dir|fd = /path/to/fasta/directory
    --minimum_bin_size|mbs=minimum/bin/size

=head1 HOW_TO_RUN

perl perl scripts/get_bins_from_fasta.pl -fd=/cShare/data/genomes/fasta/HG19/ -mbs=30000

=head1 OPTIONS

B<--input_file,-fd> 
REQUIRED. directory of fasta files for a genome in the format mentioned in the DESCRIPTION section.

B<--minimum_bin_size,-mbs> 
REQUIRED. directory of fasta files for a genome in the format mentioned in the DESCRIPTION section.

B<--output_file,-o>
Output files are in the file format mentioned in the DESCRIPTION section.

=head1  DESCRIPTION

get_bins_from_fasta.pl  will take a directory of fasta files for a genome and returns the low, medium and high level bins.

=head1  INPUT

   Directory containing fasta files (*.fa)

=head1 OUTPUT

3157608038	1600000	300000	30000


=head1  CONTACT

    Gaurav Jain
    gaurav.jain@umassmed.edu

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Data::Dumper;
use File::Basename;
use POSIX qw(ceil floor);

my %options;
my $results = GetOptions( \%options,'input_fasta_dir|fd=s','minimum_bin_size|mbs=s',);

my $input_fasta_dir;
my $minimum_bin_size;

my $all  = 500;
my $low  = 2000;
my $med  = 10000;
my $high = 20000;

# my $low_level, $med_level, $high_level);
############################################################
&check_options( \%options );

my @fasta_file_names = glob($input_fasta_dir."/*.fa");
my $word_count = 0;
$word_count = `wc -c $input_fasta_dir/*.fa`;
chomp($word_count);

# 573902 /cShare/data/genomes/fasta/sacCer3/chr8.fa
# 448692 /cShare/data/genomes/fasta/sacCer3/chr9.fa
# 87501 /cShare/data/genomes/fasta/sacCer3/chrM.fa
# 12400364 total

# get last line
my $total_words = (split(/\n/,$word_count))[-1];
# get number
$total_words = (split(/ /,$total_words))[0];

my $all_level  = &round_up_to_nearest($total_words/$all, 500000);
my $low_level  = &round_up_to_nearest($total_words/$low, 100000);
my $med_level  = &round_up_to_nearest($total_words/$med, 50000);
my $high_level = &round_up_to_nearest($total_words/$high,10000);

$all_level = $minimum_bin_size if $all_level < $minimum_bin_size;
$low_level = $minimum_bin_size if $low_level < $minimum_bin_size;
$med_level = $minimum_bin_size if $med_level < $minimum_bin_size;
$high_level = $minimum_bin_size if $high_level < $minimum_bin_size;

my $all_bins=($total_words/$all_level);
my $low_bins=($total_words/$low_level);
my $med_bins=($total_words/$med_level);
my $high_bins=($total_words/$high_level);

print "$total_words|$all_level|$low_level|$med_level|$high_level";

####################### USER DEFINED FUNCTIONS #######################
sub round_up_to_nearest() {
	my $num     = shift;
	my $roundto = shift;

	return ceil($num/$roundto)*$roundto;
}

## --- Checks the options to the program ---
sub check_options {
	my $opts = shift;

	if( $opts->{'input_fasta_dir'} ) {
	    $input_fasta_dir = $opts->{'input_fasta_dir'};
		$input_fasta_dir =~ s/\/$//;
		die("Option input_fasta_dir|fd should be a directory.") unless -d $input_fasta_dir ;
	} else {
	    die("Option input_fasta_dir|fd is required.");
	}

	if( $opts->{'minimum_bin_size'} ) {
	    $minimum_bin_size = $opts->{'minimum_bin_size'};
		$minimum_bin_size = 10000 if($minimum_bin_size < 10000);
	} else {
		die("Option minimum_bin_size|mbs is required.");
	}
	
}
