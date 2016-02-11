#!/usr/bin/perl -w

use English;
use warnings;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use POSIX qw(ceil floor);

sub check_options {
	my $opts = shift;

	my ($restrictionFragmentFile,$minContigSize);
	
	if( exists($opts->{ restrictionFragmentFile }) ) {
		$restrictionFragmentFile = $opts->{ restrictionFragmentFile };
	} else {
		die("input restrictionFragmentFile|rff is required.\n");
	}
	
	if( exists($opts->{ minContigSize }) ) {
		$minContigSize = $opts->{ minContigSize };
	} else {
		$minContigSize = 100000;
	}
	
	return($restrictionFragmentFile,$minContigSize);

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

sub removeFileExtension($) {
    my $fileName=shift;
    
    my $extension=(split(/\./,$fileName))[-1];
    $fileName =~ s/\.$extension$//;
    
    return($fileName);
}  

my %options;
my $results = GetOptions( \%options,'restrictionFragmentFile|rff=s','minContigSize|mcs=f');
my ($restrictionFragmentFile,$minContigSize)=check_options( \%options );

die("File does not exist! ($restrictionFragmentFile)\n") if(!(-e($restrictionFragmentFile)));

my %contigs=();

open (IN,$restrictionFragmentFile) or die $!;
while(my $line = <IN>) {
	chomp($line);
	next if(($line =~ /^#/) or ($line eq ""));
	
	my @tmp=split(/\t/,$line);
	my $chr=$tmp[0];
	my $end=$tmp[2];
	
	$contigs{$chr}=$end;
	
}
close(IN);


my %subset_contigs=();
foreach my $chr (sort {$contigs{$b} <=> $contigs{$a}} keys %contigs)  {
	$subset_contigs{$chr}=1 if($contigs{$chr} > $minContigSize);
}

my $restrictionFragmentFileName=getFileName($restrictionFragmentFile);

open(OUT,">".$restrictionFragmentFileName."__".$minContigSize.".txt");

open (IN,$restrictionFragmentFile) or die $!;
while(my $line = <IN>) {
	chomp($line);
	next if(($line =~ /^#/) or ($line eq ""));
	
	my @tmp=split(/\t/,$line);
	my $chr=$tmp[0];
	my $end=$tmp[2];
	
	print OUT "$line\n" if(exists($subset_contigs{$chr}));
}
close(IN);

close(OUT);




