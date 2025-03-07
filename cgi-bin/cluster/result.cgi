#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;

my $id = $q->param('id');
my $uploadbase = $DiveinParam::uploadbase;
my $uploadDir = $uploadbase."/$id";

print $q->header;
if ($id !~ /^\d+$/) {
	print "Invalid ID, process terminated.<br>";
	exit;
}
Divein::Print_header('cluster', 'result');

print "<div id='indent'>";
print "<h2>Sequence clustering result</h2>";
print "<p>Parameter settings for the job id of $id:</p>";
print "<table board=0>";
my $parameterFile = $uploadDir."/".$id.".log";
open PARA, $parameterFile or die "couldn't open $parameterFile: $!\n";
while (my $line = <PARA>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	my ($first, $second) = split /:\s+/, $line;
	if ($first eq 'filename') {
		print "<tr><td align=left width=460>Input file:</td><td align=left>$second</td></tr>";
	}elsif ($first eq 'method') {
		my ($para, $value) = split /\=/, $second;
		if ($value eq 'tn93') {
			$value = 'TN93';
		}else {
			$value = 'Phylogenetic tree branch lengths';
		}
		print "<tr><td align=left width=460>Distance calculation method:</td><td align=left>$value</td></tr>";
	}elsif ($first eq 'min-cluster-size') {
		my ($para, $value) = split /\=/, $second;
		print "<tr><td align=left width=460>Minimal clustering size:</td><td align=left>$value</td></tr>";
	}elsif ($first eq 'distance-threshold') {
		my ($para, $value) = split /\=/, $second;
		print "<tr><td align=left width=460>Distance threshold:</td><td align=left>$value</td></tr>";
	}
}
close PARA;
print "</table>";
print "<hr>";
print "<p>Please click <a href=download.cgi?id=$id&file=_output.csv class='blue'>here</a> to download the clustering result.</p>";
print "<p>Please click <a href=download.cgi?id=$id&file=_distance_cutoff.csv class='blue'>here</a> to download the distance file (less than distance threshold).</p>";

Divein::PrintFooter();
