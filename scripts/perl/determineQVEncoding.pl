#bryan lajoie
#08/18/12

use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

=pod
 
Used to detect the format of a fastq file. In its current state,
it can only differentiate between sanger and solexa/illumina.
If need arises, checking for different versions of illumina formats
could easily be implemented. ( Please upload an update if you implement this )
 
Can easily be copy/pasted into any other script and altered to do other
things than die when it has determined the format.
 
Pseudo code
 
* Open the fastq file
* Look at each quality ASCII char and convert it to a number
* Depending on if that number is above or below certain thresholds,
  determine the format.
 SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS.....................................................
  ..........................XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX......................
  ...............................IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII......................
  .................................JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ......................
  LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL....................................................
  !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~
  |                         |    |        |                              |                     |
 33                        59   64       73                            104                   126

 S - Sanger        Phred+33,  raw reads typically (0, 40)
 X - Solexa        Solexa+64, raw reads typically (-5, 40)
 I - Illumina 1.3+ Phred+64,  raw reads typically (0, 40)
 J - Illumina 1.5+ Phred+64,  raw reads typically (3, 40)
    with 0=unused, 1=unused, 2=Read Segment Quality Control Indicator (bold) 
    (Note: See discussion above).
 L - Illumina 1.8+ Phred+33,  raw reads typically (0, 41)
 
=cut
 
sub check_options {
    my $opts = shift;

	my ($aligner,$inputFile);
	$aligner=$inputFile="";
	
    if( $opts->{'aligner'} ) {
        $aligner = $opts->{'aligner'};
    } else {
        die("Option aligner|aln is required.");
    }
	
	if( $opts->{'inputFile'} ) {
        $inputFile = $opts->{'inputFile'};
    } else {
        die("Option inputFile|i is required.");
    }
	
	return($aligner,$inputFile);
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
&GetOptions( \%options,'aligner|aln=s','inputFile|i=s');
my ($aligner,$inputFile) = &check_options( \%options );

# initiate
my @line;
my $l;
my $number;
 
my $phred="phred33";
$phred="STDFQ" if($aligner eq "novoalign");

exit if(!(-e($inputFile)));

# open the files
open(FQ,inputWrapper($inputFile)) or die $!;
my $lineNum=1;
while(my $line = <FQ>) {
	chomp($line);
	# if it is the line before the quality line
	if(($lineNum % 4) == 0) {
		#print "$line\t$phred\n";
		@line = split(//,$line); # divide in chars
		for(my $i = 0; $i <= $#line; $i++){ # for each char
			next if($line[$i] eq "");
			$number = ord($line[$i]); # get the number represented by the ascii char
			#print "\tl=$line[$i]\t$number\t$phred\n";
			# check if it is sanger or illumina/solexa, based on the ASCII image at http://en.wikipedia.org/wiki/FASTQ_format#Encoding
			if($number > 74) { # if solexa/illumina
				# phred64 - but keep checking to be sure
				$phred="phred64";
				$phred="ILMFQ" if($aligner eq "novoalign");
				print $phred;
				close(FQ);
				
				exit;
			} elsif($number < 59) { # if sanger
				$phred="phred33";
				$phred="STDFQ" if($aligner eq "novoalign");
				print $phred;
				close(FQ);
				
				exit;
			} else {
				# keep looking
			}
		}
	}
	$lineNum++;
}

print "$phred";
close(FQ);

exit;