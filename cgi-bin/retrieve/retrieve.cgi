#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q =  new CGI;
my $uploadbase = $DiveinParam::uploadbase;
my $id = $q->param("projectId");
if ($id !~ /^\d+$/) {
	print "Content-type: text/html\n\n";
	print "Invalid input, process terminated.<br>";
	exit;
}
$id = Divein::CleanString($id);
my $uploadDir = $uploadbase."/$id";

if (-e $uploadDir) {
	my $logFile = "$uploadDir/$id.log";
	my ($project, $localDir, $uploadDir, $type, $format, $treeRadio, $datatype);
	my $diverseqNames = '';
	open LOG, $logFile or die "couldn't open $logFile: $!\n";
	while (my $line = <LOG>) {
		chomp $line;
		next if $line =~ /^\s*$/;
		if ($line =~ /Project: (\S+)/) {
			$project = $1;
		}
		if ($line =~ /uploadDir: (\S+)/) {
			$uploadDir = $1;
		}
		if ($project eq 'fasttree' or $project eq 'raxml' or $project eq 'phyml') {
			if ($line =~ /^type: (\S+)/) {
				$type = $1;
			}elsif ($line =~ /diverFormat: (\S+)/ or $line =~ /diver: (\S+)/) {
				$format = $1;
			}elsif ($line =~ /divergences: (\S+)/) {
				$diverseqNames = $1;
			}
		}elsif ($project eq 'cot') {
			if ($line =~ /treeRadio: (\S+)/) {
				$treeRadio = $1;
			}
		}elsif ($project eq 'insites') {
			if ($line =~ /datatype: (\S+)/) {
				$datatype = $1;
			}
		}
	}
	close LOG;
	if ($project eq 'fasttree' or $project eq 'raxml' or $project eq 'phyml' or $project eq 'hd') {
		print $q->redirect(-URL => "/cgi-bin/diver/result.cgi?id=$id&type=$type&format=$format&diverseqNames=$diverseqNames&program=$project");
	}elsif ($project eq 'cot') {
		print $q->redirect(-URL => "/cgi-bin/cot/result.cgi?id=$id&treeRadio=$treeRadio");
	}elsif ($project eq 'insites') {
		print $q->redirect(-URL => "/cgi-bin/insites/result.cgi?id=$id&datatype=$datatype");
	}elsif ($project eq 'tst') {
		print $q->redirect(-URL => "/cgi-bin/tst/result.cgi?id=$id");
	}elsif ($project eq 'Cluster') {
		print $q->redirect(-URL => "/cgi-bin/cluster/result.cgi?id=$id");
	}
}else {
	print $q->header;	
	Divein::Print_header('retrieve', 'result');	
	print "<div id='indent'>";
	print "<h2>Retrieve results</h2>";
	print "Couldn't retrieve your results. It happens either the project had expired or the entered project id was wrong.<br>";
}

Divein::PrintFooter();