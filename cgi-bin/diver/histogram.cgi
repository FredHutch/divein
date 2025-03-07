#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser); 
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
my $jobid = $q->param('id');
my $file = $q->param('file');
my $binNum = $q->param('binBox');
my $disRadio = $q->param('radio');
$binNum =~ s/^\s+// if $binNum =~ /^\s+/;
$binNum =~ s/\s+$// if $binNum =~ /\s+$/;
print $q->header();
if ($jobid !~ /^\d+$/ || $file !~ /^[\w\.]+$/ || $binNum !~ /^\d+$/) {
	print "Invalid input, process terminated.<br>";
	exit;
}
Divein::Print_header('diver', '');

print "<div id='indent' align='center'>";

my $ID = $jobid.$file;
my $uploadbase = $DiveinParam::uploadbase;
my $files_location = "$uploadbase/$jobid";
my $inFile = $files_location."/".$ID;
my @disArr;
my $records = 0;

open IN, "<", $inFile or die "Couldn't open $inFile: $!\n";
while (my $line = <IN>) {
	chomp $line;
	unless ($line =~ /^\s*$/) {
		my @fields = split /\t/, $line;
		unless ($fields[0] eq 'MRCA' || $fields[1] eq 'MRCA') {
			push @disArr, $fields[4];
		}		
	}
}
close IN;
@disArr = sort {$a <=> $b} @disArr;
my $arrSize = scalar @disArr;
my ($minDist, $maxDist, $outFileName, $outFile, $shell_script, $pngFileName, $pngFile, $pngFileExt, $outFileExt);
if ($disRadio eq 'define') {
	$minDist = $q->param('mindist');
	$maxDist = $q->param('maxdist');
	$minDist =~ s/^\s+// if $minDist =~ /^\s+/;
	$maxDist =~ s/^\s+// if $maxDist =~ /^\s+/;
	$minDist =~ s/\s+$// if $minDist =~ /\s+$/;
	$maxDist =~ s/\s+$// if $maxDist =~ /\s+$/;	
	if ($minDist !~ /^[\d\.]+$/ || $maxDist !~ /^[\d\.]+$/) {
		print "Invalid input, process terminated.<br>";
		exit;
	}
	$outFileName = $jobid.'_histogram_'.$binNum.'.txt';
	$outFileExt = '_histogram_'.$binNum.'.txt';
	$outFile = $files_location.'/'.$outFileName;
	$shell_script = $files_location.'/'.$jobid.'_histogram_'.$binNum.'.sh';
	$pngFileName = $jobid.'_histogram_'.$binNum.'.png';
	$pngFileExt = '_histogram_'.$binNum.'.png';
	$pngFile = $files_location.'/'.$pngFileName;
}else {
	$minDist = $disArr[0];
	$maxDist = $disArr[$#disArr];
	$outFileName = $jobid.'_histogram_auto_'.$binNum.'.txt';
	$outFileExt = '_histogram_auto_'.$binNum.'.txt';
	$outFile = $files_location.'/'.$outFileName;
	$shell_script = $files_location.'/'.$jobid.'_histogram_auto_'.$binNum.'.sh';
	$pngFileName = $jobid.'_histogram_auto_'.$binNum.'.png';
	$pngFileExt = '_histogram_auto_'.$binNum.'.png';
	$pngFile = $files_location.'/'.$pngFileName;
}

my $interval = ($maxDist - $minDist) / $binNum;

open OUT, ">", $outFile or die "Couldn't open $outFile: $!\n";
for (my $i = 0; $i < $binNum; $i++) {
	my $match = 0;
	foreach my $dis (@disArr) {
		if ($dis <= $minDist + ($i+1)*$interval) {
			if ($i == 0) {
				if ($dis >= $minDist) {
					$match++;
					$records++;
				}
			}else {
				if ($dis > $minDist + $i*$interval) {
					$match++;
					$records++;
				}
			}
		}
	}
	my $percentage = $match / $arrSize;
	my $disInterval = int (($minDist + $i * $interval) * 1000000 + 0.5) / 1000000;
	print OUT "$disInterval\t$percentage\n";
}

close OUT;

open SHELL, ">", $shell_script or die "Couldn't open $shell_script: $!\n";
print SHELL "set terminal png\n";
print SHELL "set output \"".$pngFile."\"\n";
print SHELL "set datafile separator '\t'\n";
print SHELL "set title \"Distance Histogram\" font \"/usr/share/fonts/bitstream-vera/Vera.ttf, 20\"\n";
print SHELL "set xlabel \"Distance\" font \"/usr/share/fonts/bitstream-vera/Vera.ttf, 16\"\n";
print SHELL "set ylabel \"Frequency\" font \"/usr/share/fonts/bitstream-vera/Vera.ttf, 16\"\n";
print SHELL "set xrange [0:*]\n";
print SHELL "set style data histogram\n";
print SHELL "set style fill solid\n";
print SHELL "set xtics scale 0 font \"/usr/share/fonts/bitstream-vera/Vera.ttf, 10\"\n";
print SHELL "set ytics nomirror font \"/usr/share/fonts/bitstream-vera/Vera.ttf, 10\"\n";
print SHELL "set xtics nomirror rotate by -90\n";
if ($binNum <= 25) {
	print SHELL "plot \"".$outFile."\" u 2:xtic(1) notitle linecolor rgb 'black'\n";
}else {
	my @lvPos;
	my $folds = $binNum / 25;
	for (my $i = 0; $i <= 25; $i++) {
		my $xlabel = int (($minDist + $interval * $folds * $i) * 1000000 + 0.5) / 1000000;
		my $lvPos = "'".$xlabel."' ".$i * $folds;
		push @lvPos, $lvPos;
	}
	print SHELL "set xtics (".join (', ', @lvPos).")\n";
	print SHELL "plot \"".$outFile."\" u 2 notitle linecolor rgb 'black'\n";
}
close SHELL;

system ("gnuplot", $shell_script);

print "<div>";
print "<img src='/cgi-bin/getimage.cgi?image=$pngFile'>";
print "</div>";

print "<form name=png action=download.cgi method=post>";
print "<input type=hidden name=id value=$jobid>";
print "<input type=hidden name=file value=$pngFileExt>";
print "<input type=hidden name=file value=$outFileExt>";
print "<p>&nbsp;&nbsp;&nbsp;<input type=submit name=png value='Save histogram'>";
print "&nbsp;&nbsp;&nbsp;<input type=submit name=data value='Download dataset'></p>";
print "</form>";

Divein::PrintFooter();
