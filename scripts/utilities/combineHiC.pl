use 5.006;
use strict;
use warnings;
use Getopt::Long qw( :config posix_default bundling no_ignore_case ); 
use Carp qw(carp cluck croak confess);
use POSIX qw(ceil floor strftime);
use List::Util qw[min max];

use Cwd 'abs_path';
use Cwd;

my $tool=(split(/\//,abs_path($0)))[-1];
my $version = "1.0.3";

sub check_options {
    my $opts = shift;

    my $ret={};

    my ($cDataDirectory,$scratchDirectory,$outputDirectory,$genomeDirectory,$logDirectory,$userEmail,$genomeName,$customBinSize,$maxdim,$experimentPrefix,$debugModeFlag,$shortMode);
    
    if( defined($opts->{ cDataDirectory }) ) {
        $cDataDirectory = $opts->{ cDataDirectory };
        $cDataDirectory =~ s/\/$//;
        croak "cDataDirectory [".$cDataDirectory."] does not exist" if(!(-d $cDataDirectory));
    } else {
        print STDERR "\nERROR: Option inputCDataDirectory|i is required.\n";
        help();
    }
    
    if( defined($opts->{ scratchDirectory }) ) {
        $scratchDirectory = $opts->{ scratchDirectory };
        $scratchDirectory =~ s/\/$//;
        croak "scratchDirectory [".$scratchDirectory."] does not exist" if(!(-d $scratchDirectory));
    } else {
        print STDERR "\nERROR: Option scratchDirectory|s is required.\n";
        help();
    }
    
    if( defined($opts->{ outputDirectory }) ) {
        $outputDirectory = $opts->{ outputDirectory };
        $outputDirectory =~ s/\/$//;
        croak "outputDirectory [".$outputDirectory."] does not exist" if(!(-d $outputDirectory));
    } else {
        print STDERR "\nERROR: Option outputDirectory|o is required.\n";
        help();
    }
    
    if( defined($opts->{ genomeDirectory }) ) {
        $genomeDirectory = $opts->{ genomeDirectory };
        $genomeDirectory =~ s/\/$//;
        croak "genomeDirectory [".$genomeDirectory."] does not exist" if(!(-d $genomeDirectory));
    } else {
        print STDERR "\nERROR: Option genomeDirectory|gdir is required.\n";
        help();
    }
    
    if( defined($opts->{ logDirectory }) ) {
        $logDirectory = $opts->{ logDirectory };
        $logDirectory =~ s/\/$//;
        croak "logDirectory [".$logDirectory."] does not exist" if(!(-d $logDirectory));
    } else {
        $logDirectory=$outputDirectory."/cWorld-logs";
    }
    
    if( defined($opts->{ userEmail }) ) {
        $userEmail = $opts->{ userEmail };
    } else {
        $userEmail=&getUserEmail();
    }
    
    if( $opts->{ genomeName } ) {
        $genomeName = $opts->{ genomeName };
    } else {
        die("Option genomeName|g is required.");
    }
    
    if( defined($opts->{ customBinSize }) ) {
        $customBinSize = $opts->{ customBinSize };
    } else {
        $customBinSize="10000000,2500000,1000000,500000,250000,100000,40000";
    }
    
    if( defined($opts->{ maxdim }) ) {
        $maxdim = $opts->{ maxdim };
    } else {
        $maxdim=4000;
    }
   
    if( defined($opts->{ experimentPrefix }) ) {
        $experimentPrefix = $opts->{ experimentPrefix };
    } else {
        $experimentPrefix="";
    }    
    
    if( $opts->{ debugModeFlag } ) {
        $debugModeFlag=1;
    } else {
        $debugModeFlag=0;
    }

    if( defined($opts->{ shortMode }) ) {
        $shortMode=1;
    } else {
        $shortMode=0;
    }
    
    $ret->{ cDataDirectory }=$cDataDirectory;
    $ret->{ scratchDirectory }=$scratchDirectory;
    $ret->{ outputDirectory }=$outputDirectory;
    $ret->{ genomeDirectory }=$genomeDirectory;
    $ret->{ logDirectory }=$logDirectory;
    $ret->{ userEmail }=$userEmail;
    $ret->{ genomeName }=$genomeName;
    $ret->{ customBinSize }=$customBinSize;
    $ret->{ maxdim }=$maxdim;
    $ret->{ experimentPrefix }=$experimentPrefix;
    $ret->{ debugModeFlag }=$debugModeFlag;
    $ret->{ shortMode }=$shortMode;

    return($cDataDirectory,$scratchDirectory,$outputDirectory,$genomeDirectory,$logDirectory,$userEmail,$genomeName,$customBinSize,$maxdim,$experimentPrefix,$debugModeFlag,$shortMode);
}


sub getRestrictionEnzymeSequences() {
    my %restrictionEnzymeSequences=();
    
    $restrictionEnzymeSequences{ HindIII } = "AAGCTT";
    $restrictionEnzymeSequences{ EcoRI } = "GAATTC";
    $restrictionEnzymeSequences{ NcoI } = "CCATGG";
    $restrictionEnzymeSequences{ DpnII } = "GATC";
    $restrictionEnzymeSequences{ MNase } = "MNase";
    
    return(\%restrictionEnzymeSequences);
}

sub getUserEmail() {
    
    # hb67w:x:10839:1081:Houda Belaghzal [Houda.belaghzal@umassmed.edu]:/home/hb67w:/bin/bash
    my $user_info=`grep \$USER /etc/passwd`;
    chomp($user_info);
    
    my @tmp=split(/:/,$user_info);
    my $user_email=$tmp[4];
    $user_email=(split(/\[/,$user_email))[1];
    $user_email =~ s/\]//;
    
    $user_email = "" if($user_email !~ /\@/);
    
    return($user_email);
}

sub getUserHomeDirectory() {
    my $userHomeDirectory = `echo \$HOME`;
    chomp($userHomeDirectory);
    return($userHomeDirectory);
}

sub getUniqueString() {
    my $UUID = `uuidgen`;
    chomp($UUID);
    return($UUID);
}

sub getSmallUniqueString() {
    my $UUID=`uuidgen | rev | cut -d '-' -f 1`;
    chomp($UUID);
    return($UUID);
}

sub getComputeResource() {
    my $hostname = `hostname`;
    chomp($hostname);
    return($hostname);
}

sub translateFlag($) {
    my $flag=shift;
    
    my $response="no";
    $response="yes" if($flag);    
    return($response);
}

sub check_dependency($;$) {
    # required
    my $command=shift;
    # optional
    my $weblink=shift;
    
    my $repo=(split(/\//,$command))[-3];
    
    confess "missing dependency [$repo] - $command.\n\tPlease install\n\t$weblink\n\n" if(!-e($command));
    
    return($command);
    
}

sub which($;$) {
    # required
    my $command=shift;
    # optional
    my $die=1;
    $die=shift if @_;
    
    my $path="";
    $path=`which $command 2>&1`;
    chomp($path);
    
    confess "no path for $command" if(($path =~ /which: no/) and ($die == 1));
        
    return($path);
}

sub getDate() {
    my $time = strftime '%I:%M:%S %P, %m/%d/%Y', localtime;
    
    return($time);
}

sub commify {
   (my $num = shift) =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g; 
   return $num; 
}

#

sub readConfigFile($) {
    my $configFile=shift;
    
    my %log=();
    
    # get config log info
    open(IN,$configFile);
    while(my $line = <IN>) {
        chomp($line);
        next if($line =~ /^#/);
        next if($line eq "");
        
        my ($field,$value)=split(/=/,$line);
        $value =~ s/"//g;

        $log{$field}=$value;
    }
    close(IN);
    
    return(\%log);
}
       
sub getGenomePath($$$) {
    my $genomeDirectory=shift;
    my $genomeName=shift;
    my $restrictionSite=shift;
        
    my $fastaDirectory=$genomeDirectory."/fasta/".$genomeName;
    my $restrictionFragmentFile=$genomeDirectory."/restrictionFragments/".$genomeName."/".$genomeName."__".$restrictionSite.".txt";
    
    die("invalid fasta directory ($fastaDirectory)\n") if(!(-d($fastaDirectory)));
    die("invalid restriction fragment file ($restrictionFragmentFile)\n") if(!(-e($restrictionFragmentFile)));
    
    return($fastaDirectory,$restrictionFragmentFile);
}

sub getDefaultOutputFolder($) {
    my $outputFolder=shift;
    
    my $userHomeDirectory = getUserHomeDirectory();
    
    $outputFolder=$userHomeDirectory."/scratch/hicData" if($outputFolder eq "");
    croak "scratch dir [".$outputFolder."] does not exist" if(!(-d $outputFolder));
    
    return($outputFolder);
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
        
    }
    close(MAPPING);
    
    return($mappingData);
}    
    
sub findMappingFiles($$$$) {
    my $mappingData={};
    $mappingData=shift;
    my $cDataDirectory=shift;
    my $parentDir=shift;
    my $genomeName=shift;
    
    $parentDir .= "/" if($parentDir !~ /\/$/);
    
    opendir(my $dir, $parentDir) || die "can't opendir $parentDir: $!";
    
    for my $eachFile (readdir($dir)) {
        next if ($eachFile =~ /^..?$/);
        
        my $file = $parentDir .$eachFile;
        if( -d $file) {
            &findMappingFiles($mappingData,$cDataDirectory,$file,$genomeName);
        } else {
            my $strippedFilePath = $file;
            $strippedFilePath =~ s/$cDataDirectory\///;
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

sub findDataFiles($$$$$$) {
    my $laneData={};
    $laneData=shift;
    my $mappingData={};
    $mappingData=shift;
    my $cDataDirectory=shift;
    my $parentDir=shift;
    my $genomeName=shift;
    my $restrictionFragmentPath=shift;
    
    $parentDir .= "/" if($parentDir !~ /\/$/);
    
    opendir(my $dir, $parentDir) || die "can't opendir $parentDir: $!";
    
    for my $eachFile (readdir($dir)) {
        next if ($eachFile =~ /^..?$/);
        
        my $file = $parentDir .$eachFile;
        if( -d $file) {
            &findDataFiles($laneData,$mappingData,$cDataDirectory,$file,$genomeName,$restrictionFragmentPath);
        } else {
            my $strippedFilePath = $file;
            $strippedFilePath =~ s/$cDataDirectory\///;
            my $flowCell = (split(/\//,$strippedFilePath))[0];
            my $laneName = (split(/\//,$strippedFilePath))[1];
            
            next if($laneName eq "mapping");
            
            my @tmp = split(/\//,$strippedFilePath);
            my $fileName = $tmp[@tmp-1];
            
            next if($fileName !~ /.validPair.txt.gz$/);
            
            my $laneName2 = (split(/__/,$fileName))[2];
            my @tmp2 = split(/\./,$laneName2);
            my $genome = $tmp2[0];
            my $fileType = $tmp2[1];
            my $fileExtension = $tmp2[-1];
            
            next if($genome ne $genomeName);
            
            if($flowCell."__".$laneName."__".$genome.".validPair.txt.gz" ne $fileName) {
                print "\n";
                print "error with file format\n\t[$cDataDirectory]\n\t[$file]\n\t[$strippedFilePath]\n\t\tflowCell=$flowCell\n\t\tlaneName=$laneName\n\t\tgenome=$genome\n";
                print "\t".$fileName."\n";
                print "\t".$flowCell."__".$laneName."__".$genome.".validPair.txt.gz\n";
                print "\n";
                exit;
            }
            
            my $configFileName=$flowCell."__".$laneName."__".$genome.".cfg";
            my $configFilePath=$parentDir.$configFileName;
            die("Config file does not exist! ($configFileName)\n") if(!(-e($configFilePath)));
            
            my $log=readConfigFile($configFilePath);
            my $configRestrictionFragmentPath="NA";
            $configRestrictionFragmentPath=$log->{ restrictionFragmentPath };
                        
            next if( (split(/\//,$restrictionFragmentPath))[-1] ne (split(/\//,$configRestrictionFragmentPath))[-1] );
            
            my $correctedLaneName=$laneName;
            $correctedLaneName =~ s/^Sample_//;
            $correctedLaneName=(split(/_/,$correctedLaneName))[0];
            $correctedLaneName = (split(/\./,$correctedLaneName))[0];
            $correctedLaneName = $mappingData->{$flowCell."/".$laneName} if(exists($mappingData->{$flowCell."/".$laneName}));
            $correctedLaneName =~ s/\.//g;
            
            push(@{$laneData->{$correctedLaneName}->{$fileType}},$file);

        }
    }   
    
    return($laneData,$mappingData);
}

sub processCustomBinSize($) {
    my $customBinSize=shift;
    
    my $binSizes="NA";
    my $binLabels="NA";

    if($customBinSize eq "") {
        print "\t[C]\tnone\n";
        return($binSizes,$binLabels) if($customBinSize eq "");
    }
    
    my $binLabel="C";
    my @tmp=split(/,/,$customBinSize);
    for(my $i=0;$i<@tmp;$i++) {
        my $binSize=$tmp[$i];
        print "\t[C]\t".commify($binSize)."\n";
        
        $binSizes=$binSizes.",".$binSize if($binSizes ne "NA");
        $binSizes=$binSize if($binSizes eq "NA");
        
        $binLabels=$binLabels.",".$binLabel if($binLabels ne "NA");
        $binLabels=$binLabel if($binLabels eq "NA");
    }
    
    return($binSizes,$binLabels);
}
    
sub logConfigVariable($$$) {
    my $configFileVariables=shift;
    my $configVariableName=shift;
    my $configVariableValue=shift;
    
    $configFileVariables->{$configVariableName}=$configVariableValue;
    
    return($configFileVariables);
}

sub printConfigFile($$$) {
    my $configFileVariables=shift;
    my $tmpConfigFileVariables=shift;
    my $configFileName=shift;
    
    open(OUT,">".$configFileName);
    
    my $time=getDate();
    my $userHomeDirectory=getUserHomeDirectory();
    
    print OUT "# cWorld combineHiC\n";
    print OUT "# my5C.umassmed.edu\n";
    print OUT "# $time\n";
    print OUT "# $userHomeDirectory\n";
    print OUT "# ".$configFileVariables->{ computeResource}."\n";
    print OUT "# initial variables\n";
    
    for my $variableName ( sort {$a cmp $b} keys %{$configFileVariables}) {
        my $variableValue=$configFileVariables->{$variableName};
        print OUT $variableName."="."\"$variableValue\"\n";
    }
    
    for my $variableName ( sort {$a cmp $b} keys %{$tmpConfigFileVariables}) {
        my $variableValue=$tmpConfigFileVariables->{$variableName};
        print OUT $variableName."="."\"$variableValue\"\n";
    }
    
    print OUT "# dynamic variables\n";
    
    close(OUT);
}

sub getBinModes($$) {
    my $tmpBinSizes=shift;
    my $tmpBinLabels=shift;
    
    my @tmpBinSizesArr=split(/,/,$tmpBinSizes);
    my @tmpBinLabelsArr=split(/,/,$tmpBinLabels);
    
    my $nTmpBinSizes=@tmpBinSizesArr;
    my $nTmpBinLabels=@tmpBinLabelsArr;
    die("ERROR - mismatch between binSizes and binLabels! ($nTmpBinSizes vs $nTmpBinLabels)\n") if($nTmpBinSizes != $nTmpBinLabels);
    
    my $nTmpBins=$nTmpBinSizes=$nTmpBinLabels;
    
    my @binSizesArr=();
    my @binLabelsArr=();
    my @binModesArr=();
    
    for(my $i=0;$i<$nTmpBins;$i++) {
        my $binSize=$tmpBinSizesArr[$i];
        my $binLabel=$tmpBinLabelsArr[$i];
        
        print "\t\t[$binLabel]\t".commify($binSize)."\t ice mode [genome] (remove,genome,chr): ";
        my $binMode="genome";
        my $userBinMode=<STDIN>;        
        chomp($userBinMode);
        $binMode=$userBinMode if(($userBinMode ne "") and (($userBinMode eq "genome") or ($userBinMode eq "chr") or ($userBinMode eq "remove")));
        print "\t\t\t$binMode\n";
        
        next if($binMode eq "remove");
        
        push(@binSizesArr,$binSize);
        push(@binLabelsArr,$binLabel);
        push(@binModesArr,$binMode);

    }
    
    my $binSizes=join(",", @binSizesArr); 
    my $binLabels=join(",", @binLabelsArr); 
    my $binModes=join(",", @binModesArr); 

    return($binSizes,$binLabels,$binModes);
}

sub intro() {
    print STDERR "\n";
    
    print STDERR "Tool:\t\t".$tool."\n";
    print STDERR "Version:\t".$version."\n";
    print STDERR "Summary:\tcMapping pipeline - stage 2 [Hi-C]\n";
    
    print STDERR "\n";
}

sub help() {
    intro();
    
    print STDERR "Usage: perl combineHiC.pl [OPTIONS] -i <inputCDataDirectory> -o <outputDirectory> --gdir <genomeDirectory>\n";
    
    print STDERR "\n";
    
    print STDERR "Required:\n";
    printf STDERR ("\t%-10s %-10s %-10s\n", "-i", "[]", "cData directory(path)");
    printf STDERR ("\t%-10s %-10s %-10s\n", "-s", "[]", "scratch directory (path)");
    printf STDERR ("\t%-10s %-10s %-10s\n", "-o", "[]", "output directory (path)");
    printf STDERR ("\t%-10s %-10s %-10s\n", "--gdir", "[]", "genome directory (fasta,index,restrictionSite)");
    printf STDERR ("\t%-10s %-10s %-10s\n", "-g", "[]", "genomeName, genome to align");
    
    print STDERR "\n";
    
    print STDERR "Options:\n";
    printf STDERR ("\t%-10s %-10s %-10s\n", "-v", "[]", "FLAG, verbose mode");
    printf STDERR ("\t%-10s %-10s %-10s\n", "--log", "[]", "log directory");
    printf STDERR ("\t%-10s %-10s %-10s\n", "--email", "[]", "user email address");
    printf STDERR ("\t%-10s %-10s %-10s\n", "-d", "[]", "FLAg, debugMode - keep all files for debug purposes");
    printf STDERR ("\t%-10s %-10s %-10s\n", "--short", "[]", "FLAG, use the short queue");
    
    print STDERR "\n";
    
    print STDERR "Notes:";
    print STDERR "
    Stage 2 of the cMapping pipeline, for processing 5C/Hi-C data [UMMS specific].\n";
    
    print STDERR "\n";
    
    print STDERR "Contact:
    Bryan R. Lajoie
    Dekker Lab 2016
    https://github.com/blajoie/cMapping
    https://github.com/blajoie/cWorld-dekker
    http://my5C.umassmed.edu";
    
    print STDERR "\n";
    print STDERR "\n";
    
    exit;
}

my %options;
my $results = GetOptions( \%options,'cDataDirectory|i=s','scratchDirectory|s=s','outputDirectory|o=s','genomeDirectory|gdir=s','logDirectory|log=s','userEmail|email=s','genomeName|g=s','maxdim|m=s','customBinSize|C=s','experimentPrefix|ep=s','debugModeFlag|d','shortMode|short') or croak help();
my ($cDataDirectory,$scratchDirectory,$outputDirectory,$genomeDirectory,$logDirectory,$userEmail,$genomeName,$customBinSize,$maxdim,$experimentPrefix,$debugModeFlag,$shortMode)=check_options( \%options );

intro();

my $cwd = getcwd();
my $fullScriptPath=abs_path($0);
my @fullScriptPathArr=split(/\//,$fullScriptPath);
my @scriptDir=@fullScriptPathArr[0..@fullScriptPathArr-3];
my $scriptPath=join("/",@scriptDir);
my @gitDir=@fullScriptPathArr[0..@fullScriptPathArr-5];
my $gitPath=join("/",@gitDir);

my $configFileVariables={};
my $userHomeDirectory = getUserHomeDirectory();
my $cMapping = $scriptPath;

# log environment information
$configFileVariables=logConfigVariable($configFileVariables,"cDataDirectory",$cDataDirectory);
$configFileVariables=logConfigVariable($configFileVariables,"genomeName",$genomeName);
$configFileVariables=logConfigVariable($configFileVariables,"cMapping",$cMapping);
$configFileVariables=logConfigVariable($configFileVariables,"gitDir",$gitPath);
$configFileVariables=logConfigVariable($configFileVariables,"customBinSize",$customBinSize);
$configFileVariables=logConfigVariable($configFileVariables,"debugModeFlag",$debugModeFlag);
$configFileVariables=logConfigVariable($configFileVariables,"maxdim",$maxdim);

# check git repo dependencies
my $hdf2tab_path=check_dependency($gitPath."/hdf2tab/scripts/hdf2tab.py","https://github.com/blajoie/hdf2tab");
my $balance_path=check_dependency($gitPath."/balance/scripts/balance.py","https://github.com/blajoie/balance");
my $tab2hdf_path=check_dependency($gitPath."/tab2hdf/scripts/tab2hdf.py","https://github.com/blajoie/tab2hdf");
$configFileVariables=logConfigVariable($configFileVariables,"hdf2tab_path",$hdf2tab_path);
$configFileVariables=logConfigVariable($configFileVariables,"tab2hdf_path",$tab2hdf_path);
$configFileVariables=logConfigVariable($configFileVariables,"balance_path",$balance_path);

# log compute resource
my $computeResource = getComputeResource();
$configFileVariables=logConfigVariable($configFileVariables,"computeResource",$computeResource);

# setup scratch space
my $reduceScratchDir=$scratchDirectory;
my $mapScratchDir="/tmp";
$mapScratchDir=$scratchDirectory if($debugModeFlag == 1);

$shortMode=1 if($debugModeFlag == 1);

# setup queue/timelimit for LSF
my $combineQueue="long";
$combineQueue="short" if($shortMode == 1);
my $combineTimeNeeded="36:00";
$combineTimeNeeded="04:00" if($shortMode == 1);
my $combineMemoryNeeded=8192;

# enzyme choice 
my $restrictionEnzymeSequences=getRestrictionEnzymeSequences();
my $enzymeString=join(',', (keys %{$restrictionEnzymeSequences}));

my ($enzyme,$restrictionSite);
$enzyme="HindIII";
print "enzyme (".$enzymeString.") [".$enzyme."] : ";
my $userEnzyme = <STDIN>;
chomp($userEnzyme);
$enzyme=$userEnzyme if($userEnzyme ne "");
die("Invalid Restriction Enzyme! ($enzyme)\n") if(!(exists($restrictionEnzymeSequences->{ $enzyme })));
$restrictionSite=$restrictionEnzymeSequences->{ $enzyme };
print "\t$enzyme / $restrictionSite\n";
$configFileVariables=logConfigVariable($configFileVariables,"enzyme",$enzyme);
$configFileVariables=logConfigVariable($configFileVariables,"restrictionSite",$restrictionSite);

my ($fastaPath,$restrictionFragmentPath)=getGenomePath($genomeDirectory,$genomeName,$restrictionSite);
$configFileVariables=logConfigVariable($configFileVariables,"fastaPath",$fastaPath);

print "\nrestrictionFragmentPath [$restrictionFragmentPath]: ";
my $userRestrictionFragmentPath = <STDIN>;
chomp($userRestrictionFragmentPath);
$userRestrictionFragmentPath = "" if(!(-e($userRestrictionFragmentPath)));
$restrictionFragmentPath = $userRestrictionFragmentPath if($userRestrictionFragmentPath ne "");
die("invalid restriction fragment file path!\n") if(!(-e($restrictionFragmentPath)));
print "\t$restrictionFragmentPath\n";

print "\nsearching for mapping files...\n";
my $mappingData={};
($mappingData)=findMappingFiles($mappingData,$cDataDirectory,$cDataDirectory,$genomeName);
print "\tdone.\n";

$configFileVariables=logConfigVariable($configFileVariables,"fastaDir",$fastaPath);

print "\nprocessing custom bin sizes...\n";
my ($binSizes,$binLabels)=processCustomBinSize($customBinSize);

print "\nsearching for cData files [$cDataDirectory] ...\n";
my $laneData={};
($laneData,$mappingData)=findDataFiles($laneData,$mappingData,$cDataDirectory,$cDataDirectory,$genomeName,$restrictionFragmentPath);

foreach my $sampleName ( keys %$laneData ) {
    
    my $tmpConfigFileVariables={};
    
    print "\nsampleName: ".$sampleName."\n";
    print "\tskipping\n" if(($experimentPrefix ne "") and ($sampleName !~ /$experimentPrefix/));
    next if(($experimentPrefix ne "") and ($sampleName !~ /$experimentPrefix/));
    
    my @tmpArray=@{$laneData->{$sampleName}->{ validPair }};
    my $arraySize=@tmpArray;
    
    my $totalFileSizeMegabyte=0;
    for(my $i=0;$i<$arraySize;$i++) {
        my $cFile=$tmpArray[$i];
        my @tmp=split(/\//,$cFile);
        my $flowCell=$tmp[@tmp-3];
        my $laneName=$tmp[@tmp-2];

        my $fileSize=`du -b $cFile`;
        chomp($fileSize);
        $fileSize=(split(/\t/,$fileSize))[0];
        my $fileSizeMegabyte = ceil($fileSize / 1000000);
        $totalFileSizeMegabyte += $fileSizeMegabyte;
        print "\t(".commify($fileSizeMegabyte)."M)\t$flowCell\t$laneName\n";
    }
    
    die("error with sample name ($sampleName) (cannot contain [.]) - exiting\n") if($sampleName =~ /\./);
    
    print "\n\tprocess? (".commify($totalFileSizeMegabyte)."M) (y/n) [n]:\t";
    my $option = <>;
    chomp $option;
        
    if($option ne "y") {
        print "\tskipping...\n";
        next;
    } 

    print "\n\trestrictionFragmentPath [$restrictionFragmentPath]: ";
    my $userRestrictionFragmentPath = <STDIN>;
    chomp($userRestrictionFragmentPath);
    $userRestrictionFragmentPath = "" if(!(-e($userRestrictionFragmentPath)));
    $restrictionFragmentPath = $userRestrictionFragmentPath if($userRestrictionFragmentPath ne "");
    die("invalid restriction fragment file path!\n") if(!(-e($restrictionFragmentPath)));
    print "\t\t$restrictionFragmentPath\n";
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"restrictionFragmentPath",$restrictionFragmentPath);
    
    $configFileVariables=logConfigVariable($configFileVariables,"combineQueue",$combineQueue);
    $configFileVariables=logConfigVariable($configFileVariables,"combineTimeNeeded",$combineTimeNeeded);
    $configFileVariables=logConfigVariable($configFileVariables,"combineMemoryNeeded",$combineMemoryNeeded);

    print "\n";
    
    # get the mode for each resolution - cis/genome
    my $binModes="";
    ($binSizes,$binLabels,$binModes)=getBinModes($binSizes,$binLabels);
    print "\n";
    print "\t\tbinSizes\t$binSizes\n";
    print "\t\tbinLabels\t$binLabels\n";
    print "\t\tbinModes\t$binModes\n";
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"binSizes",$binSizes);
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"binLabels",$binLabels);
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"binModes",$binModes);
    
    print "\n\tignoreDiagonal [0] :\t";
    my $userIgnoreDiagonal = <STDIN>;
    chomp($userIgnoreDiagonal);
    my $ignoreDiagonal = 0;
    $ignoreDiagonal = $userIgnoreDiagonal if(($userIgnoreDiagonal =~ (/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/)) and ($userIgnoreDiagonal > 0));
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"ignoreDiagonal",$ignoreDiagonal);
    print "\t\t$ignoreDiagonal\n";
    
    print "\n\tsameStrandOnly [n] :\t";
    my $userSameStrand = <STDIN>;
    chomp($userSameStrand);
    my $sameStrand = "n";
    $sameStrand = $userSameStrand if($userSameStrand eq "y");
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"sameStrand",$sameStrand);
    print "\t\t$sameStrand\n";
    
    print "\n";
    
    my ($outputFolder)=getDefaultOutputFolder($outputDirectory);
    my $userOutputFolder = "";    
    print "\toutputFolder [$outputFolder] :\t";
    $userOutputFolder = <STDIN>;
    chomp($userOutputFolder);
    $outputFolder = $userOutputFolder if($userOutputFolder ne "");
    $outputFolder .= "/" if($outputFolder !~ /\/$/);
    $outputFolder = $userHomeDirectory."/".$outputFolder if($outputFolder !~ /^\//);
    system("mkdir -p $outputFolder") if(!(-d $outputFolder));
    die("warning - cannot use specified outputFolder ($outputFolder)\n") if(!(-d $outputFolder));
    print "\t\t$outputFolder\n";
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"outputFolder",$outputFolder);
    
    print "\n";
    
    print "\treduceScratchDir [$reduceScratchDir]\n";
    print "\tmapScratchDir [$mapScratchDir] :\t";
    my $userScratchDir = <STDIN>;
    chomp($userScratchDir);
    $mapScratchDir = $userScratchDir if($userScratchDir ne "");
    $mapScratchDir =~ s/\/$// if($mapScratchDir =~ /\/$/); # remove trailing / 
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"mapScratchDir",$mapScratchDir);
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"reduceScratchDir",$reduceScratchDir);
    print "\t\t$mapScratchDir\n";
    
    print "\n";
    
    print "\tlogDirectory [$logDirectory]: ";
    my $userLogDirectory = <STDIN>;
    chomp($userLogDirectory);
    $userLogDirectory =~ s/\/$//;
    $logDirectory=$userLogDirectory if(-d($userLogDirectory));
    print "\t\t\t$logDirectory\n";
    system("mkdir -p $logDirectory") if(!(-d $logDirectory));
    croak "invalid log directory [$logDirectory]\n" if(!(-d($logDirectory)));
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"logDirectory",$logDirectory);
    
    my $UUID=getUniqueString();
    my $configFilePath=$logDirectory."/".$UUID.".cWorld-stage2.cfg";
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"UUID",$UUID);
    print "\t\t$configFilePath\n";
    my $reduceID=getSmallUniqueString();
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"reduceID",$reduceID);
    
    print "\n";    
    
    my $jobName=$sampleName."__".$genomeName;
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"jobName",$jobName);
    
    print "\tprocessing ($jobName)...\n";
        
    my $cFileString="";
    for(my $i=0;$i<$arraySize;$i++) {
        my $cFile=$tmpArray[$i];
        $cFileString .= "," . $cFile if($cFileString ne "");
        $cFileString = $cFile if($cFileString eq "");
    }
    $tmpConfigFileVariables=logConfigVariable($tmpConfigFileVariables,"inputFileString",$cFileString);
    
    printConfigFile($configFileVariables,$tmpConfigFileVariables,$configFilePath);
    
    print "\n";
    print "\tsubmitting map HiC ($combineMemoryNeeded)...\n";
    my $return=`bsub -n 2 -q $combineQueue -R span[hosts=1] -R rusage[mem=$combineMemoryNeeded] -W $combineTimeNeeded -N -u $userEmail -J combineHiCWrapper -o $userHomeDirectory/lsf_jobs/LSB_%J.log -e $userHomeDirectory/lsf_jobs/LSB_%J.err $cMapping/utilities/combineHiCWrapper.sh $configFilePath`;
    chomp($return);
    print "\t$return\n";
    print "\n";
        
}