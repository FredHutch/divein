#!/usr/bin/perl -w

use CGI ':standard';
use CGI::Carp qw(fatalsToBrowser); 
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
my $id = $q->param('id');
my $file = $q->param('file');
my $ID = $id.$file;
my $uploadbase = $DiveinParam::uploadbase;
my $files_location = $uploadbase."/$id";
print $q->header;
if ($id !~ /^\d+$/ || $file !~ /^[\w\.]+$/) {
	print "Invalid input, process terminated.<br>";
	exit;
}
Divein::Print_header('cot', 'view');

print "<div id='indent'>";

if ($ID eq '') { 
	print "You must specify a file to view."; 
}elsif ($ID =~ /\.pdf$/) {
	print "<iframe src=\"https://divein.fredhutch.org/treeImages/$ID?#view=Fit\" width='800' height='600' >
		<p>Your browser doesn't support PDFs. <a href=\"https://divein.fredhutch.org/treeImages/$ID\">Download it here</a>.</p>
	</iframe>";
} else {
	open(DLFILE, "<", "$files_location/$ID") || Error('open', 'file'); 
	print "<pre>";
	while (my $line = <DLFILE>) {
		chomp $line;
		print "$line<br>";
	}
	close (DLFILE) || Error ('close', 'file'); 
}

Divein::PrintFooter();

sub Error {
	print "The server can't $_[0] the $_[1]: $! \n";
	exit;
}
