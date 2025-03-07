#!/usr/bin/perl -w

use strict;
use Bio::TreeIO;
use Bio::Tree::TreeFunctionsI;
use File::Copy;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;
use Cot;

my $cgi =  new CGI;
my ($remote_ip, $url) = Divein::GetInfo();
print $cgi->header;
Divein::Print_header('cot', 'process');

print "<div id='indent'>";
print "<h2>Center Of Tree</h2>";

my $rand = int (rand (90)) + 10;
my $id = time().$rand;
my $uploadbase = $DiveinParam::uploadbase;
my $docuroot = $DiveinParam::documentroot;
my $uploadDir = $uploadbase."/$id";
my $seqRadio = $cgi->param("seqRadio");
my $datatype = $cgi->param("datatype");
my $treeRadio = $cgi->param("treeRadio");
my $email = $cgi->param("email");

my $uploadSeqFile = $uploadDir.'/'."$id.sequence.txt";
my $seqFile_handle;
if ($seqRadio eq "example") {	# probablly will implement example input later
	$datatype = 'nt';
	$treeRadio = 'no';
	my $exampleFile = Divein::GetExample('seqFile');
	open $seqFile_handle, $exampleFile or die "couldn't open sequence example file: $!\n";
}else {
	$seqFile_handle = $cgi->upload("seqFile");
}
my $seqFileLines = Divein::GetFileLines ($seqFile_handle);
my $seqInfo = Divein::GetSequences ($seqFileLines, $seqRadio);	# get sequence info such as sequence number, length, array of seq name and array of seq name and sequence
my $seqNum = shift @$seqInfo;
my $seqLen = shift @$seqInfo;
my $datasize = $seqNum * $seqLen;
if ($seqNum < 3) {
	print "<p>At least 3 sequences are required in your input sequence alignment file.</p>";
	Divein::PrintFooter();
}
my $emailfile = $docuroot."/emails.txt";
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

my $seqNames = shift @$seqInfo;
my $stdSeqNames = shift @$seqInfo;

# upload files
mkdir $uploadDir;
chmod 0755, $uploadDir;
my $seqnumNlen = $seqNum."\t".$seqLen;
my $stdnameNseqs = shift @$seqInfo;
unshift @$stdnameNseqs, $seqnumNlen;
Divein::WriteFile ($uploadSeqFile, $stdnameNseqs);
my $isInnodes = 0; 
if ($treeRadio eq "yes") {
	my %seqNameStatus;
	foreach (@$stdSeqNames) {
		$seqNameStatus{$_} = 1;
	}
	
	my $uploadTreeFile = $uploadSeqFile."_phyml_tree.txt";
	my $treeFile_handle = $cgi->upload("treeFile");	
	my $treeFileLines = Divein::GetFileLines ($treeFile_handle);
	Divein::WriteFile ($uploadTreeFile, $treeFileLines);
	my $tree = Cot::GetNewickTree ($uploadTreeFile);

	if ($tree) {	
		# Hyphy implementation don't need the tree with branch lengths
		my @leafNodes = $tree->get_leaf_nodes;
		# replace non charactors in node id with '_' and write to a file for further manipulate
		my $stdNodeIdTreeFile = $uploadDir.'/'.$id.".sequence_stripgap.txt_phyml_tree.txt";
		$isInnodes = Cot::StandardizeTreeNodeId ($tree, $stdNodeIdTreeFile);
		# check name matching between sequence file and tree file 
		foreach my $leafNode (@leafNodes) {
			if (!$seqNameStatus{$leafNode->id()}) {
				print "<p>Error: sequence names between sequence file and tree file did not match.</p>";
				unlink $uploadTreeFile;
				unlink $stdNodeIdTreeFile;
				Divein::PrintFooter();
			}
		}
	}else {
		print "<p>Couldn't get newick tree. Please check your tree file.</p>";
		Divein::PrintFooter();
	}	
}

# run job in a child process
my @params = ();
push @params, $uploadSeqFile, $seqRadio, $datatype, $treeRadio, $email, $id, $uploadDir, $docuroot, $remote_ip, $isInnodes;
my $pid = fork();
die "Failed to fork: $!" unless defined $pid;
if ($pid == 0) {
	# Child process
	close(STDIN);
    close(STDOUT);
    close(STDERR);
    open(STDIN,  "</dev/null");
    open(STDOUT, ">/dev/null");
    open(STDERR, ">/dev/null");
	exec ("perl", "cotseq.pl", @params);
	exit(0);
}

print "<p>Your job id is $id.</p>";
print "<p>Your data is being processed now.</p>";
print "<p>Results will be sent to <strong>$email</strong> when the job is done.</p>";

Divein::PrintFooter();
