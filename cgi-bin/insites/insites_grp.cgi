#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use Divein;
use DiveinParam;

my $cgi =  new CGI;
print $cgi->header;
Divein::Print_header('insites', 'process');

print "<div id='indent' align='center'>";
print "<h2>Informative sites</h2>";

my $startTime = time();
my $uploadbase = $DiveinParam::uploadbase;
my $rand = int (rand (90)) + 10;
my $id = $startTime.$rand;
my $uploadDir = $uploadbase."/$id";
my $seqRadio = $cgi->param("seqRadio");
my $datatype = $cgi->param("datatype");
my $seqGrpHashRef;
my @nas;

my $seqFile = $uploadDir.'/'.$id;
my $seqFile_handle;
if ($seqRadio eq 'example') {
	my $exampleFile = Divein::GetExample('seqFile');
	open $seqFile_handle, $exampleFile or die "couldn't open sequence example file: $!\n";
	$datatype = 'nt';
}else {
	$seqFile_handle = $cgi->upload("seqFile");
}

my $seqFileLines = Divein::GetFileLines ($seqFile_handle);
# get sequence info such as sequence number, length, array of seq name and array of seq name and sequence
my $seqInfo = Divein::GetSequences ($seqFileLines, $seqRadio);	
my $seqNum = shift @$seqInfo;
my $seqLen = shift @$seqInfo;
my $seqNamesRef = shift @$seqInfo;
my $stdNamesRef = shift @$seqInfo;

# upload files
mkdir $uploadDir;
chmod 0755, $uploadDir;

my $seqNameNseq = shift @$seqInfo;
unshift @$seqNameNseq, $seqNum."\t".$seqLen;
Divein::WriteFile ($seqFile, $seqNameNseq);

print "<form enctype='multipart/form-data' action=\"/cgi-bin/insites/insites.cgi\" name='grpForm' method='post' onsubmit=\"setAllTrue('mulselect'); return CheckGroups('mulselect');\">";
print "<input type=hidden name='id' value=$id>";
print "<input type=hidden name='uploadbase' value=$uploadbase>";
print "<input type=hidden name='seqRadio' value=$seqRadio>";
print "<input type=hidden name='datatype' value=$datatype>";

print <<END_HTML;
<table border="0">
	<tr>
		<td align="center" colspan=2>Define reference (optional)</td>
		<td align="center" colspan=2>Define groups (optional)</td>
	</tr>
	<tr>
		<td align="center">(one at a time)</td>
		<td></td>
		<td align="center">Sequences</td>
		<td align="center">Group <input type="button" value="+" name="ingrpbutton" onclick="addIngrp('inGrps', this.form.seqName)"></td>
	</tr>
	<tr>
		<td valign="top">
			<select class="mulselect" id="reference" name="reference" size="36" multiple>			
			</select>
		</td>
		<td align="center">
			<input type="button" value="&lt;--"
			 onclick="moveOptions(this.form.seqName, this.form.reference);" /><br />
			<input type="button" value="--&gt;"
			 onclick="moveOptions(this.form.reference, this.form.seqName);" />
		</td>
		<td valign="top">
			<select class="mulselect" id="seqName" name="seqName" size="36" multiple>
END_HTML
foreach my $name (@$stdNamesRef) {
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
