#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use Divein;
use Insites;

my $cgi =  new CGI;
print $cgi->header;
Divein::Print_header('insites', 'process');

print "<div id='indent' align='center'>";
print "<h2>Informative sites result</h2>";
my ($remote_ip) = Divein::GetInfo();
my $startTime = time();
my $id = $cgi->param("id");
my $uploadbase = $cgi->param("uploadbase");
my $datatype = $cgi->param("datatype");
my $seqRadio = $cgi->param("seqRadio");
my $uploadDir = $uploadbase."/$id";
my $sortRadio = "n";
my @nas = ();
if ($datatype eq 'aa') {
	@nas = qw (A C D E F G H I K L M N P Q R S T V W Y);
}else {
	@nas = qw (A C G T);
}

my $log = $uploadDir.'/'.$id.'.log';
open LOG, ">",$log or die "couldn't open $log: $!\n";
print LOG "Project: insites\nid: $id\nseqRadio: $seqRadio\ndatatype: $datatype\nuploadDir: $uploadDir\n";

my $uploadseqFile = $uploadDir.'/'.$id;
my %nameSeq = ();
my $seqLen = 0;
open SEQ, $uploadseqFile or die "couldn't open $uploadseqFile: $!\n";
while (my $line = <SEQ>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	if ($line =~ /^\d+\s(\d+)$/) {
		$seqLen = $1;
	}else {
		my ($name, $seq) = split /\t/, $line;
		$nameSeq{$name} = $seq;
	}
}
close SEQ;
# get reference sequence name if user defined one
my $refName = "";
my @reference = $cgi->param("reference");
if (@reference) {	
	$refName = $reference[0];
}

# get groups and sequence names in each group if user defined
my $seqNum = 0;
my @grpNames = my @grpSeqs = my %seqGrp = ();
my @params = $cgi->param;
foreach my $param (@params) {
	if ($param =~ /ingrpName/) {
		push @grpNames, $cgi->param($param);
	}elsif ($param =~ /ingrp/) {
		my @seqs = $cgi->param($param);
		#print "$param: @seqs<br>";
		push @grpSeqs, \@seqs;
		$seqNum += scalar @seqs;
	}
}

if (!@grpSeqs) {	# user didn't define ingroups, all sequences except reference will be put in one group
	my @seqs = $cgi->param("seqName");
	push @grpSeqs, \@seqs;
	$seqNum = scalar @seqs;
	foreach my $seqName (@seqs) {
		$seqGrp{$seqName} = "defalt";
	}
}else {	# user defined ingroups
	for (my $i=0; $i<@grpNames; $i++) {
		foreach my $grpSeq (@{$grpSeqs[$i]}) {	
			$seqGrp{$grpSeq} = $grpNames[$i];	
		}
	}
}

my @seqNameNseqs = ();
for (my $i=0; $i<@grpSeqs; $i++) {
	foreach my $seqName (@{$grpSeqs[$i]}) {
		my $nameNseq = $seqName."\t".$nameSeq{$seqName};
		push @seqNameNseqs, $nameNseq;
	}
}


# if no reference defined, calculate consensus of sequences
my $refSeq = "";
if ($refName) {
	$refSeq = $nameSeq{$refName};
}else {
	$refName = "Consensus";
	$refSeq = Divein::GetConsensus (\@seqNameNseqs, $seqLen);
}
my $seqFile = $uploadseqFile."_seq4insites.phy";
$seqNum += 1;
my $refNameNseq = $refName."\t".$refSeq;
unshift @seqNameNseqs, $refNameNseq;
unshift @seqNameNseqs, $seqNum."\t".$seqLen;
Divein::WriteFile ($seqFile, \@seqNameNseqs);

my $alnDisplayFile = $uploadseqFile.".aln";	# alignment display 
my $alnTabFile = $uploadseqFile."_alntab.txt";	# alignment tab delimited file 
my $alnCondenseDisplayFile = $uploadseqFile."_uniq.aln"; # alignment display - condense unique sequence
my $alnStatFile = $uploadseqFile."_aln.txt";	# tab delimited alignment summary output file
my $varSitesAlnFile = $uploadseqFile."_var.aln";	# aligned variable sites file
my $varSitesTabFile = $uploadseqFile."_var.txt";	# tab delimited variable sites file
my $alnFile = $uploadseqFile."_info.aln";	# aligned informative output file
my $privateAlnFile = $uploadseqFile."_priv.aln";	# aligned private output file
my $tabFile = $uploadseqFile.".txt";	# tab delimited informative output file
my $privateTabFile = $uploadseqFile."_priv.txt";	# tab delimited private output file
my $seqArr = my $displaySeqArr = ();
my $element = my $count = my $maxLen = 0;
my (@informativeSites, @seqNames, @lines, @alnLines, @privateLines, @privateAlnLines, @infoMutant, %infoMutStatus, @privateMutant, %privateMutStatus);
my (%ambiguityHash, @ambiguousPos);
foreach my $line (@seqNameNseqs) {
	next if $line =~ /^\d+\s+\d+$/;
	my ($seqName, $aaSeq) = split /\t/, $line;
	$aaSeq = uc $aaSeq;
	my $nameLen = length $seqName;
	if ($nameLen > $maxLen) {
		$maxLen = $nameLen;
	}
	$seqNames[$element] = $seqName;	
	my $beginFlag = my $terminalFlag = 0;
	for (my $i = 0; $i < $seqLen; $i++) {
		my $aa = substr($aaSeq, $i, 1);
		if ($element == 0) {	# this is reference or consensus sequence
			$seqArr->[$element]->[$i] = $aa;
		}else {	
			# find ambiguous positions for nucleotide sequence
			if (!$ambiguityHash{$i}) {
				if ($datatype eq 'nt' && $aa !~ /[ACGT\-\.\?]/i) {
					$ambiguityHash{$i} = 1;
					push @ambiguousPos, $i;
				}				
			}
	
			# deal with leading gaps
			if ($i == 0 && $aa eq "-") {
				$beginFlag = 1;
				$aa = " ";
			}elsif ($beginFlag == 1 && $aa eq "-") {
				$aa = " ";
			}elsif ($aa ne "-") {
				$beginFlag = 0;
			}
			# deal with termianl gaps
			if (substr ($aaSeq, $i) =~ /^\-+$/) {
				$terminalFlag = 1;
			}
			if ($terminalFlag == 1) {
				$aa = " ";
			}
			
			if ($aa eq $seqArr->[0]->[$i]) {
				$seqArr->[$element]->[$i] = ".";
			}else {
				$seqArr->[$element]->[$i] = $aa;
			}
		}
	}
	$element++;	# sequence index
}

if (@ambiguousPos) {
	my $ambiguousFile = $uploadseqFile."_ambi.txt";	# tab delimited ambiguous output file
	open AMBI, ">", $ambiguousFile or die "couldn't open $ambiguousFile: $!\n";
	foreach my $pos (sort {$a <=> $b} @ambiguousPos) {
		my $site = $pos + 1;
		print AMBI "\t", $site;
	}
	print AMBI "\n";
	for (my $i = 0; $i < $element; $i++) {
		print AMBI $seqNames[$i];
		foreach my $pos (sort {$a <=> $b} @ambiguousPos) {
			print AMBI "\t",$seqArr->[$i]->[$pos];
		}
		print AMBI "\n";
	}
	close AMBI;
}

my (@consAAs, %infoSiteHash, %privateSiteHash, @privateSites, @uniqNas, %uniqNasStatus, %posTotalCount, $posNaCount, @varSites, %varSiteStatus);
my $infoMutHash = my $privateMutHash = my $grpAaHash = ();
my $gapOnlyInsiteCount = my $resultFlag = my $gapOnlyPriSiteCount = 0;
for (my $i = 0; $i < $seqLen; $i++) {
	my $gapOnlyFlag = 1;
	if (!$posTotalCount{$i}) {
		$posTotalCount{$i} = 0;
	}
	for (my $j = 0; $j < $element; $j++) {
		my $aa = $seqArr->[$j]->[$i];
		if ($j == 0) {
			$consAAs[$i] = $aa;
		}else {
			my $seqName = $seqNames[$j];
			#my $grp = 1;	# assume no group file that equals all sequences belong to one group
			my $grp = "";
			if (defined $seqGrp{$seqName}) {	# there is a group file
				$grp = $seqGrp{$seqName};
			}else {
				print "No defined group for sequence $seqName<br>";
				exit;
			}
			
			unless ($aa eq " " || $aa eq "?") {	# count
				my $trueAa = $aa;
				if ($aa eq ".") {
					$trueAa = $consAAs[$i];
				}
				if (!$uniqNasStatus{$trueAa}) {
					$uniqNasStatus{$trueAa} = 1;
					push @uniqNas, $trueAa;					
				}	
				$posTotalCount{$i}++;
				if (!$posNaCount->{$i}->{$trueAa}) {
					$posNaCount->{$i}->{$trueAa} = 0;
				}
				$posNaCount->{$i}->{$trueAa}++;
			}
			
			unless ($aa eq "." || $aa eq " " || $aa eq "?") {
				$resultFlag = 1;
				if (!$grpAaHash->{$i}->{$aa}->{$grp}) {
					$grpAaHash->{$i}->{$aa}->{$grp} = 0;
				}
				$grpAaHash->{$i}->{$aa}->{$grp}++;
				if (!$varSiteStatus{$i}) {
					$varSiteStatus{$i} = 1;
					push @varSites, $i;
				}
			}
		}
	}
	
	foreach my $aa (keys %{$grpAaHash->{$i}}) {
		foreach my $grp (keys %{$grpAaHash->{$i}->{$aa}}) {
			if ($grpAaHash->{$i}->{$aa}->{$grp} == 1) {
				unless ($privateMutHash->{$i}->{$aa}->{$grp}) {
					$privateMutHash->{$i}->{$aa}->{$grp} = 1;	# lable the mutation of the private site
				}	
				
				if (!$privateSiteHash{$i}) {
					$privateSiteHash{$i} = 1;
					push @privateSites, $i;	# array of private sites
				}
			}elsif ($grpAaHash->{$i}->{$aa}->{$grp} > 1) {
				unless ($infoMutHash->{$i}->{$aa}->{$grp}) {
					$infoMutHash->{$i}->{$aa}->{$grp} = 1;	# lable the mutation of the informative site
				}					
	
				if (!$infoSiteHash{$i}) {
					$infoSiteHash{$i} = 1;
					push @informativeSites, $i;	# array of informative sites
				}
			}else {
				die "Something wrong here!\n";
			}
		}
	}

	if ($infoSiteHash{$i}) {	# informative site
		if (keys %{$infoMutHash->{$i}} == 1) { # only one mutation other than consensus
			my ($mut) = keys %{$infoMutHash->{$i}};
			if ($consAAs[$i] eq "-") {
				$gapOnlyInsiteCount++;
			}elsif ($mut eq "-") {
				$gapOnlyInsiteCount++;
			}
		}
	}	
	
	if ($privateSiteHash{$i}) {	# private site
		if (keys %{$privateMutHash->{$i}} == 1) { # only one mutation other than consensus
			my ($mut) = keys %{$privateMutHash->{$i}};
			if ($consAAs[$i] eq "-") {
				$gapOnlyPriSiteCount++;
			}elsif ($mut eq "-") {
				$gapOnlyPriSiteCount++;
			}
		}
	}	
}

if (!$resultFlag) {
	print "<p>There is no informative and private site in your sequence alignment.</p>";
}else {
	# write to alignment display file
	Insites::WriteAlnDisplay ($alnDisplayFile, \@seqNames, $seqArr, $element, $seqLen, $maxLen, $alnCondenseDisplayFile);
	Insites::WriteTabAlign ($alnTabFile, \@seqNames, $seqArr, $element);
	
	$maxLen += 6;
	if (@varSites) {		
		Insites::WriteAlnVarSites ($varSitesAlnFile, $maxLen, \@varSites, \@seqNames, $seqArr, $element,  $seqLen, \%seqGrp);
		Insites::WriteTabVarSites ($varSitesTabFile, \@varSites, \@seqNames, $seqArr, $element, \%seqGrp);
	}
	
	if (@informativeSites) {
		my $param = Insites::GetParams ($maxLen, $element, \@seqNames, \@informativeSites, $seqArr, \%infoMutStatus, \@infoMutant, $infoMutHash, \%seqGrp, $datatype);
		
		Insites::WriteAlnInsites ($alnFile, $maxLen, \@informativeSites, $param, $sortRadio, $seqLen);
				
		my $TAB;
		open ($TAB, ">", $tabFile) or die "Couldn't open $tabFile: $!\n";
		print $TAB "\tTotal_informative\tInformative(noGaps)\tAmbiguities";
		Insites::WriteTabInsites ($TAB, \@informativeSites, $gapOnlyInsiteCount, $param, $sortRadio, $seqArr, $element, $datatype, \@nas, \@infoMutant, \%infoMutStatus, $infoMutHash);
		close $TAB;		
	}
	
	if (@privateSites) {
		my $param = Insites::GetParams ($maxLen, $element, \@seqNames, \@privateSites, $seqArr, \%privateMutStatus, \@privateMutant, $privateMutHash, \%seqGrp, $datatype);
		
		Insites::WriteAlnInsites ($privateAlnFile, $maxLen, \@privateSites, $param, $sortRadio, $seqLen);
				
		my $TAB;
		open ($TAB, ">", $privateTabFile) or die "Couldn't open $privateTabFile: $!\n";
		print $TAB "\tTotal_private\tPrivate(noGaps)\tAmbiguities";
		Insites::WriteTabInsites ($TAB, \@privateSites, $gapOnlyPriSiteCount, $param, $sortRadio, $seqArr, $element, $datatype, \@nas, \@privateMutant, \%privateMutStatus, $privateMutHash);
		close $TAB;		
	}
	# write to alignment summary file	
	open STAT, ">", $alnStatFile or die "couldn't open $alnStatFile: $!\n";
	print STAT "Position";
	foreach my $na (sort @uniqNas) {
		print STAT "\t$na";
	}
	print STAT "\tTotal";
	foreach my $na (sort @uniqNas) {
		print STAT "\t$na";
	}
	print STAT "\t1st Freq.\tFreq.\t2nd Freq.\tFreq.\t3rd Freq.\tFreq.\t4th Freq.\tFreq.\n";
	for (my $i = 0; $i < $seqLen; $i++) {
		my $pos = $i + 1;
		print STAT $pos;
		foreach my $na (sort @uniqNas) {
			if ($posNaCount->{$i}->{$na}) {
				print STAT "\t", $posNaCount->{$i}->{$na};
			}else {
				print STAT "\t0";
			}
		}
		if ($posTotalCount{$i}) {
			print STAT "\t", $posTotalCount{$i};
		}else {
			print STAT "\t0";
		}
		foreach my $na (sort @uniqNas) {
			if ($posNaCount->{$i}->{$na}) {
				my $freq = int ($posNaCount->{$i}->{$na} / $posTotalCount{$i} * 10000 + 0.5) / 10000;
				print STAT "\t", $freq;
			}else {
				print STAT "\t0.0000";
			}
		}
		my $idx = 0;
		foreach my $na (sort {$posNaCount->{$i}->{$b} <=> $posNaCount->{$i}->{$a}} keys %{$posNaCount->{$i}}) {
			$idx++;
			last if ($idx > 4);
			print STAT "\t$na";
			my $freq = int ($posNaCount->{$i}->{$na} / $posTotalCount{$i} * 10000 + 0.5) / 10000;
			print STAT "\t", $freq;
		}
		print STAT "\n";
	}
	print STAT "\n";
	close STAT;

	print "<p>Your job id is $id. Please check results by clicking following links:</p>";
	print "<table board=0 cellspacing=10>";
	print "<tr><td align=right>Alignment display:</td><td><a href=view.cgi?id=$id&ext=.aln&datatype=$datatype target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=.aln>download</a></td></tr>";
	print "<tr><td align=right>Tab delimited alignment:</td><td><a href=view.cgi?id=$id&ext=_alntab.txt&datatype=$datatype target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_alntab.txt>download</a></td></tr>";
	print "<tr><td align=right>Alignment display of unique sequences:</td><td><a href=view.cgi?id=$id&ext=_uniq.aln&datatype=$datatype target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_uniq.aln>download</a></td></tr>";
	if (@varSites) {
		print "<tr><td align=right>Aligned variable sites:</td><td><a href=view.cgi?id=$id&ext=_var.aln&datatype=$datatype target=_blank>view</a></td>";
		print "<td><a href=download.cgi?id=$id&ext=_var.aln>download</a></td></tr>";
		print "<tr><td align=right>Tab delimited variable sites:</td><td><a href=view.cgi?id=$id&ext=_var.txt target=_blank>view</a></td>";
		print "<td><a href=download.cgi?id=$id&ext=_var.txt>download</a></td></tr>";	
	}else {
		print "<tr><td align=right>Aligned informative sites:</td><td>None</a></td></tr>";
		print "<tr><td align=right>Tab delimited informative sites & summary:</td><td>None</a></td></tr>";
	}
	if (@informativeSites) {
		print "<tr><td align=right>Aligned informative sites:</td><td><a href=view.cgi?id=$id&ext=_info.aln&datatype=$datatype target=_blank>view</a></td>";
		print "<td><a href=download.cgi?id=$id&ext=_info.aln>download</a></td></tr>";
		print "<tr><td align=right>Tab delimited informative sites & summary:</td><td><a href=view.cgi?id=$id&ext=.txt target=_blank>view</a></td>";
		print "<td><a href=download.cgi?id=$id&ext=.txt>download</a></td></tr>";	
	}else {
		print "<tr><td align=right>Aligned informative sites:</td><td>None</a></td></tr>";
		print "<tr><td align=right>Tab delimited informative sites & summary:</td><td>None</a></td></tr>";
	}	
	if (@privateSites) {
		print "<tr><td align=right>Aligned private sites:</td><td><a href=view.cgi?id=$id&ext=_priv.aln&datatype=$datatype target=_blank>view</a></td>";
		print "<td><a href=download.cgi?id=$id&ext=_priv.aln>download</a></td></tr>";
		print "<tr><td align=right>Tab delimited private sites & summary:</td><td><a href=view.cgi?id=$id&ext=_priv.txt target=_blank>view</a></td>";
		print "<td><a href=download.cgi?id=$id&ext=_priv.txt>download</a></td></tr>";	
	}else {
		print "<tr><td align=right>Aligned private sites:</td><td>None</a></td></tr>";
		print "<tr><td align=right>Tab delimited private sites & summary:</td><td>None</a></td></tr>";
	}
	if (@ambiguousPos) {
		print "<tr><td align=right>Tab delimited ambiguity sites:</td><td><a href=view.cgi?id=$id&ext=_ambi.txt target=_blank>view</a></td>";
		print "<td><a href=download.cgi?id=$id&ext=_ambi.txt>download</a></td></tr>";	
	}
	print "<tr><td align=right>Tab delimited alignment summary:</td><td><a href=view.cgi?id=$id&ext=_aln.txt target=_blank>view</a></td>";
	print "<td><a href=download.cgi?id=$id&ext=_aln.txt>download</a></td></tr>";
	print "</table>";
}

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
my $statDir = "/var/www/html/stats";
unless (-e $statDir) {
	mkdir $statDir;
	chmod 0777, $statDir;
}
my $statFile = "$statDir/insites.stat";
open STAT, ">>", $statFile or die "couldn't open $statFile: $!\n";
print STAT "$finishTime\t$id\t$seqNum\t$seqLen\t$datatype\t$remote_ip\t$duration\n";
close STAT;

Divein::PrintFooter();

