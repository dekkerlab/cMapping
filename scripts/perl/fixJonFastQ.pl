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

sub getFileName($) {
	my $file=shift;
	
	my $fileName=(split(/\//,$file))[-1];
	my $shortName=$fileName;
	$shortName =~ s/\.matrix\.gz$//;
	$shortName =~ s/\.matrix$//;
	$shortName =~ s/\.gz$//;
	
	# if non-matrix file - remove extension
	$shortName=removeFileExtension($shortName) if($shortName eq $fileName);
	
	return($shortName);
}	

my %options;
my $results = GetOptions( \%options,'input_side1|s1=s','input_side2|s2=s');

my ($input_side1,$input_side2);
($input_side1,$input_side2)=check_options( \%options );

open(SIDE1,inputWrapper($input_side1)) or die $!;
open(SIDE2,inputWrapper($input_side2)) or die $!;

my $input_side1_name=getFileName($input_side1);
my $input_side2_name=getFileName($input_side2);

open(OUT1,outputWrapper($input_side1_name.".fixed.gz"));
open(OUT2,outputWrapper($input_side2_name.".fixed.gz"));

my ($header1_1,$sequence1,$header1_2,$qv1,$header2_1,$sequence2,$header2_2,$qv2);

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
	
	# Exit if keys doesn`t match.
	if(($lineNum % 4) == 0) {
		# parsing it for key/side
	
		if($lineNum != 0) {
			
			#print "$lineNum ... VALID ($key1_1 vs $key2_1)\n" if(($lineNum % 1000000) == 0);
			
			my ($key1_1,$side1_1) =  split(/\//,$header1_1); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
			my ($key2_1,$side2_1) =  split(/\//,$header2_1); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2
			my ($key1_2,$side1_2) =  split(/\//,$header1_2); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
			my ($key2_2,$side2_2) =  split(/\//,$header2_2); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2
			
			if ( ($key1_1 ne $key2_1) 
				or ($key1_2 ne $key2_2)
				or (length($sequence1) != length($qv1)) 
				or (length($sequence2) != length($qv2)) ) {
				
				print "ERROR\n";
				print "$key1_1\t$key2_1\n";
				print "$key1_2\t$key2_2\n";
				print "$header1_1\t$header1_2\n";
				print "$header2_1\t$header2_2\n";
				print "$sequence1 (".length($sequence1).")\t$qv1 (".length($qv1).")\n";
				print "$sequence2 (".length($sequence2).")\t$qv2 (".length($qv2).")\n";
				print "\n";
				
			} else {
				print OUT1 "$header1_1\n$sequence1\n$header1_2\n$qv1\n";
				print OUT2 "$header2_1\n$sequence2\n$header2_2\n$qv2\n";
			}
		}
		
		$header1_1=$line1;
		$header2_1=$line2;
		
		$header1_1 .= "/1" if($header1_1 !~ /\/1$/);
		$header2_1 .= "/2" if($header2_1 !~ /\/2$/);
		
		while(($header1_1 !~ /^\@/) or ($header2_1 !~ /^\@/)) {
			print "\n$lineNum\n$line1/$header1_1 is invalid!!!\n";
			
			$line1 = <SIDE1>;
			$line2 = <SIDE2>;
			chomp ($line1);
			chomp ($line2);
			
			# Get the keys and work the hash of those keys. 
			$line1 = (split(/ /,$line1))[0];
			$line2 = (split(/ /,$line2))[0];
			
			$header1_1=$line1;
			$header2_1=$line2;
			
			$header1_1 .= "/1" if($header1_1 !~ /\/1$/);
			$header2_1 .= "/2" if($header2_1 !~ /\/2$/);
			print "$line1/$header1_1 is invalid!!!\n";
		}
		
	} elsif(($lineNum % 4) == 1) {
		$sequence1=$line1;
		$sequence2=$line2;
	} elsif(($lineNum % 4) == 2) {
		$header1_2=$line1;
		$header2_2=$line2;
		
		die("ERROR: header 1-2 $header1_2") if($header1_2 !~ /^\+/);
		die("ERROR: header 2-2 $header2_2") if($header2_2 !~ /^\+/);
		
	} elsif(($lineNum % 4) == 3) {
		$qv1=$line1;
		$qv2=$line2;
	}
	
	$lineNum++;
	
	
} 

$header1_1 .= "/1" if($header1_1 !~ /\/1$/);
$header2_1 .= "/2" if($header2_1 !~ /\/2$/);

my ($key1_1,$side1_1) =  split(/\//,$header1_1); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
my ($key2_1,$side2_1) =  split(/\//,$header2_1); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2
my ($key1_2,$side1_2) =  split(/\//,$header1_2); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/1
my ($key2_2,$side2_2) =  split(/\//,$header2_2); # Example: @HWUSI-EAS1533_0007:2:1:7:1420#0/2

if ( ($key1_1 ne $key2_1) 
	or ($key1_2 ne $key2_2)
	or (length($sequence1) != length($qv1)) 
	or (length($sequence2) != length($qv2)) ) {
	
	print "ERROR\n";
	print "$key1_1\t$key2_1\n";
	print "$key1_2\t$key2_2\n";
	print "$header1_1\t$header1_2\n";
	print "$header2_1\t$header2_2\n";
	print "$sequence1 (".length($sequence1).")\t$qv1 (".length($qv1).")\n";
	print "$sequence2 (".length($sequence2).")\t$qv2 (".length($qv2).")\n";
	print "\n";
} else {
	print OUT1 "$header1_1\n$sequence1\n$header1_2\n$qv1\n";
	print OUT2 "$header2_1\n$sequence2\n$header2_2\n$qv2\n";
}
		
close(SIDE1);
close(SIDE2);

close(OUT1);
close(OUT2);