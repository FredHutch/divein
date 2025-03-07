#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $cgi =  new CGI;
print $cgi->header;
Divein::Print_header('tst', 'process');

my $startTime = time();
my $uploadbase = $DiveinParam::uploadbase;
my $rand = int (rand (90)) + 10;
my $id = $startTime.$rand;
my $uploadDir = $uploadbase."/$id";
my $projectId = $cgi->param("projectId");
my $diveinFile = $cgi->param("diveinFile");
my $userFile = $cgi->param("userFile");
my $seqFile = $cgi->param("seqFile");
my $email = $cgi->param("email");
my $docuroot = $DiveinParam::documentroot;

$projectId = Divein::CleanString($projectId);
if ($projectId) {
	$projectId = Divein::CleanString($projectId);
	if ($projectId =~ /^\d+$/) {
		$id = $projectId;
		$uploadDir = $uploadbase."/$id";
	}else {
		print "<div id='indent'>";
		print "<p>Project ID should be comprised of digits.</p>";
		Divein::PrintFooter();
		exit;
	}
}
my $diveinExampleCb = $cgi->param("diveinExampleCb");
my $userExampleCb = $cgi->param("userExampleCb");
my $seqExampleCb = $cgi->param("seqExampleCb");

my ($distFileLines, %distSeqStatus, @seqNames, %nameSeq);
if ($projectId) {
	if (-e $uploadDir) {
		my $pwdistFile = "$uploadDir/$id"."_pwcoldist.txt";
		my $tbdistFile = "$uploadDir/$id"."_tbcoldist.txt";
		my $seqFastaFile = "$uploadDir/$id".".sequence.txt.fas";
		my $distFile = "";
		if (-s $pwdistFile) {
			$distFile = $pwdistFile;
		}elsif (-s $tbdistFile) {
			$distFile = $tbdistFile;
		}
		if ($distFile) {
			open DIST, $distFile or die "couldn't open $distFile: $!\n";
			while (my $line = <DIST>) {
				chomp $line;
				next if $line =~ /^\s*$/;
				my @fields = split /\t/, $line;
				push @$distFileLines, $fields[2]."\t".$fields[3]."\t".$fields[4];
				$distSeqStatus{$fields[2]} = $distSeqStatus{$fields[3]} = 1;
			}
			close DIST;
			my $name = "";
			open SEQ, $seqFastaFile or die "couldn't open $seqFastaFile: $!\n";
			while (my $line = <SEQ>) {
				chomp $line;
				next if $line =~ /^\s*$/;
				if ($line =~ /^>(\S+)/) {
					$name = $1;
					if ($distSeqStatus{$name}) {
						push @seqNames, $name;
					}					
				}else {
					$line =~ s/[\-\s]//g;
					if ($distSeqStatus{$name}) {
						$nameSeq{$name} .= $line;
					}
				}
			}
			close SEQ;
		}else {
			print "<div id='indent'>";
			print "<p>Couldn't retrieve the distance file for project ID of $projectId. It happens either the project had expired or the entered project ID was wrong.</p>";
			Divein::PrintFooter();
			exit;
		}
	}else {
		print "<div id='indent'>";
		print "<p>Couldn't retrieve the distance file for project ID of $projectId. It happens either the project had expired or the entered project ID was wrong.</p>";
		Divein::PrintFooter();
		exit;
	}	
}else {
	my $distFile_handle;
	if ($diveinFile) {
		$distFile_handle = $cgi->upload("diveinFile");
	}elsif ($userFile) {
		$distFile_handle = $cgi->upload("userFile");
	}elsif (($diveinExampleCb && $diveinExampleCb eq 'example') || ($userExampleCb && $userExampleCb eq 'example')) {
		my $distExampleFile = Divein::GetExample('tst_distfile.txt');
		open $distFile_handle, $distExampleFile or die "couldn't open sequence $distExampleFile file: $!\n";
	}
	$distFileLines = Divein::GetFileLines ($distFile_handle);
	if ($diveinFile) {
		for (my $i=0; $i<@$distFileLines; $i++) {
			my $line = $distFileLines->[$i];
			my @fields = split /\t/, $line;
			$distFileLines->[$i] = $fields[2]."\t".$fields[3]."\t".$fields[4];
		}
	}
	foreach my $line (@$distFileLines) {
		my @names = split /\t/, $line;
		for (my $i=0; $i<2; $i++) {
			if (!$distSeqStatus{$names[$i]}) {
				$distSeqStatus{$names[$i]} = 1;
			}
		}
	}
	my $seqFile_handle;
	if ($seqExampleCb && $seqExampleCb eq 'example') {
		my $exampleFile = Divein::GetExample('tst_seqFile.fas');
		open $seqFile_handle, $exampleFile or die "couldn't open sequence example file: $!\n";
	}else {
		$seqFile_handle = $cgi->upload("seqFile");
	}

	my $name = "";
	my $seqFileLines = Divein::GetFileLines ($seqFile_handle);
	foreach my $line (@$seqFileLines) {
		if ($line =~ /^>(\S+)/) {
			$name = $1;
			push @seqNames, $name;
			if (!$distSeqStatus{$name}) {
				print "<div id='indent'>";
				print "<p>No sequence name $name in pairwise distance file.</p>";
				Divein::PrintFooter();
				exit;
			}
		}else {
			$line =~ s/[\-\s]//g;
			$nameSeq{$name} .= $line;
		}
	}
	mkdir $uploadDir;
	chmod 0755, $uploadDir;
}

my $uploadDistFile = "$uploadDir/$id"."_tst_distance.txt";
my $uploadSeqFile = "$uploadDir/$id"."_tst_sequence.fas";
Divein::WriteFile ($uploadDistFile, $distFileLines);
open SEQ, ">", $uploadSeqFile or die "couldn't open $uploadSeqFile: $!\n";
foreach my $name (@seqNames) {
	print SEQ ">$name\n";
	print SEQ "$nameSeq{$name}\n";
}
close SEQ;

print "<div id='indent' align='center'>";
print "<h2>Two-Sample Tests: Please define sample sequences</h2>";


print "<form enctype='multipart/form-data' action=\"/cgi-bin/tst/tst.cgi\" name='grpForm' method='post' onsubmit=\"setAllTrue('mulselect'); return CheckSampleList('mulselect');\">";
print "<input type=hidden name='id' value=$id>";
print "<input type=hidden name='projectId' value=$projectId>";
print "<input type=hidden name='email' value=$email>";
print "<input type=hidden name='docuroot' value=$docuroot>";

print <<END_HTML;
<table align='center' border="0">
	<tr>
		<td align="center">Sample 1</td>
		<td align="center">Sequences</td>
		<td align="center">Sample 2</td>
	</tr>
<!--	<tr>
		<td align="center">Add group <input type="button" value="+" name="s1button" onclick="addGrp('sample1Grps', 'sample1group1', this.form.allSeqName)"></td>
		<td></td>
		<td align="center">Add group <input type="button" value="+" name="s2button" onclick="addGrp('sample2Grps', 'sample2group1', this.form.allSeqName)"></td>
	</tr>	-->
	<tr>
		<td valign="top">
			<table id="sample1Grps">
				<tr>
				<!--	<td><input type="button" value="-" onclick="rmGrp('sample1group1', this.form.allSeqName)"> group 1 </td>-->
					<td valign="top">
						<select class="mulselect" id="sample1group1" name="sample1group1" size="36" multiple>			
						</select>
					</td>
					<td align="center">
						<input type="button" value="&lt;--"
						 onclick="moveOptions(this.form.allSeqName, this.form.sample1group1);" /><br />
						<input type="button" value="--&gt;"
						 onclick="moveOptions(this.form.sample1group1, this.form.allSeqName);" />
					</td>
				</tr>
			</table>
		</td>
		<td valign="top">
			<select class="mulselect" id="allSeqName" name="allSeqName" size="36" multiple="multiple">
END_HTML
foreach my $name (@seqNames) {
	print "<option value=$name>$name</option>";
}
print <<END_HTML;
			</select>
		</td>
		<td valign="top">
			<table id="sample2Grps">
				<tr>
					<td align="center">
						<input type="button" value="--&gt;"
						 onclick="moveOptions(this.form.allSeqName, this.form.sample2group1);" /><br />
						<input type="button" value="&lt;--"
						 onclick="moveOptions(this.form.sample2group1, this.form.allSeqName);" />
					</td>					
					<td valign="top">
						<select class="mulselect" id="sample2group1" name="sample2group1" size="36" multiple>			
						</select>
					</td>
				<!--	<td>group 1 <input type="button" value="-" onclick="rmGrp('sample2group1', this.form.allSeqName)"></td>-->
				</tr>
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

