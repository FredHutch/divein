#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q =  new CGI;
my ($remote_addr) = Divein::GetInfo();

print $q->header;
Divein::Print_header('diver', 'process');

print "<div id='indent'>";
print "<h2>Hamming distance and diversity</h2>";

my $docsRoot = $DiveinParam::documentroot;
my $uploadbase = $DiveinParam::uploadbase;
my $id = $q->param("id");
my $seqFileName = $q->param("seqFileName");
my $email = $q->param("email");
my $program = $q->param("program");
my $uploadDir = $uploadbase."/$id";
my $uploadgrpFile = $uploadDir.'/'."$id.group.txt";
my @ingrpNames = my @ingrpSeqs = ();
my $grpNameSeqs;
my @params = $q->param;
foreach my $param (@params) {
	if ($param =~ /ingrpName/) {
		push @ingrpNames, $q->param($param);
	}elsif ($param =~ /ingrp/) {
		my @seqs = $q->param($param);
		push @ingrpSeqs, \@seqs;
	}
}

open GRP, ">", $uploadgrpFile;
if (!@ingrpSeqs) {	# user didn't define ingroups, all sequences except outgroup will be put in one group named as "default"
	@ingrpSeqs = $q->param("seqName");	
	foreach my $ingrp (@ingrpSeqs) {
		print GRP "default\t$ingrp\n";
	}	
}else {	# user defined ingroups
	for (my $i=0; $i<@ingrpNames; $i++) {
		foreach my $grpSeq (@{$ingrpSeqs[$i]}) {	
			print GRP "$ingrpNames[$i]\t$grpSeq\n";	
		}
	}
}
close GRP;

my @parameterArray;
push @parameterArray, $id, $seqFileName, $email, $uploadDir, $remote_addr, $docsRoot, $program;

# fork.
my $pid = fork();
die "Failed to fork: $!" unless defined $pid;

if ($pid == 0) {
	# Execute the background process.
	close(STDIN);
    close(STDOUT);
    close(STDERR);
    open(STDIN,  "</dev/null");
    open(STDOUT, ">/dev/null");
    open(STDERR, ">/dev/null");
	exec("perl", "hd.pl", @parameterArray);
	exit(0);
}

print "<p>Your job id is $id.</p>";
print "<p>Your data is being processed...</p>";
print "<p>Results will be sent to <strong>$email</strong> when the job is done.</p>";

Divein::PrintFooter();
