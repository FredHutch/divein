#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
print $q->header;
Divein::Print_header('diver', '');

print "<div id='indent' align='center'>";

my $jobid = $q->param('id');
my $file = $q->param('file');
my $ID = $jobid.$file;
my $chart_type = $q->param('chart_type');
my $uploadbase = $DiveinParam::uploadbase;
my $files_location = "$uploadbase/$jobid";
my $inFile = $files_location."/".$ID;
my $outFileName = $jobid."_chart.txt";
my $outFile = $files_location."/".$outFileName;
my @disArr;
my $records = 0;

open IN, "<", $inFile or die "Couldn't open $inFile: $!\n";
open OUT, ">", $outFile or die "Couldn't open $outFile: $!\n";

my @pos;
while (my $line = <IN>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	if ($records) {
		my ($group, $seqcount, $diver, $stderr) = split /\t/, $line;
		print OUT "$records\t$group\t$diver\t$stderr\n";
		my $pos = "'".$group."' ".$records;
		push @pos, $pos;
	}
	$records++;
}
close IN;
close OUT;

my $shell_script = $files_location."/".$jobid.".sh";
my $pngFileName = $jobid."_chart.png";
my $pngFile = $files_location."/".$pngFileName;
open SHELL, ">", $shell_script or die "Couldn't open $shell_script: $!\n";

print SHELL "set terminal png\n";
print SHELL "set output '".$pngFile."'\n";
print SHELL "set datafile separator '\t'\n";
print SHELL "set title '".$chart_type." Chart' font '/usr/share/fonts/bitstream-vera/Vera.ttf, 20'\n";
print SHELL "set xlabel 'Group' font '/usr/share/fonts/bitstream-vera/Vera.ttf, 16'\n";
print SHELL "set ylabel '".$chart_type."' font '/usr/share/fonts/bitstream-vera/Vera.ttf, 16'\n";
print SHELL "set xrange [0:".$records."]\n";
print SHELL "set xtics font '/usr/share/fonts/bitstream-vera/Vera.ttf, 10'\n";
print SHELL "set ytics nomirror font '/usr/share/fonts/bitstream-vera/Vera.ttf, 10'\n";
print SHELL "set xtics (".join (', ', @pos).")\n";
print SHELL "set xtics nomirror rotate by -45\n";
print SHELL "plot '".$outFile."' u 1:3:4 notitle w errorbars lt -1, '' u 1:3 notitle w linespoints lt -1 pt 7\n";

close SHELL;

system ("gnuplot", $shell_script);

print "<div>";
print "<img src='/cgi-bin/getimage.cgi?image=$pngFile'>";
print "</div>";

print "<form action=download.cgi method=post>";
print "<input type=hidden name=id value=$jobid>";
print "<input type=hidden name=file value='_chart.png'>";
print "<p>&nbsp;&nbsp;&nbsp;<input type=submit name=png value='Save chart'>";
print "</form>";

Divein::PrintFooter();
