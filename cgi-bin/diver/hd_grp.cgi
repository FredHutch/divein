#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;
use Diver;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

my $q =  new CGI;
print $q->header;
Divein::Print_header('diver', 'process');
print "<div id='indent' align='center'>";
print "<h2>Hamming distance and diversity</h2>";

my $docsRoot = $DiveinParam::documentroot;
my $uploadbase = $DiveinParam::uploadbase;
my $rand = int (rand (90)) + 10;
my $id = time().$rand;
my $uploadDir = $uploadbase."/$id";
my $seqFileName = $q->param('seqFile') || 'Example';
my $email = $q->param("email");
my $program = $q->param("program");
my $uploadSeqFile = $uploadDir.'/'."$id.sequence.txt";

my $seqFile_handle;
if ($seqFileName eq "Example") {
	my $exampleFile = Divein::GetExample('alignFile.fas');
	open $seqFile_handle, $exampleFile or die "couldn't open sequence example file: $!\n";
}else {
	$seqFile_handle = $q->upload("seqFile");
}
my $seqFileLines = Divein::GetFileLines ($seqFile_handle);
close $seqFile_handle;

my $seqInfo = Divein::GetSequences ($seqFileLines, "fasta");	# get sequence info such as sequence number, length, array of seq name and array of seq name and sequence
my $seqNum = shift @$seqInfo;
my $seqLen = shift @$seqInfo;
my $datasize = $seqNum * $seqLen;
my $size_flag = 0;
if ($seqNum < 2) {
	print "<p>At least 2 sequences are required in your input sequence alignment file.</p>";
	Divein::PrintFooter();
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
	if ($datasize > 1500000) {
		print "<p>The maximum size of input sequence data is 1.5M (sequence number x alignment length).</p>";
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

# defines group and/or outgroup for divergence/diversity analysis

print "<form enctype='multipart/form-data' action=\"/cgi-bin/diver/hd.cgi\" name=grpForm method=post onsubmit=\"setAllTrue('mulselect'); return CheckOutgroup(this.DiverSeqName, this.OutgrpSeqName, 'mulselect');\">";
print "<input type=hidden name='id' value=$id>";
print "<input type=hidden name='seqFileName' value=$seqFileName>";
print "<input type=hidden name='email' value=$email>";
print "<input type=hidden name='program' value=$program>";

print <<END_HTML;
<table align='center' border="0">
	<tr>
		<td align="center" colspan=4>Define groups (optional)</td>
	</tr>
	<tr>
		<td align="center">Sequences</td>
		<td align="center">Groups <input type="button" value="+" name="ingrpbutton" onclick="addIngrp('inGrps', this.form.seqName)"></td>
	</tr>
		<td valign="top">
			<select class="mulselect" id="seqName" name="seqName" size="36" multiple>
END_HTML
foreach my $name (@$stdSeqNames) {
	print "<option value=$name>$name</option>";
}
print <<END_HTML;
			</select>
		</td>
		<td valign="top">
			<table id="inGrps">
			
			</table>
		</td>
	</tr>	
</table>
<div class='row' align=center>
		<span><input type='submit' value=' Submit '></span>
</div>
</form>
END_HTML

Divein::PrintFooter();



