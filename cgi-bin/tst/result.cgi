#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
my $id = $q->param("id");
my $uploadbase = $DiveinParam::uploadbase;
my $uploadDir = $uploadbase."/$id";
my $logFile = "$uploadDir/$id"."_tst.log";
unless (-e $logFile) {
	$logFile = "$uploadDir/$id.log";
}

print $q->header;
if ($id !~ /^\d+$/) {
	print "Invalid input, process terminated.<br>";
	exit;
}
Divein::Print_header('tst', 'result');

print "<div id='indent'>";
print "<h2>Two-Sample Tests result</h2>";
    
print "<p>Your job id is $id.</p>";
print "<table board=0>";
if (-s $logFile) {
	my $t = my $df = my $Pt = my $Pz = 0;
	open LOG, $logFile or die "couldn't open $logFile: $!\n";
	while (my $line = <LOG>) {
		chomp $line;
		if ($line =~ /T=(\S+)/) {
			$t = $1;
		}elsif ($line =~ /df=(\S+)/) {
			$df = $1;
		}elsif ($line =~ /Z-test P=(\S+)/) {
			$Pz = $1;
		}elsif ($line =~ /T-test P=(\S+)/) {
			$Pt = $1;
		}
	}
	print "<tr><td>T score:</td><td>$t</td><tr>";
	print "<tr><td>Degrees of freedom:</td><td>$df</td><tr>";
	print "<tr><td>Z-test P value:</td><td>$Pz</td><tr>";
	print "<tr><td>T-test P value:</td><td>$Pt</td><tr>";
}

print "</table>";

Divein::PrintFooter();