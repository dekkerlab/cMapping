#!/usr/bin/perl -w

use warnings;
use strict;
use IO::Handle;
use POSIX qw(ceil floor);
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

## Checks the options to the program
sub check_options {
	my $opts = shift;

	my ($cDataDir,$readDir,$outputDir,$genomeName,$projectName,$hicMode,$fiveCMode,$experimentPrefix);
	
	if( $opts->{ cDataDir } ) {
		$cDataDir = $opts->{ cDataDir };
	} else {
		$cDataDir=$ENV{"HOME"}."/farline/HPCC/cshare/cData/";
	}
	
	if( $opts->{ readDir } ) {
		$readDir = $opts->{ readDir };
	} else {
		$readDir=$ENV{"HOME"}."/farline/HPCC/cshare/solexa/";
	}
	
	if( $opts->{ outputDir } ) {
		$outputDir = $opts->{ outputDir };
	} else {
		$outputDir=$ENV{"HOME"}."/scratch/";
	}
	
	if( $opts->{ genomeName } ) {
		$genomeName = $opts->{ genomeName };
	} else {
		die("Option genomeName|g is required.");
	}
	
	if( $opts->{ projectName } ) {
		$projectName = $opts->{ projectName };
	} else {
		$projectName="defaultProject";
	}
	
	if( defined($opts->{ hicMode }) ) {
		$hicMode = 1;
	} else {
		$hicMode=0;
	}
	
	if( defined($opts->{ fiveCMode }) ) {
		$fiveCMode = 1;
	} else {
		$fiveCMode=0;
	}
	
	if( defined($opts->{ experimentPrefix }) ) {
		$experimentPrefix = $opts->{ experimentPrefix };
	} else {
		$experimentPrefix="";
	}	
	
	return($cDataDir,$readDir,$outputDir,$genomeName,$projectName,$hicMode,$fiveCMode,$experimentPrefix);
}

sub storeMapping($$$) {
	my $mappingData={};
	$mappingData=shift;
	my $file=shift;
	my $flowCell=shift;
	
	my $nRenamed=0;
	my ($line);
	open(MAPPING,$file);
	while($line = <MAPPING>) {
		chomp($line);
		
		next if($line eq "");
		
		my ($origLaneName,$newLaneName)=split(/\t/,$line);
		
		my $laneKey=$flowCell."/".$origLaneName;
		$nRenamed++;
		
		$mappingData->{$laneKey}=$newLaneName;
		#print "\t$laneKey -> $newLaneName\n";
		
	}
	close(MAPPING);
	
	return($mappingData);
}	
	
sub findMappingFiles($$$$) {
	my $mappingData={};
	$mappingData=shift;
	my $cDataDir=shift;
	my $parentDir=shift;
	my $genomeName=shift;
	
	$parentDir .= "/" if($parentDir !~ /\/$/);
	
	opendir(my $dir, $parentDir) || die "can't opendir $parentDir: $!";
	
	for my $eachFile (readdir($dir)) {
		next if ($eachFile =~ /^..?$/);
		
		my $file = $parentDir .$eachFile;
		if( -d $file) {
			&findMappingFiles($mappingData,$cDataDir,$file,$genomeName);
		} else {
			my $strippedFilePath = $file;
			$strippedFilePath =~ s/$cDataDir//;
			my $flowCell = (split(/\//,$strippedFilePath))[0];
			
			next if(($flowCell eq "LIVE") or ($flowCell eq "FREEZES"));
			
			my $laneName = (split(/\//,$strippedFilePath))[1];
			
			if($laneName eq "mapping") {
				$mappingData=storeMapping($mappingData,$file,$flowCell);
				print "\t$file\n";
				next;
			}
			
		}
	}   
	
	return($mappingData);
}

sub findDataFiles($$$$$$$) {
	my $laneData={};
	$laneData=shift;
	my $mappingData={};
	$mappingData=shift;
	my $cDataDir=shift;
	my $parentDir=shift;
	my $genomeName=shift;
	my $hicMode=shift;
	my $fiveCMode=shift;
	
	$parentDir .= "/" if($parentDir !~ /\/$/);
	
	opendir(my $dir, $parentDir) || die "can't opendir $parentDir: $!";
	
	for my $eachFile (readdir($dir)) {
		next if ($eachFile =~ /^..?$/);
		
		my $file = $parentDir .$eachFile;
		if( -d $file) {
			&findDataFiles($laneData,$mappingData,$cDataDir,$file,$genomeName,$hicMode,$fiveCMode);
		} else {
			
			my $strippedFilePath = $file;
			$strippedFilePath =~ s/$cDataDir//;
			my $flowCell = (split(/\//,$strippedFilePath))[0];
			
			next if(($flowCell eq "LIVE") or ($flowCell eq "FREEZES"));
			
			my $laneName = (split(/\//,$strippedFilePath))[1];
			
			next if($laneName eq "mapping");
			
			my @tmp = split(/\//,$strippedFilePath);
			my $fileName = $tmp[@tmp-1];
			
			next if(($fileName !~ /.validPair.txt.gz$/) and ($fileName !~ /.interaction.gz$/));
			
			my $correctedLaneName="NA";
			
			# process hic mode
			if($hicMode == 1) {
			
				my @tmp2 = split(/__/,$fileName);
                my $flowCell2=$tmp2[0];
                my $laneName2=$tmp2[1];
                my @tmp3=split(/\./,$tmp2[2]);
                my $genome=$tmp3[0];

				next if($genome ne $genomeName);
				
				if($flowCell."__".$laneName ne $flowCell2."__".$laneName2) {
					print "error with file format...\n";
					print "[".$flowCell."__".$laneName."] vs [".$flowCell2."__".$laneName2."]\n";
					print "$fileName\n";
					print "$strippedFilePath\n";
					exit;
				}
				
				$correctedLaneName=(split(/_/,$laneName))[0];
				$correctedLaneName = (split(/\./,$correctedLaneName))[0];
				$correctedLaneName = $mappingData->{$flowCell."/".$laneName} if(exists($mappingData->{$flowCell."/".$laneName}));
				$correctedLaneName =~ s/\.//g;
				
				#print "\n";
				#print "file\t\t\t$file\n";
				#print "flowCell\t\t$flowCell\n";
				#print "laneName\t\t$laneName\n";
				#print "genome\t\t\t$genome\n";
				#print "correctedLaneName\t$correctedLaneName\n";
				#print "\n";
			} 
			
			#process 5C mode
			if($fiveCMode == 1) {
				my $laneName2 = (split(/__/,$fileName))[1];
				my $genomeSplit = (split(/__/,$fileName))[-1];
				my $genome=(split(/\./,$genomeSplit))[0];
				my $fileType = (split(/\./,$genomeSplit))[-2];
				
				next if($genome ne $genomeName);
				
				if($laneName ne $laneName2) {
					print "error with file format...\n";
					print "$laneName != $laneName2\n";
					print "$fileName\n";
					print "$strippedFilePath\n";
					exit;
				}
				
				$correctedLaneName=(split(/_/,$laneName))[0];
				$correctedLaneName = (split(/\./,$correctedLaneName))[0];
				$correctedLaneName = $mappingData->{$flowCell."/".$laneName} if(exists($mappingData->{$flowCell."/".$laneName}));
				$correctedLaneName =~ s/\.//g;
				
				#print "\n";
				#print "file\t\t\t$file\n";
				#print "flowCell\t\t$flowCell\n";
				#print "laneName\t\t$laneName\n";
				#print "genome\t\t\t$genome\n";
				#print "correctedLaneName\t$correctedLaneName\n";
				#print "\n";
				
			}
			
			#print "$correctedLaneName -> $file\n";
			push(@{$laneData->{$correctedLaneName}},$file)

		}
	}   
	
	return($laneData,$mappingData);
}

sub searchForFASTQ($$$$$$$) {
	my $fastqFiles=shift;
	my $dataDirectory=shift;
	$dataDirectory =~ s/\/$//;
	my $laneNum=shift;
	my $side1FastqFile=shift;
	my $side2FastqFile=shift;
	my $readLength=shift;
	my $zippedFlag=shift;
	
	opendir(BIN, $dataDirectory) or die "Can't open $dataDirectory: $!";
	my @fileNames = readdir BIN ;
	close(BIN);
	my $nFiles = @fileNames;
	
	for(my $i=0; $i<$nFiles; $i++) {
		my ($side1File,$side2File);
		
		my $dataFileName=$fileNames[$i];		
		
		next if ($dataFileName =~ /^\.\.?$/);
		
		if(-d $dataDirectory."/".$dataFileName) {
			
			&searchForFASTQ($fastqFiles,$dataDirectory."/".$dataFileName,$laneNum,$side1FastqFile,$side2FastqFile,$readLength,$zippedFlag) if(($dataFileName =~ /bustard/i) or ($dataFileName =~ /gerald/i));
			
		} else {
		
			next if(($dataFileName !~ /.fq$/) and ($dataFileName !~ /_sequence.txt/) and ($dataFileName !~ /.fastq$/) and ($dataFileName !~ /.fastq.gz$/));
			
			if($dataFileName =~ /\.gz$/) {
				
				my $fastqFile=$dataDirectory."/".$dataFileName;
				my $sampleLine = `zcat $fastqFile | head -n 2 | tail -n 1`;
				chomp($sampleLine);
				my $readLength = length($sampleLine);
				my @tmp=split(/_/,$dataFileName);
				foreach(@tmp) { $laneNum = $_ if($_ =~ /L[0-9]{3}/); }
				$laneNum =~ s/L00//;
				
				$dataFileName =~ s/_[0-9]{3}\.fastq\.gz/_\*\.fastq\.gz/;
				
				my $side="NA";
				$side=1 if($dataFileName =~ /_R1_/);
				$side=2 if($dataFileName =~ /_R2_/);
				
				$fastqFiles->{$side}->{"path"}=$dataDirectory."/".$dataFileName if(($side == 1) or ($side == 2));
				$fastqFiles->{$side}->{"readLength"}=$readLength if(($side == 1) or ($side == 2));
				$fastqFiles->{"laneNum"}=$laneNum;
				
				$zippedFlag=1;
				
			} else {
				
				my $fastqFile=$dataDirectory."/".$dataFileName;
				my $sampleLine = `head -n 2 $fastqFile | tail -n 1`;
				chomp($sampleLine);
				my $readLength = length($sampleLine);
				$laneNum=(split(/_/,$dataFileName))[1];
				
                my $side="NA";
                $side=1 if($dataFileName =~ /s_(.+)_1_sequence.txt/);
				$side=2 if($dataFileName =~ /s_(.+)_2_sequence.txt/);
                
				$fastqFiles->{$side}->{"path"}=$dataDirectory."/".$dataFileName if(($side == 1) or ($side == 2));
				$fastqFiles->{$side}->{"readLength"}=$readLength if(($side == 1) or ($side == 2));
				$fastqFiles->{"laneNum"}=$laneNum;
				
			}
			
		}
	}
	
	next if( (!exists($fastqFiles->{1})) or (!exists($fastqFiles->{2})) );
	
	$side1FastqFile=$fastqFiles->{1}->{"path"};
	my $side1ReadLength=$fastqFiles->{1}->{"readLength"};
	$side2FastqFile=$fastqFiles->{2}->{"path"};
	my $side2ReadLength=$fastqFiles->{2}->{"readLength"};
	$laneNum=$fastqFiles->{"laneNum"};
	
	print "\twarning - read lengths are not equal\n\t(side1 - $side1ReadLength | side2 - $side2ReadLength)!\n" if($side1ReadLength != $side2ReadLength);
	
	return($fastqFiles,$dataDirectory,$laneNum,$side1FastqFile,$side2FastqFile,$side1ReadLength,$zippedFlag);

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
my $results = GetOptions( \%options,'cDataDir|i=s','readDir|r=s','outputDir|o=s','genomeName|g=s','projectName|pn=s','hicMode|h','fiveCMode|f','experimentPrefix|ep=s');

my ($cDataDir,$readDir,$outputDir,$genomeName,$projectName,$hicMode,$fiveCMode,$experimentPrefix)=check_options( \%options );

print "\n";
print "cDataDir (-i)\t$cDataDir\n";
print "readDir (-i)\t$readDir\n";
print "outputDir (-o)\t$outputDir\n";
print "genomeName (-g)\t$genomeName\n";
print "projectName (-pn)\t$projectName\n";
print "experimentPrefix (-ep)\t$experimentPrefix\n";
print "\n";

die("ERROR - must choose either -f (5C) or -h (HiC) mode option\n\n") if( (($fiveCMode+$hicMode) <= 0) or (($fiveCMode+$hicMode) >= 2) );

$outputDir =~ s/\/$//;;
$outputDir .= "/".$projectName;
system("mkdir -p $outputDir");
print "outputDir\t$outputDir\n";

print "\n";
	
print "searching for mapping files...\n";
my $mappingData={};
($mappingData)=findMappingFiles($mappingData,$cDataDir,$cDataDir,$genomeName);
print "\tdone\n";

print "\n";
print "\nsearching for cData files...\n";
my $laneData={};
($laneData,$mappingData)=findDataFiles($laneData,$mappingData,$cDataDir,$cDataDir,$genomeName,$hicMode,$fiveCMode);

foreach my $sampleName ( keys %$laneData ) {
	
	print "\nsampleName: ".$sampleName."\n";
	print "\tskipping\n" if(($experimentPrefix ne "") and ($sampleName !~ /$experimentPrefix/));
	next if(($experimentPrefix ne "") and ($sampleName !~ /$experimentPrefix/));
	
	my @tmpArray=@{$laneData->{$sampleName}};
	my $arraySize=@tmpArray;
	
	for(my $i=0;$i<$arraySize;$i++) {
		my $cFile=$tmpArray[$i];
		my @tmp=split(/\//,$cFile);
		my $flowCell=$tmp[@tmp-3];
		my $laneName=$tmp[@tmp-2];

		print "\t$flowCell\t$laneName\n";
	}
	
	die("error with sample name ($sampleName) (cannot contain [.]) - exiting\n") if($sampleName =~ /\./);
	
	print "\n\tprocess? (y/n) [n]:\t";
	my $option = <>;
	chomp $option;
		
	if($option ne "y") {
		print "\tskipping...\n";
		next;
	} 
	
	print "\n";
	
	# now process all the files
	for(my $i=0;$i<$arraySize;$i++) {
		my $cFile=$tmpArray[$i];
		my @tmp=split(/\//,$cFile);
		my $flowCell=$tmp[@tmp-3];
		my $laneName=$tmp[@tmp-2];

		print "\t$flowCell\t$laneName\n";
		
		my $tmpfastqFiles={};
		my ($fastqFiles,$dataDirectory,$laneNum,$side1File,$side2File,$readLength,$zippedFlag)=&searchForFASTQ($tmpfastqFiles,$readDir.$flowCell."/".$laneName,0,"NA","NA",0,0);
		
		print "\t\t$laneName [$laneNum]\n";
		print "\t\t(1)\t$side1File\t$readLength\n";
		print "\t\t(2)\t$side2File\t$readLength\n";
		
		@tmp=();
		@tmp=split(/\//,$flowCell);
		my $flowCellName=$tmp[@tmp-1];
		
		my $workDirectory = $flowCell;
		$workDirectory =~ s/$flowCellName//;
		$workDirectory =~ s/\/$//;
		
		print "\n";
		
		my $side1FileName=$sampleName."_NoIndex_L00".$laneNum."_R1_001.fastq";
		my $side2FileName=$sampleName."_NoIndex_L00".$laneNum."_R2_001.fastq";
		
		my $outputFile_1=$outputDir."/".$sampleName."__".$flowCell."__".$laneName."__".$side1FileName;
		my $outputFile_2=$outputDir."/".$sampleName."__".$flowCell."__".$laneName."__".$side2FileName;
		
		my $tmpShell=$outputDir."/".$sampleName."__".$flowCell."__".$laneName.".sh";
		
		open(OUT,'>',$tmpShell) or die "$!";
		
		if($side1File =~ /\.gz$/) {
			print OUT "cat ".$side1File." > ".$outputFile_1.".gz\n";
		} else {
			print OUT "cat ".$side1File." > ".$outputFile_1."\n";
			print OUT "gzip ".$outputFile_1."\n";
		}
		
		if($side2File =~ /\.gz$/) {
			print OUT "cat ".$side2File." > ".$outputFile_2.".gz\n";
		} else {
			print OUT "cat ".$side2File." > ".$outputFile_2."\n";
			print OUT "gzip ".$outputFile_2."\n";
		}
		
		close(OUT);
		system("chmod 755 $tmpShell");
		
		system("bsub -q short -W 04:00 -N -u bryan.lajoie\@umassmed.edu -o /home/bl73w/lsf_jobs/LSB_%J.log -e /home/bl73w/lsf_jobs/LSB_%J.err $tmpShell 2> /dev/null");
	}
}