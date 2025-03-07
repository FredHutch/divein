#!/usr/bin/perl -w

use strict;
use CGI;

my $q = new CGI;
print "Content-type: image/png\n\n";
my $imagefile = $q->param('image');
open IMAGE, $imagefile;
binmode IMAGE;
print while <IMAGE>;
close IMAGE;
