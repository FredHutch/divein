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
print "<div id='indent'>";
print "<h2>Phylogeny/divergence/diversity by PhyML 3.3.20220408</h2>";

my $uploadbase = $DiveinParam::uploadbase;
my $docuroot = $DiveinParam::documentroot;
my $r_seed = time();
my $rand = int (rand (90)) + 10;
my $id = $r_seed.$rand;
my $uploadDir = $uploadbase."/$id";
my $seqFileName = $q->param('seqFile') || 'Example';
my $seqFileRadio = my $seqFormat = $q->param("seqRadio");
my $datatype = $q->param("datatype");
my $seedRadio = $q->param("seedRadio");
if ($seedRadio eq "fixed") {
	$r_seed = $q->param("seedText");
}
my $bsRadio = $q->param("bsRadio");
my $bootstrap = $q->param("bsText") || $q->param("aLRT") || 0;
my $subModel = $q->param("subModel");
my $freq = $q->param("freq");
my $ttRadio = my $ttRatio = $q->param("ttRadio");
if ($ttRadio && $ttRadio eq "f") {	# fixed tt ratio
	$ttRatio = $q->param("ttText");
}
my $propRadio = $q->param("propRadio");
my $proportion = "e";
if ($propRadio eq "fixed") {
	$proportion = $q->param("propText");
}
my $subRateCat = $q->param("catText");
my $gammaRadio = $q->param("gammaRadio");
my $gamma = '';
if ($gammaRadio eq 'estimated') {
	$gamma = 'e';
}elsif ($gammaRadio eq 'fixed') {
	$gamma = $q->param("gammaText");
}
my $treeImprovType = $q->param("treeImprovType");
my $opt = $q->param("optimise");
my $email = $q->param("email");
my $program = $q->param("program");
my $diverFormat = "";
my @diverFormats = $q->param("divermeasure");
if (@diverFormats) {
	if (scalar @diverFormats == 1) {
		$diverFormat = $diverFormats[0];
	}else {
		$diverFormat = "both";
	}
}
my @divergence = $q->param('divergence');
my $divergences = '';
if (@divergence) {
	$divergences = join(',', @divergence);
}

my $seqType = 'DNA';
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

print "<form enctype='multipart/form-data' action=\"/cgi-bin/diver/diver.cgi\" name=grpForm method=post onsubmit=\"setAllTrue('mulselect'); return CheckOutgroup(this.DiverSeqName, this.OutgrpSeqName, 'mulselect');\">";
print "<input type=hidden name='id' value=$id>";
print "<input type=hidden name='seqFileName' value=$seqFileName>";
print "<input type=hidden name='seqType' value=$seqType>";
print "<input type=hidden name='datatype' value=$datatype>";
print "<input type=hidden name='bootstrap' value=$bootstrap>";
print "<input type=hidden name='subModel' value=$subModel>";
print "<input type=hidden name='freq' value=$freq>";
print "<input type=hidden name='ttRatio' value=$ttRatio>";
print "<input type=hidden name='proportion' value=$proportion>";
print "<input type=hidden name='subRateCat' value=$subRateCat>";
print "<input type=hidden name='gamma' value=$gamma>";
print "<input type=hidden name='treeImprovType' value=$treeImprovType>";
print "<input type=hidden name='opt' value=$opt>";
print "<input type=hidden name='email' value=$email>";
print "<input type=hidden name='diverFormat' value=$diverFormat>";
print "<input type=hidden name='sizeFlag' value=$size_flag>";
print "<input type=hidden name='program' value=$program>";
print "<input type=hidden name='r_seed' value=$r_seed>";

print <<END_HTML;
<table border="0">
	<tr>
		<td align="center" colspan=3>Divergence measurement (optional)</td>
		<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
		<td align="center" colspan=4>Define groups (optional)</td>
	</tr>
	<tr>
		<td align="center">Sequences</td>
		<td></td>
		<td align="center">Calculate divergence from:</td>
		<td></td>
		<td align="center">Outgroup</td>
		<td></td>
		<td align="center">Sequences</td>
		<td align="center">Ingroup <input type="button" value="+" name="ingrpbutton" onclick="addIngrp('inGrps', this.form.seqName)"></td>
	</tr>
	<tr>
		<td valign="top">
			<select class="mulselect" id="allSeqName" name="allSeqName" size="36" multiple>
				<option value="MRCA">MRCA</option>
				<option value="Consensus">Consensus</option>
				<option value="COT">COT</option>
END_HTML
foreach my $name (@$stdSeqNames) {
	print "<option value=$name>$name</option>";
}
print <<END_HTML;
			</select>
		</td>
		<td align="center">
			<input type="button" value="--&gt;"
			 onclick="moveOptions(this.form.allSeqName, this.form.DiverSeqName);" /><br />
			<input type="button" value="&lt;--"
			 onclick="moveOptions(this.form.DiverSeqName, this.form.allSeqName);" />
		</td>
		<td valign="top">
			<select class="mulselect" id="DiverSeqName" name="DiverSeqName" size="36" multiple>			
			</select>
		</td>
		<td></td>
		<td valign="top">
			<select class="mulselect" id="OutgrpSeqName" name="OutgrpSeqName" size="36" multiple>			
			</select>
		</td>
		<td align="center">
			<input type="button" value="&lt;--"
			 onclick="moveOptions(this.form.seqName, this.form.OutgrpSeqName);" /><br />
			<input type="button" value="--&gt;"
			 onclick="moveOptions(this.form.OutgrpSeqName, this.form.seqName);" />
		</td>
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



