use strict;

my $file=$ARGV[0];

my %contigs=();

my $init=0;
open(IN,$file);
while(my $line=<IN>) {
	chomp($line);
	
	if($line =~ /^>/) {
		my $fileName=$line;
		
		$fileName =~ s/ //g; # remove any weird white space
		$fileName =~ s/\t/-/g; # remove any weird white space
		$fileName =~ s/'//g; # remove any quotes
		$fileName =~ s/"//g; # remove any quotes
		$fileName =~ s/^>//;
		$fileName = (split(/\|/,$fileName))[0];
		
		die("ERROR - duplicate contig!") if(exists($contigs{$fileName}));
		$contigs{$fileName}=1;
		
		close(OUT) if($init != 0);
		print "opening $fileName.fa ...\n";
		open(OUT,">".$fileName.".fa");
		
		print OUT ">".$fileName;
		
		$init=1;
	} else {
		$line=uc($line);
		print OUT "\n$line";
	}
}
