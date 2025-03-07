#!/usr/bin/perl -w

use CGI ':standard';
use CGI::Carp qw(fatalsToBrowser); 
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
print $q->header;

my $id = $q->param('id');
my $ext = $q->param('ext');
my $datatype = $q->param('datatype');
if ($id !~ /^\d+$/ || $ext !~ /^[\w\.]+$/ || ($datatype && $datatype ne 'nt' && $datatype ne 'aa')) {
	print "Invalid input, process terminated.<br>";
	exit;
}
my $uploadbase = $DiveinParam::uploadbase;
my $ID = $id.$ext;
my $files_location = $uploadbase."/$id";

Divein::Print_header('insites', 'view');
print "<div id='indent'>";

if ($ID eq '') { 
	print "You must specify a file to view."; 
} else {
	open(DLFILE, "<", "$files_location/$ID") || Error('open', 'file'); 
	print "<table class='font' border=0 cellspacing=3>";
	print "<pre style='font-size: 11px;'>";
	while (my $line = <DLFILE>) {
		chomp $line;
		if ($ID =~ /\.aln$/) {
			if ($datatype eq "nt") {
				if ($line =~ /^(\S+)(\s+)(\S+)$/) {
					my $name = $1.$2;
					my $seq = $3;
					my @nts = split //, $seq;
					print "$name";
					foreach my $nt (@nts) {
						printNt ($nt);
					}
					print "<br>";
				}else {
					print "$line<br>";
				}
			}else {
				print "$line<br>";
			}		
		}else {
			my @fields = split /\t/, $line;
			print "<tr>";
			foreach my $field (@fields) {			
				print "<td align=right>$field</td>";
			}
			print "</tr>";
		}	
	
	}
	print "</table>";
	close (DLFILE) || Error ('close', 'file'); 
}

Divein::PrintFooter();

sub Error {
	print "The server can't $_[0] the $_[1]: $! \n";
	exit;
}

sub printNt {
	my $nt = shift;
	if ($nt eq "A") {
		print "<font color=red>A</font>";
	}elsif ($nt eq "C") {
		print "<font color=green>C</font>";
	}elsif ($nt eq "G") {
		print "<font color=CC9900>G</font>";
	}elsif ($nt eq "T") {
		print "<font color=blue>T</font>";
	}else {
		print "$nt";
	}
}
