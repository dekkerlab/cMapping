use strict;
use warnings;
use List::Util qw[min max];
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

sub check_options {
    my $opts = shift;
    my ($input_side1,$input_side2);
	$input_side1=$input_side2="";
 
	if( exists($opts->{'input_side1'}) ) {
		$input_side1 = $opts->{'input_side1'};
    } else {
		print "Option input_side1|s1 is required.\n";
		exit;
    }
	if( exists($opts->{'input_side2'}) ) {
		$input_side2 = $opts->{'input_side2'};
    } else {
		print "Option input_side2|s2 is required.\n";
		exit;
    }
	
	return($input_side1,$input_side2);
}

my %options;
my $results = GetOptions( \%options,'input_side1|s1=s','input_side2|s2=s');

my ($input_side1,$input_side2);
($input_side1,$input_side2)=check_options( \%options );

my @tmp=split(/\//,$input_side1);
my $logFile="unknownSample.log";
$logFile=$tmp[-3]."__".$tmp[-2].".log" if(@tmp >= 3);
open(LOG,">".$logFile);

$input_side1 = "gunzip -c '".$input_side1."' | " if(($input_side1 =~ /\.gz$/) and (!(-T($input_side1))));
open (SIDE1,$input_side1) or die $!;
$input_side2 = "gunzip -c '".$input_side2."' | " if(($input_side2 =~ /\.gz$/) and (!(-T($input_side2))));
open (SIDE2,$input_side2) or die $!;

my ($header1_1,$sequence1,$header1_2,$qv1,$header2_1,$sequence2,$header2_2,$qv2);

my $lineNum=0;
my $badLines=0;

while((!eof(SIDE1)) || (!eof(SIDE2))){ 
    	
    # Reading both file line by line but only one line at a time.
    my $line1 = <SIDE1>;
    my $line2 = <SIDE2>;
    chomp ($line1);
    chomp ($line2);
    
	#if either line starts with a # (comment line) skip.
	next if(($line1 =~ /^\# /) and ($line2 =~ /^\# /));
		
    # Get the keys and work the hash of those keys. 
    $line1 = (split(/ /,$line1))[0];
	$line2 = (split(/ /,$line2))[0];
	
	# Exit if keys doesn`t match.
	if(($lineNum % 4) == 0) {
		# parsing it for key/side
		
		if($lineNum != 0) {
			
			my ($key1_1,$side1_1) =  split(/\//,$header1_1); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
			my ($key2_1,$side2_1) =  split(/\//,$header2_1); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2
			my ($key1_2,$side1_2) =  split(/\//,$header1_2); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
			my ($key2_2,$side2_2) =  split(/\//,$header2_2); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2
			
			#print "$lineNum ... VALID ($key1_1 vs $key2_1)\n" if(($lineNum % 1000000) == 0);
			
			#if ( ($key1_1 ne $key2_1) 
			#	or ($key1_2 ne $key2_2)
			#	or ($header1_1 !~ /\/1$/)
			#	or ($header2_1 !~ /\/2$/)
			#	or (length($sequence1) != length($qv1)) 
			#	or (length($sequence2) != length($qv2)) ) {
			
            if ( (length($sequence1) != length($qv1)) 
				or (length($sequence2) != length($qv2)) ) {
				
				die("too many bad lines...$badLines\n") if($badLines > 10000);
				print LOG "ERROR1  @ lineNum : $lineNum\n";
				print LOG "SIDE1\t$header1_1\n$sequence1\n$header1_2\n$qv1\n";
				print LOG "SIDE2\t$header2_1\n$sequence2\n$header2_2\n$qv2\n";
				print LOG "\n";
				$badLines++;
			}
			
		}
		
		$header1_1=$line1;
		$header2_1=$line2;
		
		if(($header1_1 !~ /^\@/) or ($header2_1 !~ /^\@/)) {
			print LOG "ERROR2 @ lineNum : $lineNum\n";
			print LOG "SIDE1\t$header1_1\n$sequence1\n$header1_2\n$qv1\n";
			print LOG "SIDE2\t$header2_1\n$sequence2\n$header2_2\n$qv2\n";
			print LOG "\n";
		}
		
	} elsif(($lineNum % 4) == 1) {
		$sequence1=$line1;
		$sequence2=$line2;
		
		
	} elsif(($lineNum % 4) == 2) {
		$header1_2=$line1;
		$header2_2=$line2;
		
		if(($header1_2 !~ /^\+/) or ($header2_2 !~ /^\+/)) {
			print LOG "ERROR3 @ lineNum : $lineNum\n";
			print LOG "SIDE1\t$header1_1\n$sequence1\n$header1_2\n$qv1\n";
			print LOG "SIDE2\t$header2_1\n$sequence2\n$header2_2\n$qv2\n";
			print LOG "\n";
		}
		
	} elsif(($lineNum % 4) == 3) {
		$qv1=$line1;
		$qv2=$line2;
	}
	
	$lineNum++;
	
	
} 

my ($key1_1,$side1_1) =  split(/\//,$header1_1); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
my ($key2_1,$side2_1) =  split(/\//,$header2_1); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2
my ($key1_2,$side1_2) =  split(/\//,$header1_2); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
my ($key2_2,$side2_2) =  split(/\//,$header2_2); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2

if($lineNum != 0) {		
	if (($key1_1 ne $key2_1) or ($key1_2 ne $key2_2)) {
		print LOG "ERROR4 @ lineNum : $lineNum\n";
		print LOG "SIDE1\t$header1_1\n$sequence1\n$header1_2\n$qv1\n";
		print LOG "SIDE2\t$header2_1\n$sequence2\n$header2_2\n$qv2\n";
		print LOG "\n";
	}
}

close(SIDE1);
close(SIDE2);

close(LOG);
