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

sub getFileName($) {
	my $fileName=shift;
	
	my $shortName=(split(/\//,$fileName))[-1];
	$shortName =~ s/\.gz$//;
	
	return($shortName);
}	

my %options;
my $results = GetOptions( \%options,'input_side1|s1=s','input_side2|s2=s');

my ($input_side1,$input_side2);
($input_side1,$input_side2)=check_options( \%options );

my $input_side1_name=getFileName($input_side1);
my $input_side2_name=getFileName($input_side2);

$input_side1 = "gunzip -c '".$input_side1."' | " if(($input_side1 =~ /\.gz$/) and (!(-T($input_side1))));
open (SIDE1,$input_side1) or die $!;
$input_side2 = "gunzip -c '".$input_side2."' | " if(($input_side2 =~ /\.gz$/) and (!(-T($input_side2))));
open (SIDE2,$input_side2) or die $!;

my $output_side1=$input_side1_name.".stripped.gz";
$output_side1 .= ".gz" if($output_side1 !~ /\.gz$/);
$output_side1 = "| gzip -c > '".$output_side1."'" if($output_side1 =~ /\.gz$/);
open(OUT1,$output_side1) || die("Could not open file for writing $!");

my $output_side2=$input_side2_name.".stripped.gz";
$output_side2 .= ".gz" if($output_side2 !~ /\.gz$/);
$output_side2 = "| gzip -c > '".$output_side2."'" if($output_side2 =~ /\.gz$/);
open(OUT2,$output_side2) || die("Could not open file for writing $!");

my $lineNum=0;
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
	
	print OUT1 "$line1\n";
	print OUT2 "$line2\n";
	$lineNum++;
	
	
} 
close(SIDE1);
close(SIDE2);
