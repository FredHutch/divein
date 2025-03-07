#!/usr/bin/perl -w

use strict;
use CGI ':standard';
use CGI::Carp qw(fatalsToBrowser); 
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;

my $id = param('id');
my $file = param('file');
if ($id !~ /^\d+$/ || $file !~ /^[\w\.]+$/) {
	Error('open', 'file');
}
my $ID = $id.$file; 
my $uploadbase = $DiveinParam::uploadbase;
my $files_location = "$uploadbase/$id";

my @fileholder;
if ($ID eq '') { 
	print "Content-type: text/html\n\n"; 
	print "You must specify a file to download."; 
} else {
	my $date = gmtime;
	open(DLFILE, "<", "$files_location/$ID") || Error('open', 'file'); 
	@fileholder = <DLFILE>; 
	close (DLFILE) || Error ('close', 'file'); 
	
	print "Content-Type:application/x-download\n"; 
	print "Content-Disposition:attachment;filename=$ID\n\n";
	print @fileholder
}

sub Error {
    print "Content-type: text/html\n\n";
	print "The server can't $_[0] the $_[1]: $! \n";
	exit;
}
