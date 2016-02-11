use strict;

# input is 1 command line argument (output file)
open(OUT,">$ARGV[0]") or die $!;

my %cigarHash=();
# take input from STDIN (pipe)
while(my $line=<STDIN>){
	chomp($line);
	
	my @tmp=split(/\t/,$line);
	
	# ensure properly formatted read IDs
	# strip off everything except minimal readID, to ensure proper sorting later on
	my @ri=();
	@ri =split(/ /,$tmp[0]);
	$tmp[0]=$ri[0].":".$ri[1] if((@ri == 3) and ($ri[0] =~ /^\@SRR/));
	@ri =split(/ /,$tmp[0]);
	die("invalid FASTQ readIDs encountered!\n\t$tmp[0]\n") if(@ri > 2);
	
	$tmp[0] =~ s/#\/1//;
	$tmp[0] =~ s/\/1//;
	$tmp[0] =~ s/#\/2//;
	$tmp[0] =~ s/\/2//;
	$tmp[0] = (split(/ /,$tmp[0]))[0];
	$tmp[0] = (split(/\#/,$tmp[0]))[0];
	
	# extract out allele-override field 
	my $alleleOverride="";
	if($line =~ m/\tCW:AO:(.[^\t]*)/) {
		$alleleOverride="-".$1;
	}
	
	# XS signifies multi mapped read 0x4 signifies no matches
	if(($line =~ /XS:/) or ($line =~ /ZS:Z:R/)) {
		print OUT "MM\t$tmp[1]\t.\t.\t.\t$tmp[0]\t.\t.\t.\n";
	} elsif(($tmp[1]&0x4) or ($line =~ /ZS:Z:NM/)) { 
		print OUT "NM\t$tmp[1]\t.\t.\t.\t$tmp[0]\t.\t.\t.\n";
	} else {
		# if 0x10 is set -> reverse strand mapped
		# if reverse strand, then correct the readPos to the actual start (default is leftmost position)
		# need to extract CIGAR string, and then pull out the number of matched bases, CANNOT USE SEQ LENGTH
		# 31 match length | HWUSI-EAS1533_0053_FC:6:4:1428:5827#	16	  chrM	16268   3	   31M5S   *	   0	   0	   ATCATACTCTATTACGCAATAAACATTAACAAGTTA	dfccacfcfaf^cd^cfcff\fdffdfcafdfdfff	 PG:Z:novoalign  AS:i:64 UQ:i:64 NM:i:0  MD:Z:31
		# 36 match length | HWUSI-EAS1533_0053_FC:6:4:1428:5827#	0	   chr10-cast	  106130757	   60	  36M	 *	   0	   0	   TTCTTAAGTCGAATGAAAATGATTCTAATGATACCC	dffff^ddff_cfccfcfdafcfcffffdcfafafc	 ZQ:f:60.00	  PG:Z:novoalign  AS:i:0  UQ:i:0  NM:i:0  MD:Z:36
		
        $cigarHash{ M }=0;
        $cigarHash{ I }=0;
        $cigarHash{ D }=0;
        $cigarHash{ N }=0;
        $cigarHash{ S }=0;
        $cigarHash{ H }=0;
        $cigarHash{ P }=0;
        $cigarHash{"="}=0;
        $cigarHash{ X }=0;
        
		my $cigarString=$tmp[5];
		my @cigarValues=split(/(\d+[MIDNSHP=X])/,$cigarString);
		for(my $i=0;$i<@cigarValues;$i++) {
            my $cigarSubString=$cigarValues[$i];
            next if($cigarValues[$i] eq "");			
			my ($cigarScore,$cigarField)=split(/([MIDNSHP=X]{1})/,$cigarSubString);            
			$cigarHash{$cigarField}+=$cigarScore;
		}
        
        # Sum of lengths of the M/I/S/=/X operations shall equal the length of SEQ.
        # M/=/X/D/N
        my $readLength=$cigarHash{ M }+$cigarHash{ I }+$cigarHash{ S }+$cigarHash{"="}+$cigarHash{ X };
        my $alignmentLength=$cigarHash{ M }+$cigarHash{"="}+$cigarHash{ X }+$cigarHash{ D }+$cigarHash{ N };
        
		print "U".$alleleOverride."\t$tmp[1]\t",$tmp[2],"\t",$tmp[1]&0x10?(($tmp[3]+($alignmentLength-1)),"\t\-"):($tmp[3],"\t\+"),"\t",$tmp[0],"\n";
	}
}

close(OUT);
