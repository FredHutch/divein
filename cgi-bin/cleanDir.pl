#!/usr/bin/perl

use strict;
use File::Path;

my $dir = '/var/www/html/outputs';
opendir DIR, $dir;
while (my $subdir = readdir DIR) {
	next if $subdir =~ /^\./;
	$subdir = $dir.'/'.$subdir;
	my $rmflag = 0;
	if (-d $subdir) {
		opendir SUBDIR, $subdir;
		while (my $file = readdir SUBDIR) {
			if ($file eq "toggle") {
				my $togglefile = $subdir."/toggle";
				if((-f $togglefile) && (-M $togglefile > 5)) {
					$rmflag = 1;
					last;
				}
			}
		}
		closedir SUBDIR;
		if ($rmflag) {
			rmtree($subdir);
			#print "$subdir has been removed.\n";
		}
	}	
}
closedir DIR;


