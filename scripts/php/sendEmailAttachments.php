\<?php

if(isset($argv[1])) { $emailTo = $argv[1]; } else { $emailTo = "bryan.lajoie@umassmed.edu"; } #comma seperated
if(isset($argv[2])) { $ccTo = $argv[2]; } else { $ccTo = "my5C.help@umassmed.edu"; }
if(isset($argv[3])) { $subject = $argv[3]; } else { $subject = "c-world alert"; }
if(isset($argv[4])) { $messageFile = $argv[4]; } else { $messageFile = ""; }
if(isset($argv[5])) { $fileString = $argv[5]; } else { $fileString = ""; }
if(isset($argv[6])) { $fileNameString = $argv[6]; } else { $fileNameString = ""; }

$body="";
if((file_exists($messageFile) and (filesize($messageFile) > 0))) {
	$lines = file($messageFile);
	foreach ($lines as $line_num => $line) {
		$body .= $line."\r\n";
	}
} else {
	$body="error";
}

$mime_boundary="==Multipart_Boundary_x".md5(mt_rand())."x";
 
$headers = "From: c-world <my5C.help@umassmed.edu>" . "\r\n" .
"Cc: " .$ccTo. "\r\n" .
"MIME-Version: 1.0\r\n" .
"Content-Type: multipart/mixed;\r\n" .
" boundary=\"{$mime_boundary}\"";

$message = "This is a multi-part message in MIME format.\n\n" .
"--{$mime_boundary}\n" .
"Content-Type: text/html; charset=\"iso-8859-1\"\n" .
"Content-Transfer-Encoding: 7bit\n\n" .
$body . "\n\n";
 
if($fileString != "") {
	$files = explode(",", $fileString);
	$fileNames = explode(",", $fileNameString);
	for($x=0;$x<count($files);$x++){
		print "attaching ... ".$files[$x]." ".$fileNames[$x]."\n";
		$data = chunk_split(base64_encode(file_get_contents($files[$x])) );
		$message .= "--{$mime_boundary}\n" .
		  "Content-Type: application/octet-stream;\n" .
		  "Content-Disposition: attachment;\n" .
		  " filename=".$fileNames[$x]."\n" .
		  "Content-Transfer-Encoding: base64\n\n" .
	   $data . "\n\n";
		$message .= "–-{$mime_boundary}\n";
	}
}
 
$message.="--{$mime_boundary}--\n";
 
mail($emailTo, $subject, $message, $headers);
?>
