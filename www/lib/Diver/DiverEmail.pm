package Diver::DiverEmail;

use strict;
use warnings;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Email::Simple;
use Email::Simple::Creator; # For creating the email


sub SendEmail {
	my ($emailAddr, $id, $flag, $errorMsg, $type, $diverFormat, $uploadDir, $seqFileName, $diverseqNames, $program) = @_;
	my $emailbody = '';
	if ($flag eq "Success") {
		$emailbody = "<p>Your job $id for the input sequence file of $seqFileName has finished on DIVEIN server. Please click <a  href='https://divein.fredhutch.org/cgi-bin/diver/result.cgi?id=$id&type=$type&format=$diverFormat&diverseqNames=$diverseqNames&program=$program'>here</a> to get results.</p>
		<p>If the link does not work, please copy and paste following URL to your browser to get your results:<br>https://divein.fredhutch.org/cgi-bin/diver/result.cgi?id=$id&type=$type&format=$diverFormat&diverseqNames=$diverseqNames&program=$program</p>
		<p>The result will be kept 5 days after this message was sent.</p>";	
	}else {
		if ($errorMsg eq "monophyletic") {
			$emailbody = "<p>Couldn't find the MRCA node duo to improper outgroup sequence position.</p>";
		}elsif ($errorMsg eq "notree") {
			$emailbody = "<p>Couldn't get reconstructed tree. Probablly the input sequence dataset is too large (too many sequences), or the sequence data type (DNA or protein) you entered is not correct.</p>";
		}else {
			$emailbody = "<p>Couldn't finish your job. Here is the error message:</p>
			<p>$errorMsg</p>";
		}		
	}
	$emailbody .= "<p>If you have any questions please email to mullspt\@uw.edu. Thanks!</p>";	

	# Create the email
	my $email = Email::Simple->create(
		header => [
			To => $emailAddr,
			From => 'divein@fredhutch.org',
			Subject => "Your Web DIVEIN #$id Results",
		],
		body => $emailbody,
	);
	$email->header_set( 'Content-Type' => 'Text/html' );
	$email->header_set( 'Reply-To' => 'mullspt@uw.edu' );
	
	# Configure the SMTP transport
	my $transport = Email::Sender::Transport::SMTP->new({
		host => 'mx.fhcrc.org', # Your SMTP server address
		port => 25, # Common ports are 25, 465, or 587
		ssl => 0, # Set to 1 if SSL is required
		# sasl_username => 'your_username', # Your SMTP username
		#sasl_password => 'your_password', # Your SMTP password
	});
	
	# Send the email
	eval {
		sendmail($email, { transport => $transport });
		print "Email sent successfully!\n";
	};
	if ($@) {
		die "Failed to send email: $@\n";
	}
}

1;