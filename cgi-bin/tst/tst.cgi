#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $cgi =  new CGI;
my ($remoteIP) = Divein::GetInfo();
print $cgi->header;
Divein::Print_header('tst', 'process');

print "<div id='indent'>";
print "<h2>Two-Sample Tests result</h2>";

my $id = $cgi->param("id");
my $projectId = $cgi->param("projectId");
my $uploadbase = $DiveinParam::uploadbase;
my $uploadDir = $uploadbase."/$id";
my $email = $cgi->param("email");
my $docuroot = $cgi->param("docuroot");

my @sample1Grps = my @sample2Grps = ();
my @selects = $cgi->param;
foreach my $select (@selects) {
	my @seqs = $cgi->param($select);
	if ($select =~ /sample1/) {
		push @sample1Grps, \@seqs;
	}elsif ($select =~ /sample2/) {
		push @sample2Grps, \@seqs;
	}
}

my $uploadSeqFile = $uploadDir."/$id"."_tst_sequence.fas";
my $uploadDistFile = $uploadDir."/$id"."_tst_distance.txt";
my $name = "";
my %seqNameLen = ();
open SEQ, $uploadSeqFile or die "couldn't open $uploadSeqFile: $!\n";
while (my $line = <SEQ>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	if ($line =~ /^>(\S+)/) {
		$name = $1;
	}else {
		$seqNameLen{$name} = length $line;
	}
}
close SEQ;

my $dist;
open DIST, $uploadDistFile or die "couldn't open $uploadDistFile: $!\n";
while (my $line = <DIST>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	my @fields = split /\t/, $line;
	$dist->{$fields[0]}->{$fields[1]} = $fields[2];
}
close DIST;

my $dist1Dir = $uploadDir."/Set1";
my $dist2Dir = $uploadDir."/Set2";
my $dist1File = "$dist1Dir/$id-sample1.dat";
my $dist2File = "$dist2Dir/$id-sample2.dat";
unless (-e $dist1Dir) {
	mkdir $dist1Dir;
	chmod 0777, $dist1Dir;
}
unless (-e $dist2Dir) {
	mkdir $dist2Dir;
	chmod 0777, $dist2Dir;
}

open DIST1, ">", $dist1File or die "couldn't open $dist1File: $!\n";
for (my $i=0; $i<@sample1Grps; $i++) {
	my @seqs = @{$sample1Grps[$i]};
	for (my $i=1; $i<=@seqs; $i++) {
		my $seq1 = $seqs[$i-1];
		for (my $j=$i+1; $j<=@seqs; $j++) {
			my $seq2 = $seqs[$j-1];
			my $pwdist = 0;
			if (defined $dist->{$seq1}->{$seq2}) {
				$pwdist = $dist->{$seq1}->{$seq2}
			}elsif (defined $dist->{$seq2}->{$seq1}) {
				$pwdist = $dist->{$seq2}->{$seq1};
			}else {
				die "No distance value between $seq1 and $seq2\n";
			}
			print DIST1 "$i $j $pwdist $seqNameLen{$seq1}\n";
		}
	}
}
close DIST1;

open DIST2, ">", $dist2File or die "couldn't open $dist2File: $!\n";
for (my $i=0; $i<@sample2Grps; $i++) {
	my @seqs = @{$sample2Grps[$i]};
	for (my $i=1; $i<=@seqs; $i++) {
		my $seq1 = $seqs[$i-1];
		for (my $j=$i+1; $j<=@seqs; $j++) {
			my $seq2 = $seqs[$j-1];
			my $pwdist = 0;
			if (defined $dist->{$seq1}->{$seq2}) {
				$pwdist = $dist->{$seq1}->{$seq2}
			}elsif (defined $dist->{$seq2}->{$seq1}) {
				$pwdist = $dist->{$seq2}->{$seq1};
			}else {
				die "No distance value between $seq1 and $seq2\n";
			}
			
			print DIST2 "$i $j $pwdist $seqNameLen{$seq1}\n";
		}
	}
}
close DIST2;

my @params;
push @params, $id, $email, $uploadDir, $remoteIP, $projectId, $docuroot;
my $pid = fork();
die "Failed to fork: $!" unless defined $pid;
if ($pid == 0) {
	# Child process
	close(STDIN);
    close(STDOUT);
    close(STDERR);
    open(STDIN,  "</dev/null");
    open(STDOUT, ">/dev/null");
    open(STDERR, ">/dev/null");
	exec ("perl", "tst.pl", @params);
	exit(0);
}
print "<p>Your job id is $id.</p>";
print "<p>Your data is being processed ... ";
print "</p>";
print "<p>Results will be sent to <strong>$email</strong> after the job is done.</p>";


Divein::PrintFooter();


