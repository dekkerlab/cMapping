#! /usr/bin/perl
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Data::Dumper;

my %options;
my $results = GetOptions( \%options,
							'input_side1|s1=s',
							'input_side2|s2=s',
							'mode|m=s'
						);

################# GLOBALS ##################################
my $input_side1;
my $input_side2;
my $mode;
my ($COUT1, $COUT2, $MOUT1, $MOUT2);
&check_options( \%options );
############################################################
my $input_side1_correct = $input_side1.".correct";
my $input_side2_correct = $input_side2.".correct";
my $input_side1_messedup = $input_side1.".messedup";
my $input_side2_messedup = $input_side2.".messedup";

print "opening $input_side1_correct...\n";
print "opening $input_side2_correct...\n";
print "opening $input_side1_messedup...\n";
print "opening $input_side2_messedup...\n";
###########################################
# opening the files and getting the data. 
###########################################

open (my $SIDE1, $input_side1) or die "Can not open file $input_side1:$!";
open (my $SIDE2, $input_side2) or die "Can not open file $input_side2:$!";
my $total_side1_lines = `wc -l $input_side1`;
$total_side1_lines = (split(/\s/,$total_side1_lines))[0];
my $total_side2_lines = `wc -l $input_side2`;
$total_side2_lines = (split(/\s/,$total_side2_lines))[0];

die("input files have same number of lines...\n\ts1=$total_side1_lines vs s2=$total_side2_lines\n") if($total_side1_lines == $total_side2_lines);

my $brokenSide=0;
if($total_side1_lines < $total_side2_lines) {
	$brokenSide = 2;
} else {
	$brokenSide = 1;
}

print "\n----------------  Processing -----------------\n";
print "\t1)$input_side1($total_side1_lines)\n";
print "\t2)$input_side2($total_side2_lines)\n";

open ($COUT1,">$input_side1_correct" ) or die "Can not open file $input_side1_correct:$!";
open ($COUT2,">$input_side2_correct" ) or die "Can not open file $input_side2_correct:$!";
open ($MOUT1,">$input_side1_messedup") or die "Can not open file $input_side1_messedup:$!";
open ($MOUT2,">$input_side2_messedup") or die "Can not open file $input_side2_messedup:$!";

my $lineNum=0;
my $nErrors=0;

while((!eof($SIDE1)) and (!eof($SIDE2))){  
    # Reading both file line by line but only one line at a time.
    my $line1 = <$SIDE1>;
    my $line2 = <$SIDE2>;
    chomp ($line1);
    chomp ($line2);
    	
    # Get the keys and work the hash of those keys. 
    my @line1 = split(/\t/,$line1);
    my @line2 = split(/\t/,$line2);
	
	# parsing it for key/side
	my ($key1,$side1) =  split(/\//,$line1[0]); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
	my ($key2,$side2) =  split(/\//,$line2[0]); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2
	
	if ($key1 ne $key2) {
		
		print "\nBAD LINE @ $lineNum\n\t1:$key1\n\t2:$key2\n\n";
		
		if($brokenSide == 1) {
			#skip forward 1000 lines in good file
			for(my $i=0;$i<1000;$i++) {
				next if(eof($SIDE2));
				$line2 = <$SIDE2>;
				chomp ($line2);
				my @line2 = split(/\t/,$line2);
				($key2,$side2) =  split(/\//,$line2[0]); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
				$lineNum++;
			}
			print "anchoring on 2:$key2\n";
			while( ($key1 ne $key2) and (!eof($SIDE1)) ) {
				$line1 = <$SIDE1>;
				chomp ($line1);
				my @line1 = split(/\t/,$line1);
				($key1,$side1) =  split(/\//,$line1[0]); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
				#print "anchoring on 2:$key2 // 1:$key1...\n";
				#print "\t1:$line1\n";
				#print "\t2:$line2\n";
				#print "\n";
			}
			print "fixed on lineNum $lineNum\n";
			print $COUT1 "$key1\n";
			print $COUT2 "$key2\n";
			for(my $i=0; $i<3; $i++){
				next if( (eof($SIDE1)) or (eof($SIDE2)) );
				my $line1 = <$SIDE1>;
				my $line2 = <$SIDE2>;
				print $COUT1 $line1;
				print $COUT2 $line2;
				$lineNum++;
			}
		} else {
			#skip forward 1000 lines in good file
			for(my $i=0;$i<1000;$i++) {
				next if(eof($SIDE1));
				$line1 = <$SIDE1>;
				chomp ($line1);
				my @line1 = split(/\t/,$line1);
				($key1,$side1) =  split(/\//,$line1[0]); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
				$lineNum++;
			}
			print "anchoring on 1:$key1\n";
			while( ($key1 ne $key2) and (!eof($SIDE2)) ) {
				$line2 = <$SIDE2>;
				chomp ($line2);
				my @line2 = split(/\t/,$line2);
				($key2,$side2) =  split(/\//,$line2[0]); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
				#print "anchoring on 1:$key1 // 2:$key2...\n";
				#print "\t1:$line1\n";
				#print "\t2:$line2\n";
				#print "\n";
			}
			print "fixed on lineNum $lineNum\n";
			print $COUT1 "$key1\n";
			print $COUT2 "$key2\n";
			for(my $i=0; $i<3; $i++){
				next if( (eof($SIDE1)) or (eof($SIDE2)) );
				my $line1 = <$SIDE1>;
				my $line2 = <$SIDE2>;
				print $COUT1 $line1;
				print $COUT2 $line2;
				$lineNum++;
			}
		}
	}else{
		print $COUT1 "$key1\n";
		print $COUT2 "$key2\n";
		for(my $i=0; $i<3; $i++){
			my $line1 = <$SIDE1>;
			my $line2 = <$SIDE2>;
			print $COUT1 $line1;
			print $COUT2 $line2;
			$lineNum++;
		}
	}
	$lineNum++;
	print "checked $lineNum lines...\n\t$key1 == $key2\n" if $lineNum % 100000 == 0;
} # End of while loop.

close($SIDE1);
close($SIDE2);

sub check_options {
    my $opts = shift;

	if( exists($opts->{'input_side1'}) ) {
		$input_side1 = $opts->{'input_side1'};
    } else {
		die "Option input_side1|s1 is required.\n";
    }
	if( exists($opts->{'input_side2'}) ) {
		$input_side2 = $opts->{'input_side2'};
    } else {
		die "Option input_side2|s2 is required.\n";
    }
	
}