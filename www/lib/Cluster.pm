package Cluster;

use strict;
use warnings;
#use Carp qw[croak carp];
#use Data::Dumper;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Email::Simple;
use Email::Simple::Creator; # For creating the email


=head1 NAME

Common -- package for  routines used in cot

=head1 SYNOPSIS


=head1 METHODS


=cut


sub SendEmail {
	my ($emailAddr, $id, $flag, $errorMsg, $uploadDir, $filename) = @_;
	my $emailbody = '';
	if ($flag eq "Success") {
		$emailbody = "<p>Your job $id of the input file of $filename has finished on our server. Please click <a  href='https://divein.fredhutch.org/cgi-bin/cluster/result.cgi?id=$id'>here</a> to check the result.</p>
		<p>If the link does not work, please copy and paste following URL to your browser to get your results:<a href=https://divein.fredhutch.org/cgi-bin/cluster/result.cgi?id=$id>https://divein.fredhutch.org/cgi-bin/cluster/result.cgi?id=$id
		</a></p>
		<p>The result will be kept for 5 days after this message was sent.</p>";	
	}else {
		$emailbody = "<p>Couldn't finish your job. Here is the error message:</p>
		<p>$errorMsg</p>";		
	}
	$emailbody .= "<p>If you have any questions please email to mullspt\@uw.edu. Thanks!</p>";	

	# Create the email
	my $email = Email::Simple->create(
		header => [
			#To => '"Recipient Name" <recipient@fredhutch.org>',
			#From => '"Sender Name" <sender@fredhutch.org>',
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


1; #TRUE!!
