#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
my $id = $q->param("id");
my $treeRadio = $q->param("treeRadio");
my $uploadbase = $DiveinParam::uploadbase;
my $uploadDir = $uploadbase."/$id";

print $q->header;
if ($id !~ /^\d+$/ || ($treeRadio ne 'yes' && $treeRadio ne 'no')) {
	print "Invalid input, process terminated.<br>";
	exit;
}
Divein::Print_header('cot', 'result');

print "<div id='indent' align='center'>";
print "<h2>Center of tree result</h2>";
    
print "<p>Your job id is $id. Please check results by clicking following links:</p>";
print "<table board=0 cellspacing=10>";

if ($treeRadio eq "no") {
	print "<tr><td align=right>MLE tree:</td><td><a href=view.cgi?id=$id&file=.sequence_stripgap.txt_fasttree_tree.pdf class='blue' target=_blank>view</a>";
	print "<td><a href=download.cgi?id=$id&file=.sequence_stripgap.txt_fasttree_tree.tre class='blue'>download</a></td></tr>";
	print "<tr><td align=right>ML parameters:</td><td><a href=view.cgi?id=$id&file=.sequence_stripgap.txt.fasttree.log class='blue' target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&file=.sequence_stripgap.txt.fasttree.log class='blue'>download</a></td></tr>";
}

print "<tr><td align=right>COT rooted tree:</td><td><a href=view.cgi?id=$id&file=.cot.pdf class='blue' target=_blank>view</a>";
print "<td><a href=download.cgi?id=$id&file=.cot.tre class='blue'>download</a></td></tr>";
print "<tr><td align=right>COT sequence:</td><td><a href=view.cgi?id=$id&file=.cot.fas class='blue' target=_blank>view</a></td>";
print "<td><a href=download.cgi?id=$id&file=.cot.fas class='blue'>download</a></td></tr>";
print "</table>";
Divein::PrintFooter();
