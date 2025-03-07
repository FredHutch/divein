#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
my $id = $q->param("id");
my $datatype = $q->param("datatype");
my $uploadbase = $DiveinParam::uploadbase;
my $uploadDir = $uploadbase."/$id";

print $q->header;
if ($id !~ /^\d+$/ || ($datatype ne 'nt' && $datatype ne 'aa')) {
	print "Invalid input, process terminated.<br>";
	exit;
}

Divein::Print_header('insites', 'result');

print "<div id='indent' align='center'>";
print "<h2>Informative sites result</h2>";
    
print "<p>Your job id is $id. Please check results by clicking following links:</p>";
print "<table board=0 cellspacing=10>";
if (-s $uploadDir.'/'.$id.'.aln') {
	print "<tr><td align=right>Alignment display:</td><td><a href=view.cgi?id=$id&ext=.aln&datatype=$datatype target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=.aln>download</a></td></tr>";
}
if (-s $uploadDir.'/'.$id.'_uniq.aln') {
	print "<tr><td align=right>Alignment display of unique sequences:</td><td><a href=view.cgi?id=$id&ext=_uniq.aln&datatype=$datatype target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_uniq.aln>download</a></td></tr>";
}
if (-s $uploadDir.'/'.$id.'_var.aln') {
	print "<tr><td align=right>Aligned variable sites:</td><td><a href=view.cgi?id=$id&ext=_var.aln&datatype=$datatype target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_var.aln>download</a></td></tr>";
	print "<tr><td align=right>Tab delimited variable sites:</td><td><a href=view.cgi?id=$id&ext=_var.txt target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_var.txt>download</a></td></tr>";	
}
if (-s $uploadDir.'/'.$id.'_info.aln') {
	print "<tr><td align=right>Aligned informative sites:</td><td><a href=view.cgi?id=$id&ext=_info.aln&datatype=$datatype target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_info.aln>download</a></td></tr>";
	print "<tr><td align=right>Tab delimited informative sites & summary:</td><td><a href=view.cgi?id=$id&ext=.txt target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=.txt>download</a></td></tr>";	
}else {
	print "<tr><td align=right>Aligned informative sites:</td><td>None</a></td></tr>";
	print "<tr><td align=right>Tab delimited informative sites & summary:</td><td>None</a></td></tr>";
}	
if (-s $uploadDir.'/'.$id.'_priv.aln') {
	print "<tr><td align=right>Aligned private sites:</td><td><a href=view.cgi?id=$id&ext=_priv.aln&datatype=$datatype target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_priv.aln>download</a></td></tr>";
	print "<tr><td align=right>Tab delimited private sites & summary:</td><td><a href=view.cgi?id=$id&ext=_priv.txt target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_priv.txt>download</a></td></tr>";	
}else {
	print "<tr><td align=right>Aligned private sites:</td><td>None</a></td></tr>";
	print "<tr><td align=right>Tab delimited private sites & summary:</td><td>None</a></td></tr>";
}
if (-s $uploadDir.'/'.$id.'_ambi.aln') {
		print "<tr><td align=right>Tab delimited ambiguity sites:</td><td><a href=view.cgi?id=$id&ext=_ambi.txt target=_blank>view</a></td>";
		print "<td><a href=download.cgi?id=$id&ext=_ambi.txt>download</a></td></tr>";	
	}
print "<tr><td align=right>Tab delimited alignment summary:</td><td><a href=view.cgi?id=$id&ext=_aln.txt target=_blank>view</a></td>";
print "<td><a href=download.cgi?id=$id&ext=_aln.txt>download</a></td></tr>";
print "</table>";

Divein::PrintFooter();