#! /usr/bin/perl
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Data::Dumper;

my $file1 = $ARGV[0]; # s_2_1_sequence.txt
my $file2 = $ARGV[1]; # s_2_2_sequence.txt

## Get the total number of lines in the file
# Reminiscent of the 2>&1 syntax of many shells, this line instructs perl to send standard error to the same place it sends standard out.

my $file1_count = `wc -l $file1 2>&1`; 
my $file2_count = `wc -l $file2 2>&1`; 

my $correct_file = 0;
my $total_lines = 0;
if($file1_count !~ /error/i){
	$correct_file = 1;
	$total_lines = (split(/ /,$file1_count))[0];
	chomp $total_lines;
}elsif($file2_count !~ /error/i){
	$correct_file = 2;
	$total_lines = (split(/ /,$file2_count))[0];
	chomp $total_lines;
}else{
	$correct_file = 3;
	die "both $file1 and $file2 are corrupt. Please look at this case\n";
}

## get the bad sector coordinates
my $file_bad_sector_start=0;
my $file_bad_sector_end  =0;
if($correct_file != 1){
	($file_bad_sector_start,$file_bad_sector_end) = &get_bad_file_sector_coords($file1, $file1_count);
}elsif($correct_file != 2){
	($file_bad_sector_start,$file_bad_sector_end) = &get_bad_file_sector_coords($file2, $file2_count);
}
print "Total lines in the corrected file:$total_lines\n";
print "-----------------------------------------------\n\n";

print "Creating fresh files with correct number of lines...\n";
# Create output directories
my $output_dir = "correct_files";
unless (-d $output_dir){ 
	print   "- mkdir -p $output_dir\n";
	system ("mkdir -p $output_dir");
}
if($correct_file == 1){
	&create_new_correct_file($file2);
	print "\n===>[sed -n '1,$file_bad_sector_start p;$file_bad_sector_end,$total_lines p' $file1 >$output_dir/$file1]\n";
	system("sed -n '1,$file_bad_sector_start p;$file_bad_sector_end,$total_lines p' $file1 >$output_dir/$file1");
}elsif($correct_file == 2){
	&create_new_correct_file($file1);
	print "\n===>[sed -n '1,$file_bad_sector_start p;$file_bad_sector_end,$total_lines p' $file2 >$output_dir/$file2]\n";
	system("sed -n '1,$file_bad_sector_start p;$file_bad_sector_end,$total_lines p' $file2 >$output_dir/$file2");
}

## Get the new correct files
sub create_new_correct_file {
	my $file = shift;
	my $top_temp_file = "top_temp_$file";
	my $bottom_temp_file = "bottom_temp_$file";
	print "===>[cat $file >$output_dir/$top_temp_file]\n";
	system("cat $file >$output_dir/$top_temp_file");

	print "===>[tac $file >$bottom_temp_file]\n";
	system("tac $file >$bottom_temp_file");

	print "===>[tac $bottom_temp_file >$output_dir/$bottom_temp_file]\n";
	system("tac $bottom_temp_file >$output_dir/$bottom_temp_file");

	print "===>[cat $output_dir/$top_temp_file $output_dir/$bottom_temp_file > $output_dir/$file]\n";	
	system("cat $output_dir/$top_temp_file $output_dir/$bottom_temp_file > $output_dir/$file");	

	print "===>[rm $output_dir/$top_temp_file $bottom_temp_file $output_dir/$bottom_temp_file]\n";
	system("rm $output_dir/$top_temp_file $bottom_temp_file $output_dir/$bottom_temp_file");
}

## Get the bad sector coordinates
sub get_bad_file_sector_coords {
	my $file = shift;
	my $file_count = shift;
	my $file_bad_sector_start = (split(/ /,(split(/\n/,$file_count))[1]))[0];
	chomp $file_bad_sector_start;
	print "-----------------------------------------------\n";
	$file_bad_sector_start=&get_forth_header_line($file_bad_sector_start, 1);
	print "$file bad sector start:$file_bad_sector_start\n";
	
	my $file_bad_sector_end = `tac $file1 2>&1| wc -l`;
	chomp $file_bad_sector_end;
	$file_bad_sector_end = $total_lines - $file_bad_sector_end;
	$file_bad_sector_end=&get_forth_header_line($file_bad_sector_end,2);
	print "$file bad sector end  :$file_bad_sector_end\n";
	
	return $file_bad_sector_start,$file_bad_sector_end;
}

sub get_forth_header_line {
	my $coord = shift;
	my $type  = shift; # 1 for start and 2 for end
	if ($type == 1 ){
		if($coord % 4 == 3){
			$coord -=3;
			print "$coord % 4 is 3; subtract 3 from start coord\n";
		}elsif($coord % 4 == 2){
			$coord -=2;
			print "$coord % 4 is 2; subtract 2 from start coord\n";
		}elsif($coord % 4 == 1){
			$coord -=1;
			print "$coord % 4 is 1; subtract 1 from start coord\n";
		}
	}
	if ($type == 2 ){
		if($coord % 4 == 3){
			$coord +=1;
			print "$coord % 4 is 3 add 1 to end coord\n";
		}elsif($coord % 4 == 2){
			$coord +=2;
			print "$coord % 4 is 2 add 2 to end coord\n";
		}elsif($coord % 4 == 1){
			$coord +=3;
			print "$coord % 4 is 1 add 3 to end coord\n";
		}
	}
	return $coord;
}