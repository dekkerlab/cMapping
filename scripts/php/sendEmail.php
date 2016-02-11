<?php

if(isset($argv[1])) { $emailTo = $argv[1]; } else { $emailTo = "bryan.lajoie@umassmed.edu"; } #comma seperated
if(isset($argv[2])) { $ccTo = $argv[2]; } else { $ccTo = "my5C.help@umassmed.edu"; }
if(isset($argv[3])) { $subject = $argv[3]; } else { $subject = "c-world alert"; }
if(isset($argv[4])) { $messageFile = $argv[4]; } else { $messageFile = ""; }

$body="";
if((file_exists($messageFile) and (filesize($messageFile) > 0))) {
	$lines = file($messageFile);
	foreach ($lines as $line_num => $line) {
		$body .= "$line\r\n";
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
  
$message.="--{$mime_boundary}--\n";
 
mail($emailTo, $subject, $message, $headers);
?>
