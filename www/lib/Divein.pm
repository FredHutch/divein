package Divein;

use strict;
use warnings;
use Carp qw[croak carp];
use Data::Dumper;


=head1 NAME

Common -- package for common routines used in DIVEIN

=head1 SYNOPSIS


=head1 METHODS


=cut

our $uploadbase = '/var/www/html/outputs';

sub GetInfo {
	my $remote_ip = '';
	if ($ENV{'HTTP_X_REAL_IP'}) {
		$remote_ip = $ENV{'HTTP_X_REAL_IP'};
	}else {
		$remote_ip = $ENV{'REMOTE_ADDR'};
	}
	my $http = $ENV{'HTTP_REFERER'};
	$http =~ /(.*)\//;
	my $url = $1;
	$url =~ /(.*)\/(\S+)$/;
	my $localDir = $2;
	return ($remote_ip, $url, $localDir);
}

sub Get_css_source {
	my $localDir = shift;
	my $css_source = "/static/css/divein.css";
	return $css_source;
}

sub Get_help_source {
	my $localDir = shift;
	my $help_source = "/help.html";
	return $help_source;
}

sub GetExample {
	my ($file) = @_;
	my $exampleFile = "/var/www/html/examples/$file";
	return $exampleFile;
}

sub GetFileLines {
	my $fh = shift;
	my $line = "";
	my @buffer = <$fh>;
 	foreach my $element (@buffer) {
 		$line .= $element;
 	}
 	if ($line =~ /\r\n/) {
		$line =~ s/\r//g;
	}elsif ($line =~ /\r/) {
		$line =~ s/\r/\n/g;
	}
	my @fileLines = split /\n/, $line;
	return \@fileLines;
}

sub CleanString {
	my $string = shift;
	$string =~ s/^\s+//;	# remove leading spaces
	$string =~ s/\s+$//;	# remove ending spaces
	return $string;
}


sub GetSequences {
	my ($seqFileLines, $seqFileRadio) = @_;
	my ($seqName, %seqNameStatus, @seqNames, @stdnameNseqs, @seqInfo, %nameSeq, %countName);
	my $seqNum = my $seqLen = my $seqCount = my $nexusFlag = my $phylipFlag = my $fastaFlag = my $seqStartFlag = my $ntaxFlag = my $ncharFlag = my $fastSeqFlag = my $count = 0;
	foreach my $line (@$seqFileLines) {
		next if $line =~ /^\s*$/;
		$line = CleanString ($line);
		if ($seqFileRadio eq "nexus") {
			if ($nexusFlag == 0 && $line =~ /^\#NEXUS$/i) {
				$nexusFlag = 1;	
			}elsif ($nexusFlag) {
				if($line =~ /NTAX=(\d+)/i) {	# handled the case that ntax and nchar are not in the same line
					$seqNum = $1;
					$ntaxFlag = 1;
				}
				if($line =~ /NCHAR=(\d+)/i) {	# handled the case that ntax and nchar are not in the same line
					$seqLen = $1;
					$ncharFlag = 1;
				}
				if ($line =~ /^MATRIX$/i) {
					$seqStartFlag = 1;
				}elsif ($line =~ /^\;$/) {
					$seqStartFlag = 0;
					if (!$ntaxFlag) {
						$seqNum = $seqCount;
					}
				}elsif ($seqStartFlag) {
					unless ($line =~ /^\[\s+/) {	# ignore the line beginning with [
						$line =~ s/\[\d+\]$// if ($line =~ /\[\d+\]$/);	# remove [\d+] on the end of line
						if ($line =~ /^(\S+)\s+(.*)$/) {	# requires no space in sequence names, there could be spaces in sequences
							
							my $seqName = $1;
							my $seq = $2;
							$seq =~ s/\s//g;	# remove spaces that may be in sequences
							unless ($seq =~ /^[A-Za-z\-\.\?]+$/) {
								my @nas = split //, $seq;
								foreach my $na (@nas) {
									unless ($na =~ /[A-Za-z\-\.\?]/) {
										print "<p>Error: couldn't recognize character $na in sequence $seqName. Please check the sequence file.</p>";
										PrintFooter();
									}
								}								
							}
											
							if (!$seqNameStatus{$seqName}) {
								push @seqNames, $seqName;
								$seqNameStatus{$seqName} = 1;
								$nameSeq{$seqName} = '';
								$seqCount++;
							}else {
								#print "<p>$seqName</p>";
							}
							
							$nameSeq{$seqName} .= $seq;
						}
					} 				
				}
			}else {
				print "<p>The upload sequence file is not a nexus file. The nexus file must start with #NEXUS. Please check the file and upload again.</p>";
				PrintFooter();
			}
		}elsif ($seqFileRadio eq "phylip" || $seqFileRadio eq "example") {	# phylip file
			if ($phylipFlag == 0 && $line =~ /^\s*(\d+)\s+(\d+)/) {
				$seqNum = $1;
				$seqLen = $2;
				$phylipFlag = 1;
			}elsif ($phylipFlag) {
				if ($count < $seqNum) {
					$line =~ /^(\S+)\s+(.*)$/;	# requires no space in sequence names, there could be spaces in sequences
					my $seqName = $1;
					my $seq = $2;
					$seq =~ s/\s//g;	# remove spaces that may be in sequences
					unless ($seq =~ /^[A-Za-z\-\.\?]+$/) {
						my @nas = split //, $seq;
						foreach my $na (@nas) {
							unless ($na =~ /[A-Za-z\-\.\?]/) {
								print "<p>Error: couldn't recognize character $na in sequence $seqName. Please check the sequence file.</p>";
								PrintFooter();
							}
						}								
					}
					push @seqNames, $seqName;
					$countName{$count} = $seqName;
					$nameSeq{$seqName} = $seq;
					$seqCount++;
				}else {	# interleaved 
					my $index = $count % $seqNum;
					$line =~ s/\s//g;	# remove all spaces, the line only contains sequence
					my $seqName = $countName{$index};
					$nameSeq{$seqName} .= $line;
				}				
				$count++;
			}else {
				print "<p>The upload sequence file is not a phylip file. Please check the file and upload again.</p>";
				PrintFooter();
			}
		}else {	# fasta file, the code can handle both interval and sequential formats
			if (!$fastaFlag) {	# check for fasta format
				if ($line !~ /^>/) {
					print "<p>The upload sequence file is not a fasta file. Please check the file and upload again.</p>";
					PrintFooter();
				}else {
					$fastaFlag = 1;
				}	
			}
			
			if ($line =~ /^>(\S+)/) {
				$seqCount++;
				$seqNum = $seqCount;
				$seqName = $1;
				push @seqNames, $seqName;
				$fastSeqFlag = 0;
			}else {
				$line =~ s/\s//g;	# remove spaces that may be in sequences
				unless ($line =~ /^[A-Za-z\-\.\?]+$/) {
					my @nas = split //, $line;
					foreach my $na (@nas) {
						unless ($na =~ /[A-Za-z\-\.\?]/) {
							print "<p>Error: couldn't recognize character $na in sequence $seqName. Please check the sequence file.</p>";
							PrintFooter();
						}
					}								
				}
				if (!$fastSeqFlag) {
					$nameSeq{$seqName} = "";
					$fastSeqFlag = 1;
				}
				$nameSeq{$seqName} .= $line;				
			}
		}
	}
	
	if ($seqFileRadio eq "nexus") {
		if (!$seqNum && !$seqLen) {
			print "<p>Error: Couldn't get information of pre-defined sequnece number and length. It is probably caused by missing statement of dimensions 
			in your nexus file. Please check the sequence file.</p>";
			PrintFooter();
		}
	}elsif ($seqFileRadio eq "fasta") {
		$seqLen = length $nameSeq{$seqNames[0]};	# set alignment length to be the length of first sequence
	}
#	print "length: $seqLen<br>";
	if (!@seqNames) {
		print "<p>Error: Couldn't get sequence names from the input sequence file. Please check the sequence file.</p>";
		PrintFooter();
	}else {
		my %seqNamesHash;
		foreach my $seqName (@seqNames) {
			#if (length $seqName > 30) {	# check length of sequence name, when compile PhyML, user can set it. now set to maximum 30 characters
			#	print "<p>Error: The length of sequence name exceeds the maximum length of 30 characters.</p>";
			#	PrintFooter();
			#}
			my $ciName = uc $seqName;
			# name is case-insensitive, because hyphy treats lower- and upper-case same
			if (!$seqNamesHash{$ciName}) {
				$seqNamesHash{$ciName} = 1;
			}else {
				print "<p>Error: At least two sequences have the same name of $seqName in sequence alignment file. It may be caused by the space(s) in sequence name or case-insensitve of the name. ";
				print "Please check your input sequence file to make sure the unique sequence name or no space in sequence name.</p>";
				PrintFooter();
			}		
		}
	}
	
	if ($seqCount != $seqNum) {
		print "<p>Error: Number of sequences is not equal to pre-defined sequence number of $seqNum in your uploaded sequence alignment file. 
		It may caused by the duplicated sequence names in your alignment. Please check the sequence number or remove the duplicates and upload your file again.</p>";
		PrintFooter();
	}
	
	foreach my $seqName (@seqNames) {	# check each sequence length in the alignment
		if (length $nameSeq{$seqName} != $seqLen) {						
			print "<p>Error: Lengths of sequences are not same among the alignment. It may caused by the duplicated sequence names in your alignment. ";
			print "Please check your input sequence file to make sure that sequences are aligned or there are no duplicates.</p>";
			PrintFooter();
		}
	}
	
	my @stdSeqNames;
	foreach my $seqName (@seqNames) {
		my $seq = $nameSeq{$seqName};
		my $stdName = $seqName;
		$stdName =~ s/\W/_/g;	# replace non-letters with "_"
		my $stdnameNseq = $stdName."\t".$seq;
		push @stdnameNseqs, $stdnameNseq;
		push @stdSeqNames, $stdName;
	}
	
#	my $seqNumNLen = $seqNum."\t".$seqLen;
#	unshift @stdnameNseqs, $seqNumNLen;	
#	my $datasize = $seqNum * $seqLen;
	push @seqInfo, $seqNum, $seqLen, \@seqNames, \@stdSeqNames, \@stdnameNseqs;
	return \@seqInfo;
}


sub WriteFile {
	my ($uploadFile, $fileLines) = @_;
	open OUT, ">$uploadFile" or die "couldn't open $uploadFile: $!\n";
	foreach my $line (@$fileLines) {
		print OUT $line,"\n";
	}
	close OUT;
}


sub GetConsensus {
	my ($seqNameNseq, $nchar) = @_;
	my (@seqNames, $seqArr);
	my $element = scalar @$seqNameNseq;
	for (my $i = 0; $i < $element; $i++) {
		my ($seqName, $seq) = split /\t/, $seqNameNseq->[$i];
		push @seqNames, $seqName;
		$seq = uc $seq;
		my $beginFlag = my $terminalFlag = 0;
		my $nameNformatedseq = $seqName."\t";
		for (my $j = 0; $j < $nchar; $j++) {
			my $aa = substr($seq, $j, 1);				
			# deal with leading gaps
			if ($j == 0 && $aa eq "-") {
				$beginFlag = 1;
				$aa = " ";
			}elsif ($beginFlag == 1 && $aa eq "-") {
				$aa = " ";
			}elsif ($aa ne "-") {
				$beginFlag = 0;
			}
			# deal with termianl gaps
			if (substr ($seq, $j) =~ /^\-+$/) {
				$terminalFlag = 1;
			}
			if ($terminalFlag == 1) {
				$aa = " ";
			}
			
			if ($i == 0) {
				$seqArr->[$i]->[$j] = $aa;
			}else {				
				if ($aa eq ".") {
					$seqArr->[$i]->[$j] = $seqArr->[0]->[$j];
				}else {
					$seqArr->[$i]->[$j] = $aa;
				}
			}
		}
	}
	my @consAas;
	for (my $i = 0; $i < $nchar; $i++) {
		my %aaCount;
		my $blankCount = 0;
		for (my $j = 0; $j < $element; $j++) {
			my $aa = $seqArr->[$j]->[$i];
			unless ($aa eq "?") {
				if ($aa eq " ") {	# leading or ending gaps
					$blankCount++;
				}else {
					if (!$aaCount{$aa}) {
						$aaCount{$aa} = 0;
					}
					$aaCount{$aa}++;
				}			
			}
		}
		
		my $consAa;
		if ($blankCount == $element) {
			$consAa = "-";
		}else {
			my $flag = 0;		
			foreach my $aa (keys %aaCount) {			
				if (!$flag) {
					$consAa = $aa;
					$flag = 1;
				}else {
					if ($aaCount{$aa} > $aaCount{$consAa}) {
						$consAa = $aa;
					}
				}
			}
		}		
		push @consAas, $consAa;
	}
	my $cons = join("", @consAas);
	return $cons;
}

sub GetIngroup {
	my $grpFileLines = shift;
	my @ingroup;
	my %seqGrpHash;
	foreach my $line (@$grpFileLines) {
		next if $line =~ /^\s*$/;
		my ($group, $seqName) = split /\t/, $line;
		if (defined $group && defined $seqName) {
			$group = CleanString ($group);
			$seqName = CleanString ($seqName);
			push @ingroup, $seqName;
			$seqGrpHash{$seqName} = $group;
		}
	}
	
	if (!@ingroup) {
		print "<p>Error: Couldn't get sequence names from the input group file. Please check the group file.</p>";
		PrintFooter();
	}
	return (\@ingroup, \%seqGrpHash);
}


sub CheckNameMatch {
	my ($seqNamesRef, $ingroupRef) = @_;
	my %seqNamesHash;
	foreach my $seqName (@$ingroupRef) {
		$seqNamesHash{$seqName} = 1;
	}
		
	shift @$seqNamesRef;	# skip the first sequence that is consensus
	foreach (@$seqNamesRef) {
		if (!$seqNamesHash{$_}) {
			print "<p>Error: sequence name $_ in sequence file doesn't match sequence name in group file.</p>";
			PrintFooter();
		}
	}
}

sub StripGaps {
	my ($seqFile, $gapStripSeqFile) = @_;
	my $seqCount = my $seqLen = my $afterGapStripLen = my $gapCount = 0;
	my (@seqNames, %nameSeq);
	open IN, $seqFile or die "Couldn't open $seqFile: $!\n";
	while (my $line = <IN>) {
		chomp $line;
		next if $line =~ /^\s*$/;
		if ($line =~ /^(\d+)\s+(\d+)$/) {
			$seqCount = $1;
			$seqLen = $afterGapStripLen = $2;
		}elsif ($line =~ /^(\S+)\t(\S+)$/) {
			my $seqName = $1;
			my $seq = $2;
			push @seqNames, $seqName;
			my @nas = split //, $seq;
			$nameSeq{$seqName} = \@nas;
		}
	}
	close IN;
	for (my $i = 0; $i < $seqLen; $i++) {
		my $flag = 0;
		foreach my $seqName (@seqNames) {
			unless ($nameSeq{$seqName}->[$i] eq '-') {
				$flag = 1;
				last;
			}
		}
		unless ($flag) {
			$afterGapStripLen--;
			foreach (@seqNames) {
				$nameSeq{$_}->[$i] = '';
			}
		}
	}
	open OUT, ">$gapStripSeqFile" or die "Couldn't open $gapStripSeqFile: $!\n";
	print OUT "$seqCount\t$afterGapStripLen\n";
	foreach (@seqNames) {
		print OUT $_,"\t",join ('', @{$nameSeq{$_}}),"\n";
	}
}

sub ChangetoFasta {
	my ($phylipFile, $fastaFile) = @_;
	my $seqCount = my $seqLen = 0;
	my %nameSeq = ();
	open(IN, $phylipFile) || die "Can't open file $phylipFile: $!\n";
	open(OUT, ">$fastaFile") || die "Can't open out file $fastaFile: $!\n";
	
	while(my $line = <IN>) {
		chomp $line;
		if ($line =~ /^(\d+)\s+(\d+)$/) {
			$seqCount = $1;
			$seqLen = $2;
		}else {
			if($line =~ /^(\S+)\s+(\S+)$/) {
				my $name = $1;
				my $sequence = $2;
				$nameSeq{$name} = $sequence;
				print OUT ">$name\n$sequence\n";
			}
		}	
	}
	close IN;
	close OUT;
	return ($seqCount, $seqLen, \%nameSeq);
}

sub GetCOT {
	my ($hyphyOutFile, $cottreeFile, $datatype) = @_;
	my $tree = my $seq = '';
	my $flag = 0;
	open IN, $hyphyOutFile or die "Couldn't open $hyphyOutFile: $!\n";
	open TREE, ">$cottreeFile" or die "Couldn't open $cottreeFile: $!\n";
	while (my $line = <IN>) {
		chomp $line;
		if ($line =~ /\"COTTree\"\:\"(.*?)\"/) {
			$tree = $1.';';
			print TREE $tree,"\n";
		}
		if ($datatype eq 'nt') {	# get DNA COT sequence
			if ($line =~ /MATRIX/) {
				$flag = 1;
			}elsif ($line =~ /END;/) {
				$flag = 0;
			}elsif ($flag) {
				$seq = $line;			
			}
		}else {	# get amino acid COT sequence
			if ($line =~ /Sequence,Site,ML Joint/) {
				$flag = 1;
			}elsif ($line =~ /Check messages\.log/) {
				$flag = 0;
			}elsif ($flag) {
				my ($node, $site, $aa) = split /,/, $line;
				$seq .= $aa;
			}
		}	
	}
	close IN;
	close TREE;
	return ($tree, $seq);
}

sub RefineCOT {
	my ($cotseq, $alignments, $alignLen) = @_;
	my (@seqNames, %nameSeq);
	foreach my $line (@$alignments) {
		if ($line =~ /^(\S+)\t(\S+)$/) {
			my $seqName = $1;
			my $seq = $2;
			push @seqNames, $seqName;
			my @nas = split //, $seq;
			$nameSeq{$seqName} = \@nas;
		}
	}	 
	for (my $i = 0; $i < $alignLen; $i++) {
		my $dashFlag = 0;
		foreach my $seqName (@seqNames) {
			if ($nameSeq{$seqName}->[$i] =~ /[\-\?X]/i) {
				$dashFlag = 1;
			}else {
				$dashFlag = 0;
				last;
			}
		}
		if ($dashFlag) {
			substr ($cotseq, $i, 1, "-");
		}
	}	
	return $cotseq;
}

sub WriteSeq {
	my ($file, $seq, $seqName, $lenperline) = @_;	
	# write to file
	my $idx = 0;
	open OUT, ">$file" or die "Couldn't open $file: $!\n";
	print OUT ">$seqName\n";
	if (!$lenperline) {
		print OUT "$seq\n";
	}else {
		while ($idx < length $seq) {
			my $partialSeq = substr($seq, $idx, $lenperline);
			print OUT "$partialSeq\n";
			$idx += $lenperline;
		}
	}	
	close OUT;
}

sub GetDuration_dhms {
	my $timestamp = shift;
	my @parts = gmtime ($timestamp);
	my $duration = join (':', @parts[7,2,1,0]);
	return $duration;
}

sub Print_header {
	my ($program, $step) = @_;
	my $title;
	if ($program eq 'tst') {
		$title = 'Two-Sample Tests'; 
	}elsif ($program eq 'insites') {
		$title = 'Informative sites'; 
	}elsif ($program eq 'cot') {
		$title = 'Center Of Tree'; 
	}elsif ($program eq 'diver') {
		$title = 'Phylogeny/divergence/diversity'; 
	}elsif ($program eq 'retrieve') {
		$title = 'Retrieve result'; 
	}elsif ($program eq 'cluster') {
		$title = 'Sequence clustering';
	}
	
	print <<END_HTML;

	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
			"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
	<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
	<title>$title</title>	
	<link href="/static/css/divein.css" media='screen' rel='Stylesheet' type='text/css' />
	<script type="text/javascript" src='/static/js/divein.js'></script>
	<script type="text/javascript" src="/static/Archaeopteryx/ArchaeopteryxA.js"></script>
	
	</head>
	
	<body>
		<div>
    		<div class="title">DIVEIN</div>
    		<div><img src="/static/images/Jim&Lisa/header.jpg" width='400' height='120' style="float:left"></div>
    		<div class="s-title">Divergence, Diversity,<br>Informative Sites and<br>Phylogenetic Analyses</div>
END_HTML
	if ($program eq 'tst') {
		print "<div><img src='/static/images/Jim&Lisa/KoHa-90.jpg' height='120' style='float:right'></div>";
	}elsif ($program eq 'insites') {
		print "<div><img src='/static/images/Jim&Lisa/KoHa-83.jpg' height='120' style='float:right'></div>";
	}elsif ($program eq 'cot') {
		if ($step eq 'process') {
			print "<div><img src='/static/images/Jim&Lisa/KoHa-64.jpg' height='120' style='float:right'></div>";
		}else {
			print "<div><img src='/static/images/Jim&Lisa/KoHa-90.jpg' height='120' style='float:right'></div>";
		}		
	}elsif ($program eq 'diver') {
		if ($step eq 'process') {
			print "<div><img src='/static/images/Jim&Lisa/KoHa-66.jpg' height='120' style='float:right'></div>";
		}else {
			print "<div><img src='/static/images/Jim&Lisa/KoHa-10_m.jpg' height='120' style='float:right'></div>";
		}		
	}elsif ($program eq 'cluster') {
		print "<div><img src='/static/images/Jim&Lisa/KoHa-83.jpg' height='120' style='float:right'></div>";
	}
			
	print <<END_HTML;
    	</div>
    	<div class="spacer"></div>
		
		<div class="navbar">
			<a href='/index.html' class="nav">Home</a>
END_HTML
	if ($program eq 'insites') {
		print "<a href='/insites.html'><strong>Informative sites</strong></a>";
	}else {
		print "<a href='/insites.html'>Informative sites</a>";
	}
	if ($program eq 'cot') {
		print "<a href='/cot.html'><strong>Center Of Tree</strong></a>";
	}else {
		print "<a href='/cot.html'>Center Of Tree</a>";
	}
	if ($program eq 'diver') {
		print "<div class='dropdown'>";
		print "<button class='dropbtn'><strong>Phylogeny/Divergence/Diversity</strong>";
		print "<i class='fa fa-caret-down'></i>";
		print "</button>";
		print "<div class='dropdown-content'>";
		print "<a href='/diver.html'>PhyML 3.3.20220408</a>";
		print "<a href='/fasttree.html'>FastTree 2.1.10</a>";
		print "<a href='/raxml.html'>RAxML 8.2.12</a>";
		print "<a href='/hd.html'>Hamming distance</a>";
		print "</div></div>"; 
	}else {
		print "<div class='dropdown'>";
		print "<button class='dropbtn'>Phylogeny/Divergence/Diversity";
		print "<i class='fa fa-caret-down'></i>";
		print "</button>";
		print "<div class='dropdown-content'>";
		print "<a href='/diver.html'>PhyML 3.3.20220408</a>";
		print "<a href='/fasttree.html'>FastTree 2.1.10</a>";
		print "<a href='/raxml.html'>RAxML 8.2.12</a>";
		print "<a href='/hd.html'>Hamming distance</a>";
		print "</div></div>"; 
	}
	if ($program eq 'tst') {
		print "<a href='/tst.html'><strong>Two-Sample Tests</strong></a>";
	}else {
		print "<a href='/tst.html'>Two-Sample Tests</a>";
	}
	if ($program eq 'cluster') {
		print "<a href='/cluster.html'><strong>Sequence clustering</strong></a>";
	}else {
		print "<a href='/cluster.html'>Sequence clustering</a>";
	}
	if ($program eq 'retrieve') {
		print "<a href='/retrieve.html'><strong>Retrieve results</strong></a>";
	}else {
		print "<a href='/retrieve.html'>Retrieve results</a>";
	}		
			
	print <<END_HTML;	
			<span><a href="/contact.html" class="nav">Contact</a></span>
			<span><a href="/help.html" class="nav">Help</a></span>
		</div>
 
END_HTML
}

sub PrintFooter {
	print "</div>
			<div id='footer' align=center>
				<p class='copyright'>&copy; 2025 Fred Hutch Cancer Center. All rights reserved.</p>
			</div>
		</body>
		<html>";
	exit 0;
}



1; #TRUE!!
 
