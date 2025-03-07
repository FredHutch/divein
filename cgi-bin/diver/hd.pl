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
######################################################################################################

use strict;
use warnings;
use v5.10;
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use Divein;
use Diver;
use Diver::DiverEmail;

my ($id, $seqFileName, $email, $uploadDir, $ip, $docsRoot, $program);
BEGIN {
	$id             = shift;	# job id
	$seqFileName    = shift;	# name of user uploaded sequence alingment file
	$email          = shift;
	$uploadDir      = shift;	# directory for uploading files	
	$ip             = shift;
	$docsRoot       = shift;
	$program		= shift;
}

my $startTime = time();
my $logFile = $uploadDir.'/'.$id.'.log';
my $errFile = $uploadDir.'/'.$id.'.err';
my $errLog;
open $errLog, ">", $errFile or die "couldn't open $errFile: $!\n";
open (LOG, ">", $logFile) or die Diver::DiverEmail::SendEmail ($email, $id, "Error", "Couldn't open $logFile: $!\n");
print LOG "Project: $program\nid: $id\nseqFileName: $seqFileName\n";
print LOG "email: $email\nIP: $ip\nuploadDir: $uploadDir\n";

my $parameterFile = $uploadDir.'/'.$id.'.parameters.txt';
open PARA, ">", $parameterFile or die Diver::DiverEmail::SendEmail ($email, $id, "Error", "Couldn't open $parameterFile: $!\n");
printf PARA ("%-45s%s%s", 'Input alignment sequence file:', $seqFileName, "\n");
printf PARA ("%-45s%s%s", 'Calculate diversity based on:', 'Pairwise hamming distance', "\n");
close PARA;

my $uploadFile = $uploadDir.'/'."$id.sequence.txt";	# uploaded sequence file name
my $uploadgrpFile = $uploadDir.'/'."$id.group.txt";	# uploaded ingroup file name if any

my $phylipFile = $uploadFile;
my $fastaFile = $phylipFile.'.fas';
my ($seqCount, $seqLen, $nameSeq) = Divein::ChangetoFasta($phylipFile, $fastaFile);
my ($grpStatus, $groups, $grpSeqs) = Diver::GetGrpSeqStatus($uploadgrpFile);

my @seqNames = my %hdDistHash = ();
open GRP, "<", $uploadgrpFile or die "couldn't open $uploadgrpFile: $!\n";
while (my $line = <GRP>) {
	$line =~ s/\R$//;
	next if $line =~ /^\s*$/;
	my ($grp, $name) = split /\t/, $line;
	push @seqNames, $name;
}
close GRP;

while (@seqNames) {	
	my $firstname = shift @seqNames;
	my $seq = $nameSeq->{$firstname};
	my @seqNas = split //, $seq;
	$seq =~ s/\-//g;
	my $seqlen = length $seq;			
	foreach my $restname (@seqNames) {
		my $hdist = 0;
		my $restseq = $nameSeq->{$restname};
		my @restNas = split //, $restseq;
		for (my $i = 0; $i < $seqLen; $i++) {
			if ($seqNas[$i] =~ /[A-Z]/ and $restNas[$i] =~ /[A-Z]/) {
				if ($seqNas[$i] ne $restNas[$i]) {
					++$hdist;
				}
			}
		}
		$restseq =~ s/\-//g;
		my $minlen = length $restseq;
		if ($seqlen < $minlen) {
			$minlen = $seqlen;
		}
		my $nhdist = $hdist / $minlen;
		$hdDistHash{$firstname}{$restname} = $hdDistHash{$restname}{$firstname} = int($nhdist * 1000000 + 0.5) / 1000000;
		#$hdDistHash{$firstname}{$restname} = $hdDistHash{$restname}{$firstname} = $nhdist;
	}
}

# write column distance file 
my $hdColDistFile = $uploadDir.'/'.$id.'_pwcoldist.txt';	# column hamming distance file
Diver::WriteColumnDistFile ($groups, $grpSeqs, $hdColDistFile, \%hdDistHash, "", $errLog, $grpStatus);
# calculate diversity and write to file
my $hdDiversityFile = $uploadDir.'/'.$id.'_pwdiversity.txt';
Diver::CalculateDiversity ($hdDiversityFile, $groups, $grpSeqs, \%hdDistHash, $errLog);
if (@$groups > 1) {	# more than one groups
	my $hdBtGrpDistFile = $uploadDir.'/'.$id.'_pwBtGrpDist.txt';
	Diver::CalculateBtwDist ($hdBtGrpDistFile, $groups, $grpSeqs, \%hdDistHash, $errLog);
}

#create a file to indicate the status of the finished job.
open TOGGLE, ">", "$uploadDir/toggle" or die "couldn't create file toggle\n";
close TOGGLE;

my $endTime = time();
my $timestamp = $endTime - $startTime;
my $duration = Divein::GetDuration_dhms ($timestamp);
print LOG "Duration: $duration\n";
close LOG;
close $errLog;

my $finishTime = localtime();
chomp $finishTime;
my $statDir = $docsRoot."/stats";
unless (-e $statDir) {
	mkdir $statDir;
	chmod 0775, $statDir;
}
my $statFile = "$statDir/diver.stat";
open STAT, ">>", $statFile or die "couldn't open $statFile: $!\n";
print STAT "$finishTime\t$id\t$seqCount\t$seqLen\t\t\t\t$ip\t$email\t$duration\t$program\n";
close STAT;

Diver::DiverEmail::SendEmail ($email, $id, 'Success', 'Normal', '', '', $uploadDir, $seqFileName, '', $program);

exit (0);



