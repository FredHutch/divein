#!/usr/bin/perl -w

######################################################################################################
# This script takes MacClade alignment nexus file or phylip file, difined outgroup sequence name file
# and ingroup file as input, tranfers nexus file to phylip file if necessary, runs phyml
# program, difines MRCA from phyml output tree file using HYPHY, removes outgroup sequences 
# from original phylip file and adds MRCA sequence. run phyml again to get distance matrix,
# calculate divergence and diversity in tree based and/or pairwise distance based as user difined.
# Author: Wenjie Deng
# Date: 2007-01-12
# version: 1.0.1
# Modified for docker container: 2025-3
######################################################################################################

use strict;
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use Divein;
use Cluster;
use DiveinParam;

my ($file, $method, $output, $distout, $minclustersize, $distcutoff, $filename, $email, $id, $uploadDir, $ip, $docsRoot);
BEGIN {
	$file           = shift;	
	$method         = shift;	
	$output         = shift;	
	$distout        = shift;
	$minclustersize = shift;	
	$distcutoff     = shift;	
	$filename       = shift;
	$email          = shift;
	$id             = shift;	
	$uploadDir      = shift;		
	$ip             = shift;
	$docsRoot       = shift;
}

my $startTime = time();
my $logFile = $uploadDir.'/'.$id.'.log';
my $errFile = $uploadDir.'/'.$id.'.err';
open (LOG, ">", $logFile) or die Cluster::SendEmail ($email, $id, "Error", "Couldn't open $logFile: $!\n");
print LOG "Project: Cluster\nid: $id\nfilename: $filename\ninputfile: $file\nmethod: $method\noutput: $output\n";
print LOG "min-cluster-size: $minclustersize\ndistance-threshold: $distcutoff\nemail: $email\nIP: $ip\nuploadDir: $uploadDir\n";

my $cmdlogfile = $uploadDir.'/'.$id.'_command.log';
my @cmd = ();
my $cluster_tool = "cluster-tool";
push @cmd, $cluster_tool, $file, $method, $output, $distout, $minclustersize, $distcutoff, "1>$cmdlogfile", "2>$errFile";
my $cmdline = join(" ", @cmd);
print LOG "commandline: $cmdline\n";

system($cmdline);

# retrieve distance matrix that distances are fewer than user defined cutoff
$distcutoff =~ /\-\-distance-threshold=(.*)/;
my $cutoff = $1;
$distout =~ /\-\-distance=(.*)/;
my $distfile = my $distcutofffile = $1;
$distcutofffile =~ s/\.csv/_cutoff.csv/;
open IN, $distfile or die "couldn't open $distfile: $!\n";
open OUT, ">", $distcutofffile or die "couldn't open $distcutofffile: $!\n";
while (my $line = <IN>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	my @fields = split /\,/, $line;
	my $dist = $fields[2];
	if ($line eq "id1,id2,distance" or $dist <= $cutoff) {
		print OUT "$line\n";
	}
}
close IN;
close OUT;

#create a file to indicate the status of the finished job.
open TOGGLE, ">", "$uploadDir/toggle" or die "couldn't create file toggle\n";
close TOGGLE;

my $endTime = time();
my $timestamp = $endTime - $startTime;
my $duration = Divein::GetDuration_dhms ($timestamp);
print LOG "Duration: $duration\n";
close LOG;

my $finishTime = localtime();
chomp $finishTime;
my $statDir = $DiveinParam::statsbase;
unless (-e $statDir) {
	mkdir $statDir;
	chmod 0777, $statDir;
}
my $statFile = "$statDir/cluster.stat";
open STAT, ">>", $statFile or die "couldn't open $statFile: $!\n";
print STAT "$finishTime\t$id\t$file\t$method\t$output\t$minclustersize\t$distcutoff\t$ip\t$email\t$duration\n";
close STAT;

Cluster::SendEmail ($email, $id, 'Success', 'Normal', $uploadDir, $filename);

exit (0);
