#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;
use Diver;

my $q =  new CGI;
my ($remote_addr) = Divein::GetInfo();
print $q->header;
Divein::Print_header('diver', 'process');

print "<div id='indent'>";
print "<h2>Phylogeny/divergence/diversity by RAxML 8.2.12</h2>";

my ($id, $seqFileName, $seqType, $bootstrap, $heteromodel, $diver, @divergence, $size_flag, $uploadDir);
my $datatype = $q->param("datatype");
my $subModel = $q->param("subModel");
my $program = $q->param("program");
my $email = $q->param("email");
my $docsRoot = $DiveinParam::documentroot;
my $uploadbase = $DiveinParam::uploadbase;

if ($q->param("id")) {
	$id = $q->param("id");
	$uploadDir = $uploadbase."/$id";
	$seqFileName = $q->param("seqFileName");
	$seqType = $q->param("seqType");
	$bootstrap = $q->param("bootstrap");	
	$heteromodel = $q->param("heteromodel");
	$diver = $q->param("diver");
	@divergence = $q->param('DiverSeqName');
	$size_flag = $q->param("sizeFlag");
}else {
	my $rand = int (rand (90)) + 10;
	$id = time().$rand;
	$uploadDir = $uploadbase."/$id";
	$seqFileName = $q->param('seqFile') || 'Example';
	my $seqFileRadio = $q->param("seqRadio");
	my $gammaRadio = $q->param("gammaRadio");
	my $bsRadio = $q->param("bsRadio");
	$bootstrap = $q->param("bsText");
	$diver = $q->param("diverRadio");
	$seqType = 'DNA';
	if ($datatype eq 'aa') {
		$seqType = 'Protein';
	}
	
	my $uploadSeqFile = $uploadDir.'/'."$id.sequence.txt";
	my $seqFile_handle;
	if ($seqFileRadio eq "example") {
		$datatype = 'nt';
		my $exampleFile = Divein::GetExample('seqFile');
		open $seqFile_handle, $exampleFile or die "couldn't open sequence example file: $!\n";
	}else {
		$seqFile_handle = $q->upload("seqFile");
	}
	my $seqFileLines = Divein::GetFileLines ($seqFile_handle);
	close $seqFile_handle;
	
	if ($gammaRadio eq 'gamma') {
		if ($datatype eq "nt") {
			$heteromodel = "GTRGAMMA";
		}else {
			$heteromodel = "PROTGAMMA".$subModel;
		}	
	}else {
		if ($datatype eq "nt") {
			$heteromodel = "GTRCAT";
		}else {
			$heteromodel = "PROTCAT".$subModel;
		}	
	}
	
	my $seqInfo = Divein::GetSequences ($seqFileLines, $seqFileRadio);	# get sequence info such as sequence number, length, array of seq name and array of seq name and sequence
	my $seqNum = shift @$seqInfo;
	my $seqLen = shift @$seqInfo;
	my $datasize = $seqNum * $seqLen;
	my $size_flag = 0;
	if ($seqNum < 3) {
		print "<p>At least 3 sequences are required in your input sequence alignment file.</p>";
		Divein::PrintFooter();
	}
	if ($datatype eq 'nt' && $datasize > 1500000) {
		$size_flag = 1;
	}elsif ($datatype eq 'aa' && $datasize > 500000) {
		$size_flag = 1;
	}
	if ($seqNum > 1000) {
		$size_flag = 1;
	}
	my $emailfile = $docsRoot."/emails.txt";
	my %emailstatus;
	open EMAIL, "<", $emailfile or die "couldn't open $emailfile: $!\n";
	while (my $line = <EMAIL>) {
		chomp $line;
		$emailstatus{$line} = 1;
	}
	close EMAIL;

	unless ($emailstatus{$email}) {
		if ($datatype eq 'nt' && $datasize > 1500000) {
			print "<p>The maximum size of input DNA sequence data is 1.5M (sequence number x alignment length).</p>";
			Divein::PrintFooter();
		}elsif ($datatype eq 'aa' && $datasize > 500000) {
			print "<p>The maximum size of input protein sequence data is 500K (sequence number x alignment length).</p>";
			Divein::PrintFooter();
		}
		if ($seqNum > 1000) {
			print "<p>The maximum number of input sequences for analysis is 1000.</p>";
			Divein::PrintFooter();
		}
	}

	my $seqNames = shift @$seqInfo;	# original sequence name

	# upload files
	mkdir $uploadDir;
	chmod 0755, $uploadDir;
	my $stdSeqNames = shift @$seqInfo;
	my $seqnumNlen = $seqNum."\t".$seqLen;
	my $stdnameNseqs = shift @$seqInfo;
	unshift @$stdnameNseqs, $seqnumNlen;
	Divein::WriteFile ($uploadSeqFile, $stdnameNseqs);
}
my $divergences = '';
if (@divergence) {
	$divergences = join(',', @divergence);
}

my $uploadOutgrpFile = $uploadDir.'/'."$id.outgrp.txt";
unlink $uploadOutgrpFile if (-e $uploadOutgrpFile);
my @outgrps = $q->param("OutgrpSeqName");
if (@outgrps) {	
	open OUTGRP, ">", $uploadOutgrpFile;
	foreach my $outgrp (@outgrps) {
		print OUTGRP "$outgrp\n";
	}
	close OUTGRP;
}

my $uploadgrpFile = $uploadDir.'/'."$id.group.txt";
my @ingrpNames = my @ingrpSeqs = ();
my $grpNameSeqs;
my @sample1Grps = my @sample2Grps = ();
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
push @parameterArray, $id, $seqFileName, $seqType, $datatype, $bootstrap, $subModel, $heteromodel, $email, $diver, $uploadDir, $remote_addr, $divergences, $docsRoot, $program;

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
	exec("perl", "raxml.pl", @parameterArray);
	exit(0);
}

print "<p>Your job id is $id.</p>";
print "<p>Your data is being processed...</p>";
print "<p>Results will be sent to <strong>$email</strong> when the job is done.</p>";

Divein::PrintFooter();



