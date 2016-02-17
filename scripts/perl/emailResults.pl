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

	my ($jobID,$jobName,$logFile,$configFile,$plotFolder);
	
	if( exists($opts->{'jobID'}) ) {
		$jobID = $opts->{'jobID'};
	} else {
		croak "emailInitial: jobID|j is required.\n";
	}
	
	if( exists($opts->{ jobName }) ) {
		$jobName = $opts->{ jobName };
	} else {
		croak "emailInitial: jobName|jn is required.\n"
	}
	
	if( $opts->{'logFile'} ) {
		$logFile = $opts->{'logFile'};
	} else {
		croak "emailResults: logFile|lf is required.";
	}
	
	if( exists($opts->{'configFile'}) ) {
		$configFile = $opts->{'configFile'};
	} else {
		croak "emailInitial: configFile|cf is required.\n";
	}
	
	
	if( exists($opts->{'plotFolder'}) ) {
		$plotFolder = $opts->{'plotFolder'};
	} else {
		$plotFolder = "";
	}
	
	return($jobID,$jobName,$logFile,$configFile,$plotFolder);	
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
&GetOptions( \%options,'jobID|j=s','jobName|jn=s','logFile|lf=s','configFile|cf=s','plotFolder|pf=s');
my ($jobID,$jobName,$logFile,$configFile,$plotFolder) = &check_options( \%options );

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
open(HEADER,$logFile);
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

open(OUT,">".$jobName.".end.mappingLog.html");
print OUT $message;
close(OUT);

my ($team,$cc);
$team = "my5C.help\@umassmed.edu";
$cc="";

my $emailTo=$log{ emailTo };
if($emailTo ne "none") {
	my @tmpArr=split(/,/,$emailTo);
	for(my $i=0;$i<@tmpArr;$i++) {
		my $tmpEmail = $tmpArr[$i];
		next if($tmpEmail eq "none");
		next if($tmpEmail !~ /\@/);
		
		my ($name,$domain)=split(/\@/,$tmpEmail);
		$tmpEmail = $name."@".$domain;
		$team .= ",".$tmpEmail;
	}
}

$team="my5C.help\@umassmed.edu";

my $attachmentString="";
$plotFolder = $plotFolder."/" if($plotFolder !~ /\/$/); # tack on trailing / if not there	
die("invalid plot dir! ($plotFolder)\n") if(!(-d($plotFolder)));
opendir(DIR, $plotFolder) || die "Can't opedir $plotFolder: $!\n";
while (my $plotFile = readdir DIR) {
	next if($plotFile =~ /^\./); # skip . an
	
	my $plotFilePath=$plotFolder.$plotFile;
	
	die("plot file does not exist! ($plotFilePath)\n") if(!(-e($plotFilePath)));
	
	$attachmentString .= ",".$plotFilePath if($attachmentString ne "");
	$attachmentString = $plotFilePath if($attachmentString eq "");
}
closedir(DIR);
	
my @attachmentPlotArray=split(/,/,$attachmentString);
my $attachmentNameString="";
for(my $i=0;$i<@attachmentPlotArray;$i++) {
	my $attachmentPlot=$attachmentPlotArray[$i];
	my $attachmentPlotName=baseName($attachmentPlot);
	
	$attachmentNameString .= ",".$attachmentPlotName if($attachmentNameString ne "");
	$attachmentNameString = $attachmentPlotName if($attachmentNameString eq "");
}

my $messageFile=$jobName.".end.message.html";
open(OUTMESSAGE,">".$messageFile);
print OUTMESSAGE $message;
close(OUTMESSAGE);

my $subject = "c-World COMPLETE ($jobID) ".$data{ jobName };
if($attachmentString ne "") {
	`ssh ghpcc06 "php $log{ cMapping }/php/sendEmailAttachments.php '$team' '$cc' '$subject' '$messageFile' '$attachmentString' '$attachmentNameString'"`
} else {
	`ssh ghpcc06 "php $log{ cMapping }/php/sendEmail.php '$team' '$cc' '$subject' '$messageFile'"`
}

system("rm $messageFile");