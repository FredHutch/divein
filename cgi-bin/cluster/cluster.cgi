#!/usr/bin/perl -w

use strict;
use File::Copy;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $cgi =  new CGI;
my ($remote_ip, $url) = Divein::GetInfo();
print $cgi->header;
Divein::Print_header('cluster', 'process');

print "<div id='indent'>";
print "<h2>Sequence clustering</h2>";

my $startTime = time();
my $rand = int (rand (90)) + 10;
my $id = $startTime.$rand;
my $uploadbase = $DiveinParam::uploadbase;
my $uploadDir = $uploadbase."/$id";
my $seqFile = $cgi->param("seqFile");
my $alignFile = $cgi->param("alignFile");
my $treeFile = $cgi->param("treeFile");
my $seqExampleCb = $cgi->param("seqExampleCb");
my $alignExampleCb = $cgi->param("alignExampleCb");
my $treeExampleCb = $cgi->param("treeExampleCb");
my $method = $cgi->param("distmeasure");
my $minclustersize = $cgi->param("minclustersize");
my $distcutoff = $cgi->param("distcutoff");
my $email = $cgi->param("email");
my $filename = my $filetype = "";
my $docsRoot = $DiveinParam::documentroot;

my $file_handle;
if ($seqFile) {
	$file_handle = $cgi->upload("seqFile");
	$filetype = "--sequences";
	$filename = $seqFile;
}elsif ($seqExampleCb && $seqExampleCb eq 'example') {
	my $exampleFile = Divein::GetExample('seqFile.fas');
	open $file_handle, $exampleFile or die "couldn't open sequence example file: $!\n";
	$filetype = "--sequences";
	$filename = "Squence example";
}elsif ($alignFile) {
	$file_handle = $cgi->upload("alignFile");
	$filetype = "--alignment";
	$filename = $alignFile;
}elsif ($alignExampleCb && $alignExampleCb eq 'example') {
	my $exampleFile = Divein::GetExample('alignFile.fas');
	open $file_handle, $exampleFile or die "couldn't open sequence example file: $!\n";
	$filetype = "--alignment";
	$filename = "Alignment example";
}elsif ($treeFile) {
	$file_handle = $cgi->upload("treeFile");
	$filetype = "--tree";
	$filename = $treeFile;
}elsif ($treeExampleCb && $treeExampleCb eq 'example') {
	my $exampleFile = Divein::GetExample('treeFile.tre');
	open $file_handle, $exampleFile or die "couldn't open tree example file: $!\n";
	$filetype = "--tree";
	$filename = "Newick tree example";
}
mkdir $uploadDir;
chmod 0755, $uploadDir;
my $fileLines = Divein::GetFileLines ($file_handle);
my $uploadfile = "$uploadDir/$id"."_input";
Divein::WriteFile ($uploadfile, $fileLines);

my $outfile = "$uploadDir/$id"."_output.csv";
my $distfile = "$uploadDir/$id"."_distance.csv";

my @params = ();
push @params, "$filetype=$uploadfile", "--method=$method", "--output=$outfile", "--distance=$distfile", "--min-cluster-size=$minclustersize", "--distance-threshold=$distcutoff", $filename, $email, $id, $uploadDir, $remote_ip, $docsRoot;
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
	exec ("perl", "cluster.pl", @params);
	exit(0);
}

print "<p>Your job id is $id.</p>";
print "<p>Your data is being processed now.</p>";
print "<p>Results will be sent to <strong>$email</strong> when the job is done.</p>";

Divein::PrintFooter();
