#!/usr/bin/perl

use strict;
use CGI ':standard';
use CGI::Carp qw(fatalsToBrowser); 
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
my $id = $q->param('id');
my $file = $q->param('file');
my $chart_type = $q->param('chart_type');
my $ID = $id.$file;
my $uploadbase = $DiveinParam::uploadbase;
my $files_location = $uploadbase."/$id";
my $docuroot = $DiveinParam::documentroot;

print $q->header;
if ($id !~ /^\d+$/ || $file !~ /^[\w\.]+$/ || ($chart_type && $chart_type !~ /^[A-Za-z]+$/)) {
	print "Invalid input, process terminated.<br>";
	exit;
}
Divein::Print_header('diver', 'view');
print "<div id='indent'>";
if ($ID eq '') { 
	print "You must specify a file to view."; 
}elsif ($ID =~ /\.pdf$/) {
	print "<iframe src=\"https://divein.fredhutch.org/treeImages/$ID?#view=Fit\" width='800' height='600' >
		<p>Your browser doesn't support PDFs. <a href=\"https://divein.fredhutch.org/treeImages/$ID\">Download it here</a>.</p>
	</iframe>";
}else {
	if ($chart_type && $chart_type eq "histogram") {
		print "<div>";
		print "<form action='histogram.cgi' name='histogramForm' method='post' onSubmit='return checkHistForm(this);' target=_blank>";		
		print "<p>&nbsp;Bins:&nbsp;<input type=text id=binBox name=binBox size=6 value=100></p>";		
		print "<p><input type=radio name=radio value=auto checked=true onclick=\"DistText('disable', this.form)\">Auto distance range</p>";
		print "<p><input type=radio name=radio value=define onclick=\"DistText('enable', this.form)\">Define distance range";
		print "&nbsp;&nbsp;&nbsp;Min: <input type=text id=mindist name=mindist size=6 disabled=true>";
		print "&nbsp;&nbsp;&nbsp;Max: <input type=text id=maxdist name=maxdist size=6 disabled=true></p>";
		print "<p><input type='submit' name='submit' value='Draw histogram'></p>";
		print "<input type=hidden name=id value=$id>";
		print "<input type=hidden name=file value=$file>";
		print "</form></div></div><hr><div id='indent'>";
		print "</form></div></div><div id='indent'>";
	}
	print "<table border=0 cellspacing=5 style='font-size: 10px'>";
	open(DLFILE, "<", "$files_location/$ID") || Error('open', 'file'); 
	
	my $line_count = 0;
	print "<pre>";
	while (my $line = <DLFILE>) {
		chomp $line;
		if ($ID =~ /\.fas$/ || $ID =~ /_stats?\.txt$/ || $ID =~ /parameters.txt$/ || $ID =~ /.log$/) {
			print "$line<br>";
		}else {
			my @fields = split /\t/, $line;
			print "<tr>";
			foreach my $field (@fields) {			
				print "<td >$field</td>";
			}
			print "</tr>";
		}
		
		$line_count++;
	}
	print "</table>";
	close (DLFILE) || Error ('close', 'file'); 
	
	if ($chart_type && $chart_type =~ /^Diver/ && $line_count > 2) {
		print "<div>";
		print "<form action='diver_chart.cgi' method='post' target=_blank>";
		print "<p>&nbsp;<input type='submit' name='submit' value='Draw $chart_type chart'>";
		print "<input type=hidden name=id value=$id>";
		print "<input type=hidden name=file value=$file>";
		print "<input type=hidden name=chart_type value=$chart_type>";
		print "</form></div>";
	}	
}

Divein::PrintFooter();

sub Error {
	print "The server can't $_[0] the $_[1]: $!";
	exit;
}
