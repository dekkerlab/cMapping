#!usr/bin/perl -w
#Bryan Lajoie
#8/20/2007

use strict;
use English;
use POSIX qw(ceil floor);
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Carp qw(carp cluck croak confess);

sub check_options {
    my $opts = shift;
    my ($jobID,$jobName,$configFile);
 
	if( exists($opts->{'jobID'}) ) {
		$jobID = $opts->{'jobID'};
    } else {
		croak "emailInitial: jobID|j is required.\n"
    }
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		croak "emailInitial: jobName|jn is required.\n";
	}
	
	if( exists($opts->{'configFile'}) ) {
		$configFile = $opts->{'configFile'};
    } else {
		croak "emailInitial: configFile|cf is required.\n";
	}
	
	return($jobID,$jobName,$configFile);
}


sub commify {
   (my $num = shift) =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g; 
   return $num; 
}

sub getDate() {

	my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	my $year = 1900 + $yearOffset;
	my $time = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
	
	return($time);
}

sub baseName($) {
	my $fileName=shift;
	
	my $shortName=(split(/\//,$fileName))[-1];
	
	return($shortName);
}	

my %options;
my $results = GetOptions( \%options,'jobID|j=s','jobName|jn=s','configFile|cf=s');
my ($jobID,$jobName,$configFile)=check_options( \%options );

my $time = getDate();

die("configFile does not exist! ($configFile)\n") if(!(-e($configFile)));

my %log=();
open(IN,$configFile);
while(my $line = <IN>) {
	chomp($line);
	next if($line =~ /^#/);
	
	my ($field,$value)=split(/=/,$line);
	$value =~ s/"//g;
	$value="n/a" if($value eq "");
	$log{$field}=$value;
}
close(IN);

open(OUT,">".$jobName.".start.mappingLog.txt");

print OUT "General\n";
print OUT "time\t".$time."\n";	
print OUT "cType\t".$log{ cType }."\n";
print OUT "logDirectory\t".$log{ logDirectory }."\n";
print OUT "UUID\t".$log{ UUID }."\n";
print OUT "cMapping\t".$log{ cMapping }."\n";
print OUT "computeResource\t".$log{ computeResource }."\n";
print OUT "reduceResources\t".$log{ reduceQueue }." / ".$log{ reduceTimeNeeded }."\n";
print OUT "mapResources\t".$log{ mapQueue }." / ".$log{ mapTimeNeeded }."\n";
print OUT "reduceScratchDir\t".$log{ reduceScratchDir }."\n";
print OUT "reduceScratchSize\t".$log{ reduceScratchSize }."M\n";
print OUT "mapScratchDir\t".$log{ mapScratchDir }."\n";
print OUT "mapScratchSize\t".$log{ mapScratchSize }."M\n";
print OUT "nCPU\t".commify(ceil(($log{ nReads }*4)/$log{ splitSize }))."\n";
print OUT "reduceMemoryNeeded\t".commify($log{ reduceMemoryNeededMegabyte })."M\n";
print OUT "mapMemoryNeeded\t".commify($log{ mapMemoryNeededMegabyte })."M\n";
print OUT "debugMode\ton\n" if($log{ debugModeFlag } == 1);
print OUT "snpMode\ton\n" if($log{ snpModeFlag } == 1);

print OUT "\nDataset\n";
print OUT "jobName\t".$log{ jobName }."\n";
print OUT "flowCell\t".$log{ flowCellName }."\n";
print OUT "laneName\t".$log{ laneName }."\n";
print OUT "laneNum\t".$log{ laneNum }."\n";
print OUT "side1File\t".baseName($log{ side1File })."\n";
print OUT "side2File\t".baseName($log{ side2File })."\n";
print OUT "readLength\t".$log{ readLength }."\n";
print OUT "qvEncoding\t".$log{ qvEncoding }."\n";
print OUT "numReads\t".commify($log{ nReads })."\n";

print OUT "\nAlignment Options\n";
print OUT "splitSize\t".commify($log{ splitSize })."\n";
print OUT "splitSizeMegabyte\t".commify($log{ splitSizeMegabyte })."M\n";
print OUT "aligner\t".$log{ aligner }."\n";
print OUT "alignmentSoftwarePath\t".$log{ alignmentSoftwarePath }."\n";
print OUT "alignmentOptions\t".$log{ alignmentOptions }."\n";
print OUT "side1AlignmentOptions\t".$log{ optionalSide1AlignmentOptions }."\n";
print OUT "side2AlignmentOptions\t".$log{ optionalSide2AlignmentOptions }."\n";
print OUT "snp-minimumReadDistance\t".$log{ minimumReadDistance }."\n" if($log{ snpModeFlag } == 1);
print OUT "assumeCisAllele\t".$log{ assumeCisAllele }."\n" if($log{ snpModeFlag } == 1);
print OUT "enzyme\t".$log{ enzyme }."\n";
print OUT "restrictionSite\t".$log{ restrictionSite }."\n";
print OUT "restrictionFragmentFile\t".$log{ restrictionFragmentPath }."\n";
print OUT "genome\t".$log{ genomeName }."\n";
print OUT "genomePath\t".$log{ genomePath }."\n";
print OUT "genomeSize\t".commify($log{ indexSizeMegabyte })."M\n";

close(OUT);

my $message='
<html>

<link rel="stylesheet" href="http://beta-3DG.umassmed.edu/css/dekkerc.css">
<link rel="icon" href="http://my5C.umassmed.edu/images/favicon.png" type="image/x-icon">
<link rel="shortcut icon" href="http://my5C.umassmed.edu/images/favicon.png" type="image/x-icon"> 
<title>c-world mapping statistics</title>

	<div id="banner" align="left">
		<table class="emailTable" width=800>
			<tr>
				<td align="left"><img class="first" height=50 src="http://beta-3DG.umassmed.edu/images/3DG.png"></img></td>
				<td align="center"><img height=35 src="http://beta-3DG.umassmed.edu/images/dekkerlabbioinformatics.gif"></img></td>
				<td align="right"><img class="first" src="http://beta-3DG.umassmed.edu/images/umasslogo.gif"></img></td>
				</td>
			</tr>
		</table>
	</div>
	<table class="emailTable" width=800>
		<tr>
			<td>
				<div class="pageTitle">c-World (<a href="http://c-world.umassmed.edu">http://c-world.umassmed.edu</a>)</div>
				<div class="subTitle">Starting c-World/cMapping pipeline job #'.$jobID.'</div>
				<div class="subTitle">('.$time.')</div>
			</td>
		</tr>
		<tr>
			<td>
				<table class="emailTable" width=800>';
                
my $lineNum=0;
my %data=();
open(HEADER,$jobName.".start.mappingLog.txt");	
while(my $line = <HEADER>) {
	chomp($line);
	
	$line =~ s/^# //;
	$lineNum++;
	
	my @tmp=split(/\t/,$line);
	
	my $nCols=0;
	for(my $i=0; $i<@tmp; $i++) {
		my $tmpVal=$tmp[$i];
		$nCols++ if($tmpVal ne "");
	}
	
	if($nCols == 0) {
		$message .= "<br>";
	} else {
				
		$data{$tmp[0]}=$tmp[1] if($nCols >= 2);
		
		$tmp[0] = "<font size=2>".$tmp[0]."</font>" if(($nCols >= 2) and (length($tmp[0]) >= 25));
		$tmp[1] = "<font size=2>".$tmp[1]."</font>" if(($nCols >= 2) and (length($tmp[1]) >= 40));
		
		if($nCols == 3) {
			$message .= "<tr>\n";
			$message .= "<td width=40%>".$tmp[0]."</td>\n";
			$message .= "<td width=40%>".$tmp[1]."</td>\n";
			$message .= "<td width=20%>(".$tmp[2]."%)</td>\n";
			$message .= "</tr>\n";
		} elsif($nCols == 2) {		
			$message .= "<tr>\n";
			$message .= "<td width=40%>".$tmp[0]."</td>\n";
			$message .= "<td width=60% colspan=2>".$tmp[1]."</td>\n";
			$message .= "</tr>\n";
		} elsif($nCols == 1) {
			$message .= "<tr><th colspan=3 width=100%>".$tmp[0]."</th></tr>\n";
		} else {
			print "$lineNum\t".@tmp."\t$line\tERROR\n";
			exit;
		}
	}
}
close(HEADER);

$message .= "</table></td></tr></table></html>";

open(OUT,">".$jobName.".start.mappingLog.html");
print OUT $message;
close(OUT);

my $team="";
my $cc="";

my $emailTo=$log{ emailTo };
my $userEmail=$log{ userEmail };
$team = "my5C.help\@umassmed.edu";
$team .= ",".$emailTo if(($emailTo ne "") and ($emailTo ne "none"));
$team .= ",".$userEmail if(($userEmail ne "") and ($userEmail ne "none"));

my $messageFile=$jobName.".start.message.html";
open(OUTMESSAGE,">".$messageFile);
print OUTMESSAGE $message;
close(OUTMESSAGE);

$team="my5C.help\@umassmed.edu";

my $subject='c-World STARTING ('.$jobID.') '.$log{ jobName };

`ssh ghpcc06 "php $data{ cMapping }/php/sendEmail.php '$team' '$cc' '$subject' '$messageFile'"`;

system("rm $messageFile");