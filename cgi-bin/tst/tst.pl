#!/usr/bin/perl -w

######################################################################################################
# This script takes MacClade alignment nexus file or phylip file, difined outgroup sequence name file
# and ingroup file as input, tranfers nexus file to phylip file if necessary, runs phyml
# program, difines MRCA from phyml output tree file using HYPHY, removes outgroup sequences 
# from original phylip file and adds MRCA sequence. run phyml again to get distance matrix,
# calculate divergence and diversity in tree based and/or pairwise distance based as user difined.
# Author: Wenjie Deng
# Date: 2007-01-12
# version: 1.0.1
######################################################################################################

use strict;
use warnings;
use v5.10;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Email::Simple;
use Email::Simple::Creator; # For creating the email


my ($id, $email, $uploadDir, $remoteIP, $projectId, $docuroot);
BEGIN {
	$id             = shift;	# job id
	$email          = shift;
	$uploadDir      = shift;	# directory for uploading files
	$remoteIP       = shift;
	$projectId      = shift;
	$docuroot       = shift;
}
my $rscript = "$docuroot/TwoSampleStat.R";
chdir $uploadDir;
system ("/usr/bin/R CMD BATCH -$uploadDir $rscript");

my $t = my $df = my $zTest = my $tTest = '';
my (@counts, @dfs);
open OUT, "TwoSampleStat.Rout" or die "couldn't open Two-Sample Tests output file: $!\n";
while (my $line = <OUT>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	if ($line !~ /^>/ && $line !~ /^\+/) {
		$line =~ s/\"//g;
		if ($line =~ /^Read (\d+) records/) {
			push @counts, $1;
		}
		if ($line =~ /T= (\S+) df= (\S+)/) {
			$t = trimDecimal($1);
			$df = trimDecimal($2);
		}
		if ($line =~ /Z-test P= (\S+)/) {
			$zTest = trimDecimal($1);
			
		}
		if ($line =~ /T-test P= (\S+)/) {
			$tTest = trimDecimal($1);
		}	
	}	
}

my $log = $uploadDir.'/'.$id;
if ($projectId) {
	$log .= "_tst.log";
}else {
	$log .= ".log";
}

open LOG, ">", $log or die "couldn't open $log: $!\n";
print LOG "Project: tst\nid: $id\nuploadDir: $uploadDir\nIP: $remoteIP\nemail: $email\n";
print LOG "T=$t\n";
print LOG "df=$df\n";
print LOG "Z-test P=$zTest\n";
print LOG "T-test P=$tTest\n";
close LOG;

#create a file to indicate the status of the finished job.
open TOGGLE, ">", "$uploadDir/toggle" or die "couldn't create file toggle\n";
close TOGGLE;

my $finishTime = localtime();
chomp $finishTime;
my $statDir = "$docuroot/stats";
unless (-e $statDir) {
	mkdir $statDir;
	chmod 0777, $statDir;
}
my $statFile = "$statDir/tst.stat";
open STAT, ">>", $statFile or die "couldn't open $statFile: $!\n";
print STAT "$finishTime\t$id\t$remoteIP\t$email\n";
close STAT;

if ($email) {
	my $body = "<p>Your job #$id has finished on our server. Please click <a href=https://divein.fredhutch.org/cgi-bin/tst/result.cgi?id=$id>
	here</a> to get result.</p><p>If the link does not work, please copy and paste following URL to your browser to get your result: 
	<a href=https://divein.fredhutch.org/cgi-bin/tst/result.cgi?id=$id>https://divein.fredhutch.org/cgi-bin/tst/result.cgi?id=$id
	</a></p><p>The result will be kept for 5 days after this message was sent.</p>
	<p>If you have any questions please email to mullspt\@uw.edu. Thanks.</p>";

	# Create the email
	my $create_email = Email::Simple->create(
		header => [
			To => $email,
			From => 'divein@fredhutch.org',
			Subject => "Your Web DIVEIN #$id Results",
		],
		body => $body,
	);
	$create_email->header_set( 'Content-Type' => 'Text/html' );
	$create_email->header_set( 'Reply-To' => 'mullspt@uw.edu' );
	
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
		sendmail($create_email, { transport => $transport });
		print "Email sent successfully!\n";
	};
	if ($@) {
		die "Failed to send email: $@\n";
	}
}

sub trimDecimal {
	my $value = shift;
	my $number = $value;
	if ($value =~ /^[0-9\-]/) {
		my @fields = split /e/, $value;
		$number = int ($fields[0] * 1000000) / 1000000;
		if (scalar @fields == 2) {
			$number .= "e$fields[1]";
		}
	}	
	return $number;
}
