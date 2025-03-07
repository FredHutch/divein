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
print "<h2>Phylogeny/divergence/diversity by PhyML 3.3.20220408</h2>";

my ($id, $uploadDir, $seqFileName, $seqType, $r_seed, $bootstrap, $ttRatio, $proportion, $subRateCat, $gamma, $opt, $diverFormat, $size_flag, @divergence);
my $datatype = $q->param("datatype");
my $subModel = $q->param("subModel");
my $freq = $q->param("freq");
my $email = $q->param("email");
my $program = $q->param("program");
my $treeImprovType = $q->param("treeImprovType");
my $uploadbase = $DiveinParam::uploadbase;

if ($q->param("id")) {
	$id = $q->param("id");
	$uploadDir = $uploadbase."/$id";
	$seqFileName = $q->param("seqFileName");
	$seqType = $q->param("seqType");
	$r_seed = $q->param("r_seed");
	$bootstrap = $q->param("bootstrap");
	$ttRatio = $q->param("ttRatio");
	$proportion = $q->param("proportion");
	$subRateCat = $q->param("subRateCat");
	$gamma = $q->param("gamma");	
	$opt = $q->param("opt");
	$diverFormat = $q->param("diverFormat");
	$size_flag = $q->param("sizeFlag");	
	@divergence = $q->param('DiverSeqName');
}else {
	$r_seed = time();
	my $rand = int (rand (90)) + 10;
	$id = $r_seed.$rand;
	$uploadDir = $uploadbase."/$id";
	$seqFileName = $q->param('seqFile') || 'Example';
	my $seqFileRadio = my $seqFormat = $q->param("seqRadio");
	my $seedRadio = $q->param("seedRadio");
	if ($seedRadio eq "fixed") {
		$r_seed = $q->param("seedText");
	}
	my $bsRadio = $q->param("bsRadio");
	$bootstrap = $q->param("bsText") || $q->param("aLRT") || 0;
	my $ttRadio = $q->param("ttRadio");
	$ttRatio = $q->param("ttRadio");
	if ($ttRadio && $ttRadio eq "f") {	# fixed tt ratio
		$ttRatio = $q->param("ttText");
	}
	my $propRadio = $q->param("propRadio");
	$proportion = "e";
	if ($propRadio eq "fixed") {
		$proportion = $q->param("propText");
	}
	$subRateCat = $q->param("catText");
	my $gammaRadio = $q->param("gammaRadio");
	$gamma = '';
	if ($gammaRadio eq 'estimated') {
		$gamma = 'e';
	}elsif ($gammaRadio eq 'fixed') {
		$gamma = $q->param("gammaText");
	}
	$opt = $q->param("optimise");
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

	my $seqInfo = Divein::GetSequences ($seqFileLines, $seqFileRadio);	# get sequence info such as sequence number, length, array of seq name and array of seq name and sequence
	my $seqNum = shift @$seqInfo;
	my $seqLen = shift @$seqInfo;
	my $datasize = $seqNum * $seqLen;
	$size_flag = 0;
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
	my $emailfile = $DiveinParam::documentroot."/emails.txt";
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
		#print "$param: @seqs<br>";
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
push @parameterArray, $id, $seqFileName, $seqType, $datatype, $bootstrap, $subModel, $freq, $ttRatio, $proportion, $subRateCat, $gamma, $treeImprovType, $opt, $email, $diverFormat, $uploadDir, $remote_addr, $divergences, $program, $r_seed;

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
	exec("perl", "diver.pl", @parameterArray);
	exit(0);
}

print "<p>Your job id is $id.</p>";
print "<p>Your data is being processed...</p>";
print "<p>Results will be sent to <strong>$email</strong> when the job is done.</p>";

Divein::PrintFooter();
