#! /usr/bin/perl

use strict;
use warnings;
use Carp;
use File::Basename;
use POSIX;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

sub check_options {
    my $opts = shift;

    my ($inputFastaDir,$chromosomeOrderFile,$restrictionSite,$assembly);
    
    if( $opts->{'inputFastaDir'} ) {
        if(-d $opts->{'inputFastaDir'}) {
            $inputFastaDir = $opts->{'inputFastaDir'};
            $inputFastaDir =~ s/\/$//; # remove last / if there is any 
        } elsif(-f $opts->{'inputFastaDir'}){
            die("ERROR: $opts->{'inputFastaDir'} is a file and not a directory.\n");
        } else {
            die("ERROR: $opts->{'inputFastaDir'} does not exists.\n");
        }
    } else {
        die("ERROR: Option inputFastaDir(-i) is required.\n");
    }
    
    if( $opts->{ chromosomeOrderFile } ) {
        $chromosomeOrderFile = $opts->{ chromosomeOrderFile };
    } else {
        $chromosomeOrderFile = "";
    }

    if( $opts->{ restrictionSite } ) {
        $restrictionSite = uc($opts->{'restrictionSite'});
        die("ERROR: Restriction Site is not valid: ".$restrictionSite. "\nValid example: AAGCTT or ACAT\n") if $restrictionSite=~ /[^AGCT]/;
        die("ERROR: Restriction Site should be atleast a 4cutter. You have entered invalid restriction site: ".$restrictionSite. "\nValid example: AAGCTT or ACAT\n") if length($restrictionSite) < 4;
    } else {
         die("ERROR: Option restrictionSite(-r) is required.\nexample: AAGCTT or ACAT\n");
    }

    if( $opts->{'assembly'} ) {
        $assembly = lc($opts->{'assembly'});
    } else {
        $assembly = basename($inputFastaDir);
    }
    
    return($inputFastaDir,$chromosomeOrderFile,$restrictionSite,$assembly);
}

sub create_fragment($$$$) {
    my $inputFastaFile= shift;
    my $restrictionSite=shift;
    my $fragNumber=shift;
    my $assembly=shift;
    
    # $reslen  : the length of restriction site
    # Calculating the cut positiona and removing the split character from the RS.
    # **** We are assuming the cut position in the center ****
    # for even numbers: AAG-CTT, AC-TA
    # for odd number  : ATT-AC (rounded midpoint)
    my $reslen  = length($restrictionSite);
    my $cut_position = ceil($reslen/2);
    # print STDERR "cut_position=$cut_position\tRS=$restrictionSite\tsize=$reslen\n";

    # $buffer  : a buffer to hold the DNA from the input file
    # $position: the position of the buffer in the total DNA
    open(IN, $inputFastaFile) or  die "can not open file: $inputFastaFile $!";

    # The first line of a FASTA file is a header and begins with '>'
    my $header = <IN>;
    my $chrom;
    chomp $header;
    $header   =~ s/^\>//g;
    $chrom = $header; # assuming header is >chr1.. >chr2...
    
    # Get the first line of DNA data, to start the ball rolling
    my $position = 0;
    my $buffer = "";
    my $frag_start = 1;
    my $frag_end;
    my $seq ="";
    my $lineno=1;

    # The remaining lines are DNA data ending with newlines
    while(my $newline = <IN>) {
        # Add the new line to the buffer
        chomp($newline);
        
        next if(($newline =~ m/^\#/) or (($newline =~ m/^\"/))or ($newline eq "")or ($newline =~ /^\s*$/));

        if($lineno == 1) {
            $buffer .= $newline;
            $seq .= $buffer;
        } else {
            $seq .= substr($buffer,0, length($buffer)-$reslen) if length($buffer)-$reslen > 0;
            $seq .= $newline;
            $buffer .= $newline;
        }
        
        while($buffer =~ /$restrictionSite/gi) {
            # $-[0] is a special variable that gives the offset 
            # of the last successful pattern match in the string.
            my $rs_start = $position + $-[0] + $cut_position;
            $frag_end = $rs_start;
            my $seq_len=length($seq);
            $seq =~ /$restrictionSite/gi;

            my $frag_seq=substr($seq, 0,$-[0]+ $cut_position);
            my $remaining_seq=substr($seq,$-[0] + $cut_position, $seq_len);
            print "$-[0], $cut_position, $seq_len\n\n" if $-[0] > $seq_len;
            my $name = "HiC_".$restrictionSite."_".$fragNumber."|".$assembly."|".$chrom.":".$frag_start."-".$frag_end;

            print FRAGS "$chrom\t$frag_start\t$frag_end\t$name\t$fragNumber\n";

            $frag_start = $rs_start + 1;
            $seq = $remaining_seq;
            $fragNumber++;
                
        }
    
        # Reset the position counter (will be true after you reset the buffer, next)
        $position = $position + length($buffer) - $reslen + 1;
        
        # Discard the data in the buffer, except for a portion at the end
        # so patterns that appear across line breaks are not missed
        $buffer = substr($buffer, length($buffer) - $reslen + 1, $reslen - 1);
        $lineno++;
    }
    
    
    # for the last fragment
    $frag_end =  $frag_start + length($seq)-1;
    die("bad input fasta file! ($frag_start > $frag_end)!\n") if($frag_start >= $frag_end);
    
    my $name = "HiC_".$restrictionSite."_".$fragNumber."|".$assembly."|".$chrom.":".$frag_start."-".$frag_end;
    print FRAGS "$chrom\t$frag_start\t$frag_end\t$name\t$fragNumber\n";
    $fragNumber++;
    
    return($fragNumber);
}

sub round($;$) {
    # required
    my $num=shift;
    # optional
    my $digs_to_cut=0;
    $digs_to_cut = shift if @_;
    
    return($num) if($num eq "NA");
    
    my $roundedNum=$num;
    
    if(($num != 0) and ($digs_to_cut == 0)) {
        $roundedNum = int($num + $num/abs($num*2));
    } else {
        $roundedNum = sprintf("%.".($digs_to_cut)."f", $num) if($num =~ /\d+\.(\d){$digs_to_cut,}/);
    }
    
    return($roundedNum);
}

sub validate_output($) {
    my $inputFastaFile = shift;
    
    # chr1    1       3       HIC_frag_1|hg19|chr1:1-3        1
    # chr1    4       262     HIC_frag_2|hg19|chr1:4-262      2
    # chr1    263     400     HIC_frag_3|hg19|chr1:263-400    3
    # chr1    401     526     HIC_frag_4|hg19|chr1:401-526    4
    # chr1    527     529     HIC_frag_5|hg19|chr1:527-529    5
    # chr4    1       269     HIC_frag_6|hg19|chr4:1-269      6
    # chr4    270     5435    HIC_frag_7|hg19|chr4:270-5435   7
    # chr4    5436    7889    HIC_frag_8|hg19|chr4:5436-7889  8
    
    my $previous = 0;
    my $lineno = 0;
    open(IN, $inputFastaFile) or  die "can not open file: $inputFastaFile $!";
    while (my $line = <IN>){
        chomp($line); 
        next if(($line =~ m/^\#/) or (($line =~ m/^\"/))or ($line eq "")or ($line =~ /^\s*$/));
        my $fragno = (split(/\t/,$line))[4];
        die("ERROR: There is a gap between fragment numbers. Please check $inputFastaFile file for possible errors.\nError line: $line\nError lineno: $lineno\n") if $previous != $fragno;
        $previous++;
    }
    close IN;
}

sub getSpecialOrdering() {

    my %specialContigOrdering=();
    
    $specialContigOrdering{ contigCount } = 1000000;

    $specialContigOrdering{ I } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ II } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ III } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ IV } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ V } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ VI } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ VII } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ VIII } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ IX } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ X } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ XI } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ XII } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ XIII } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ XIV } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ XV } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ XVI } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ Y } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ W } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ Z } = $specialContigOrdering{ contigCount }++;
    $specialContigOrdering{ M } = $specialContigOrdering{ contigCount }++;

    return(\%specialContigOrdering);

}

sub chr2index($$) {
    my $chr=shift;
    my $specialContigOrdering=shift;
    
    my $chrIndex=-1;
    if(exists($specialContigOrdering->{$chr})) {
        $chrIndex=$specialContigOrdering->{$chr};
    } elsif($chr =~ m/^\d+$/) {
        $specialContigOrdering->{ $chr }=$chr;
        $chrIndex=$specialContigOrdering->{ $chr };
    } else { 
        $specialContigOrdering->{ $chr }=$specialContigOrdering->{ contigCount };
        $chrIndex=$specialContigOrdering->{ $chr };
    }
    
    die("error with chr2index!\n") if($chrIndex == -1);
    
    return($chrIndex);
}

sub loadChromosomeOrderFile($$) {
    my $file=shift;
    my $specialContigOrdering=shift;

    open(IN,$file);
    while(my $line = <IN>) {
        chomp($line);
        
        $line =~ s/>//;
        $line =~ s/chr//;
        $line =~ s/scaffold//;
        $line =~ s/contig//;
        
        $line =~ s/ //g; # remove any weird white space
        $line =~ s/\t/-/g; # remove any weird white space
        $line =~ s/'//g; # remove any quotes
        $line =~ s/"//g; # remove any quotes
        $line =~ s/^>//;
        $line = (split(/\|/,$line))[0];
        
        my $chr=$line;
        
        $specialContigOrdering->{ $chr } = $specialContigOrdering->{ contigCount }++;

    }
    close(IN);
    
    return($specialContigOrdering);

}
        
my %options;
my $results = GetOptions( \%options,'inputFastaDir|i=s','chromosomeOrderFile|cof=s','restrictionSite|r=s','assembly|a=s');
my ($inputFastaDir,$chromosomeOrderFile,$restrictionSite,$assembly)=check_options( \%options );

print "\n";
print "inputFastaDir\t$inputFastaDir\n";
print "chromosomeOrderFile\t$chromosomeOrderFile\n";
print "restrictionSite\t$restrictionSite\n";
print "assembly\t$assembly\n";
print "\n";

my $outputFragments = $assembly."__".$restrictionSite.".txt";

opendir(INDIR, $inputFastaDir) or die "Can't open $inputFastaDir: $!";
open(OUT,">".$outputFragments.".tmpHeaders");


my ($specialContigOrdering)=getSpecialOrdering();
($specialContigOrdering)=loadChromosomeOrderFile($chromosomeOrderFile,$specialContigOrdering) if(-e $chromosomeOrderFile);

# read files in sorted context
my @files = sort readdir(INDIR);
my $nFiles = @files;
my $pcComplete=0;
my %chrFiles=();

print "reading in all contigs\n";

my $fileIndex=0;
for(my $f=0;$f<$nFiles;$f++) {
    my $file=$files[$f];
    
    next if($file =~ /^\./);
    next if($file !~ /.fa$/);
        
    my $filePath=$inputFastaDir."/".$file;
    open(IN,$filePath);
    my $headerLine = <IN>;
    close(IN);
    
    chomp($headerLine);
    $headerLine =~ s/>//;
    $headerLine =~ s/chr//;
    $headerLine =~ s/scaffold//;
    $headerLine =~ s/contig//;
    
    $headerLine =~ s/ //g; # remove any weird white space
    $headerLine =~ s/\t/-/g; # remove any weird white space
    $headerLine =~ s/'//g; # remove any quotes
    $headerLine =~ s/"//g; # remove any quotes
    $headerLine =~ s/^>//;
    $headerLine = (split(/\|/,$headerLine))[0];

    my $extra="*";
    
    my $chr=$headerLine;
    
    my $chrIndex=chr2index($chr,$specialContigOrdering);
    
    print OUT "$chr\t$file\t$extra\t$chrIndex\n";

    print STDERR "\e[A" if($fileIndex != 0);
    printf STDERR "\t%.2f%% complete ($f/$nFiles)...\n", $pcComplete;
    $pcComplete = round((($fileIndex/$nFiles)*100),2);
    $fileIndex++;
        
}

close(INDIR);
close(OUT);

print "\n";

print "sorting chromosomes...";
system("sort -V -k3,3 -k4,4 ".$outputFragments.".tmpHeaders -o ".$outputFragments.".tmpHeaders");
print "\tdone\n";

my $fragNumber=0;

open (FRAGS, ">$outputFragments") or die "can not open file: $outputFragments $!";

open(TMPHEADERS,$outputFragments.".tmpHeaders");
while(my $line = <TMPHEADERS>) {
    chomp($line);
    
    my ($chromosome,$inputFastaFile,$extra,$contig)=split(/\t/,$line);
    
    print "\tprocessing $contig / $extra ($inputFastaFile) [$fragNumber]...\n";
    
    # check for number of headersll
    
    # generate error if file has more than one headers
    my $header_count = `grep -c ">" $inputFastaDir/$inputFastaFile`;
    die("ERROR: Input file $inputFastaDir/$inputFastaFile should contain only one fasta header. This file found $header_count headers headers.") if $header_count!=1;
    $fragNumber=create_fragment($inputFastaDir."/".$inputFastaFile,$restrictionSite,$fragNumber,$assembly);
}
close (FRAGS);

system("rm ".$outputFragments.".tmpHeaders");

# Validate the output file
&validate_output($outputFragments);

