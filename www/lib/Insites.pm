package Insites;

use strict;
use warnings;
use Carp qw[croak carp];
use Data::Dumper;
use Sort::Fields;

=head1 NAME

Common -- package for routines used for insties in DIVEIN

=head1 SYNOPSIS


=head1 METHODS


=cut


sub GetParams {
	my ($maxLen, $element, $seqnamesRef, $sitesRef, $seqArr, $mutStatusRef, $mutantRef, $aaHash, $seqGrp, $datatype) = @_;
	my (@alnLines, @lines, $param);
	my $grp = "";
	for (my $i = 0; $i < $element; $i++) {
		my $line = "";
		my $alnLine = my $seqName = $seqnamesRef->[$i];
		my $len = length $seqnamesRef->[$i];
				
		for (my $j = $len; $j < $maxLen; $j++) {
			$alnLine .= " ";
		}
		my $infoCount = my $gapInfoCount = my $ambiCount = 0;
		foreach my $position (@$sitesRef) {
			my $aa = $seqArr->[$i]->[$position];
			if ($i == 0) {
				if (!$mutStatusRef->{$aa}) {
					$mutStatusRef->{$aa} = 1;
					push @$mutantRef, $aa;
				}
			}else {
				if (!$grp || ($grp && $seqGrp->{$seqName} ne $grp)) {
					$grp = $seqGrp->{$seqName};
					push @alnLines, "";
					push @lines, "";
				}
				unless ($aa eq "." || $aa eq " " || $aa eq "?") {
					if (!$mutStatusRef->{$aa}) {
						$mutStatusRef->{$aa} = 1;
						push @$mutantRef, $aa;
					}
					if (!$aaHash->{$position}->{$aa}->{$grp}) {	# private site, change aa to consensus for display
						#$aa = ".";
					}else {					
						$infoCount++;
						if ($aa eq "-") {
							$gapInfoCount++;
						}else {
							if ($datatype eq 'nt' && $aa !~ /[ACGTacgt\-]/) {
								$ambiCount++;
							}elsif ($datatype eq 'aa' && $aa eq 'X') {
								$ambiCount++;
							}
						}
					}
				}
			}
			$alnLine .= $aa;
			$line .= "\t".$aa;
		}
		
		push @alnLines, $alnLine;
		my $noGapInfoCount = $infoCount - $gapInfoCount;
		my $tabLine;
		if ($line) {
			$tabLine = $seqnamesRef->[$i]."\t".$infoCount."\t".$noGapInfoCount."\t".$ambiCount.$line;
		}
		push @lines, $tabLine;
	}
	$param->{lines} = \@lines;
	$param->{alnLines} = \@alnLines;
	return $param;
}

sub WriteAlnDisplay {
	my ($alignDisplayFile, $seqNames, $seqArr, $element, $seqLen, $maxLen, $uniqAlignDisplayFile) = @_;
	my %seqCount = my %seqStatus = ();
	$maxLen += 10;
	open ALNDISPLAY, ">$alignDisplayFile" or die "couldn't open $alignDisplayFile: $!\n";
	for (my $i = 0; $i < $element; $i++) {
		my $seq = join ("", @{$seqArr->[$i]});
		$seq =~ s/ /\-/g;		
		printf ALNDISPLAY "%-".$maxLen."s", $seqNames->[$i];
		print ALNDISPLAY "$seq\n";
	}
	close ALNDISPLAY;
	
	open UNIQDISPLAY, ">$uniqAlignDisplayFile" or die "couldn't open $uniqAlignDisplayFile: $!\n";	
	for (my $i = 0; $i < $element; $i++) {
		my $seq = join ("", @{$seqArr->[$i]});
		$seq =~ s/ /\-/g;
		if ($i == 0) {
			printf UNIQDISPLAY "%-".$maxLen."s", $seqNames->[$i];
			print UNIQDISPLAY "$seq\n";
		}else {
			if (!$seqStatus{$seq}) {
				$seqStatus{$seq} = $seqNames->[$i];
			}
			$seqCount{$seq}++;
		}
	}
	my $idx = 0;
	foreach my $seq (sort {$seqCount{$b} <=> $seqCount{$a}} keys %seqCount) {
		$idx++;
		my $name = $seqStatus{$seq}."_".$seqCount{$seq};
		printf UNIQDISPLAY "%-".$maxLen."s", $name;
		print UNIQDISPLAY "$seq\n";
	}
	close UNIQDISPLAY;
}

sub WriteTabAlign {
	my ($alignTabFile, $seqNames, $seqArr, $element) = @_;
	open TAB, ">", $alignTabFile or die "couldn't open $alignTabFile: $!\n";
	for (my $i = 0; $i < $element; $i++) {
		my @nts = @{$seqArr->[$i]};
		printf TAB $seqNames->[$i];
		foreach my $nt (@nts) {
			if ($nt eq " ") {
				$nt = "-";
			}
			print TAB "\t$nt";
		}
		print TAB "\n";
	}
	close TAB;
}

sub WriteAlnVarSites {
	my ($varSitesAlnFile, $maxLen, $varSitesRef, $seqNamesRef, $seqArr, $element,  $seqLen, $seqGrp) = @_;
	
	my $digits = 1;
	while (1) {
		if ($seqLen =~ /^\d{$digits}$/) {
			last;
		}
		$digits++
	}
	
	open (ALN, ">$varSitesAlnFile") or die "Couldn't open $varSitesAlnFile: $!\n";
	
	printf ALN "%".$maxLen."s", "";
	
	for (my $i = $digits; $i > 0; $i--) {
		foreach my $position (@$varSitesRef) {
			my $aaIndex = $position + 1;
			my $pattern = "(\\d)";
			for (my $j = 1; $j < $i; $j++) {
				$pattern .= "\\d";		
			}
			if ($aaIndex =~ /$pattern$/) {				
				print ALN $1;
			}else {
				print ALN " ";
			}
		}
		print ALN "\n";
		if ($i == 1) {
			print ALN "\n";
		}else {
			printf ALN "%".$maxLen."s", "";
		}	
	}
	my $grp = "";
	for (my $i = 0; $i < $element; $i++) {
		if ($i == 0) {
			printf ALN "%-".$maxLen."s", $seqNamesRef->[$i];
			foreach my $varSite (@{$varSitesRef}) {
				print ALN $seqArr->[$i]->[$varSite];
			}
			print ALN "\n";
		}else {
			if (!$grp || $grp && ($seqGrp->{$seqNamesRef->[$i]} ne $grp)) {
				$grp = $seqGrp->{$seqNamesRef->[$i]};
				print ALN "\n";
			}
			printf ALN "%-".$maxLen."s", $seqNamesRef->[$i];
			foreach my $varSite (@{$varSitesRef}) {
				print ALN $seqArr->[$i]->[$varSite];
			}
			print ALN "\n";
		}		
	}
	close ALN;
}

sub WriteTabVarSites {
	my ($varSitesTabFile, $varSitesRef, $seqNamesRef, $seqArr, $element, $seqGrp) = @_;
	open TAB, ">$varSitesTabFile" or die "couldn't open $varSitesTabFile: $!\n";
	foreach my $site (@$varSitesRef) {
		my $pos = $site + 1;
		print TAB "\t$pos";
	}
	print TAB "\n";
	my $grp = "";
	for (my $i = 0; $i < $element; $i++) {
		if ($i == 0) {
			print TAB $seqNamesRef->[$i];
			foreach my $varSite (@{$varSitesRef}) {
				print TAB "\t$seqArr->[$i]->[$varSite]";
			}
			print TAB "\n";
		}else {
			if (!$grp || $grp && ($seqGrp->{$seqNamesRef->[$i]} ne $grp)) {
				$grp = $seqGrp->{$seqNamesRef->[$i]};
				print TAB "\n";
			}
			print TAB $seqNamesRef->[$i];
			foreach my $varSite (@{$varSitesRef}) {
				print TAB "\t$seqArr->[$i]->[$varSite]";
			}
			print TAB "\n";
		}		
		
	}
	close TAB;
}

sub WriteAlnInsites {
	my ($alnFile, $maxLen, $informativeSitesRef, $param, $sortRadio, $nchar) = @_;
	my $firstAlnLine = shift @{$param->{alnLines}};
	my @alnOutputs = @{$param->{alnLines}};
	
	my $digits = 1;
	while (1) {
		if ($nchar =~ /^\d{$digits}$/) {
			last;
		}
		$digits++
	}
	
	open (ALN, ">$alnFile") or die "Couldn't open $alnFile: $!\n";
	
	printf ALN "%".$maxLen."s", "";
	
	for (my $i = $digits; $i > 0; $i--) {
		foreach my $position (@$informativeSitesRef) {
			my $aaIndex = $position + 1;
			my $pattern = "(\\d)";
			for (my $j = 1; $j < $i; $j++) {
				$pattern .= "\\d";		
			}
			if ($aaIndex =~ /$pattern$/) {				
				print ALN $1;
			}else {
				print ALN " ";
			}
		}
		print ALN "\n";
		if ($i == 1) {
			print ALN "\n";
		}else {
			printf ALN "%".$maxLen."s", "";
		}	
	}
	
	print ALN $firstAlnLine,"\n";
	
	if ($sortRadio eq "y") {
		my $alnSortFields;
		
		for (my $i = $maxLen+1; $i <= @$informativeSitesRef+$maxLen; $i++) {
			push @$alnSortFields, $i;
		}
		my @alnSorted = fieldsort '', $alnSortFields, @{$param->{alnLines}};
		@alnOutputs = reverse @alnSorted;
	}
	
	foreach my $line (@alnOutputs) {
		$line =~ s/\t//g;
		print ALN $line,"\n";
	}
	close ALN;
}

sub WriteTabInsites {
	my ($TAB, $informativeSitesRef, $gapOnlySiteCount, $param, $sortRadio, $seqArr, $element, $datatype, $nasRef, $infoMutantRef, $infoMutStatusRef, $posMutHash) = @_;
	my $informativeCount = scalar @$informativeSitesRef;
	my $notGapOnlyInSitesCount = $informativeCount - $gapOnlySiteCount;
	my $alignAmbiCount = 0;
	foreach my $site (@$informativeSitesRef) {
		my $position = $site + 1;
		print $TAB "\t", $position;
		foreach my $na (keys %{$posMutHash->{$site}}) {
			if ($datatype eq 'nt' && $na !~ /[ACGTacgt\-]/) {
				$alignAmbiCount++;
				last;
			}elsif ($datatype eq 'aa' && $na eq 'X') {
				$alignAmbiCount++;
				last;
			}
		}
	}
	print $TAB "\n";
		
	my $firstLine = shift @{$param->{lines}};
	print $TAB $firstLine,"\n";
	my @tabOutputs = @{$param->{lines}}; 
	
	if ($sortRadio eq "y") {
		my $tabSortFields;
		
		for (my $i = 5; $i <= $informativeCount+4; $i++) {
			push @$tabSortFields, $i;
		}	
		my @tabSorted = fieldsort '\t', $tabSortFields, @{$param->{lines}};
		@tabOutputs = reverse @tabSorted;
	}
	
	foreach my $line (@tabOutputs) {
		print $TAB $line,"\n";
	}
	
	print $TAB "\nAlignment\t$informativeCount\t$notGapOnlyInSitesCount\t$alignAmbiCount\n";
	
	# calculate the total na/aa at each informative site
	my (%totalNAcount, $naCount, $infoSiteMutation, $totalMutation, %mutationStatus, @mutations);
	foreach my $position (@$informativeSitesRef) {
		my $count = 0;
		my $consAa = $seqArr->[0]->[$position];
		for (my $i = 1; $i < $element; $i++) {	# exclude CON
			my $aa = $seqArr->[$i]->[$position];
	
			unless ($aa eq " ") {
				unless ($aa eq "?") {
					if ($aa eq ".") {
						$aa = $consAa;
					}
					if (!$naCount->{$position}->{$aa}) {
						$naCount->{$position}->{$aa} = 0;
					}
					$naCount->{$position}->{$aa}++;
				}			
				$count++;
			}
		}
		$totalNAcount{$position} = $count;
		
		# calculate mutation information (will exclude gap to na and na to gap)
		unless ($consAa eq "-") {
			foreach my $na (sort keys %{$posMutHash->{$position}}) {
				unless ($na eq $consAa || $na eq "-") {
					my $mutation = $consAa."-".$na;
					$infoSiteMutation->{$position}->{$mutation} = 1;
					if (!$totalMutation->{$mutation}) {
						$totalMutation->{$mutation} = 0;
					}
					$totalMutation->{$mutation}++;
					if (!$mutationStatus{$mutation}) {
						$mutationStatus{$mutation} = 1;
						push @mutations, $mutation;
					}
				}
			}
		}
	}
	
	foreach my $na (sort @$infoMutantRef) {
		print $TAB "\t\t\t$na";
		foreach my $position (@$informativeSitesRef) {
			my $count = 0;
			if ($naCount->{$position}->{$na}) {
				$count = $naCount->{$position}->{$na};
			}				
			print $TAB "\t",$count;
		}
		print $TAB "\n";
	}
	
	foreach my $an (@$nasRef) {
		unless ($infoMutStatusRef->{$an}) {
			print $TAB "\t\t\t$an";
			foreach my $position (@$informativeSitesRef) {
				print $TAB "\t0";
			}
			print $TAB "\n";
		}
	}
	
	print $TAB "\t\t\tTotal";
	foreach my $position (@$informativeSitesRef) {
		print $TAB "\t",$totalNAcount{$position};
	}
	print $TAB "\n\n";
	
	# write mutation information
	print $TAB "\t\t\tTypes of Mutation";
	foreach (@$informativeSitesRef) {
		print $TAB "\t";
	}
	print $TAB "\tTotal\n";
#	# only for existing mutation types
#	foreach my $mutation (sort @mutations) {
#		print $TAB "\t\t\t$mutation";
#		foreach my $position (@$informativeSitesRef) {
#			my $count = 0;
#			if ($infoSiteMutation->{$position}->{$mutation}) {
#				$count = $infoSiteMutation->{$position}->{$mutation};
#			}
#			print $TAB "\t",$count;
#		}
#		print $TAB "\t", $totalMutation->{$mutation}, "\n";
#	}	
	# for all possible mutaion types including ambiguities
	my (@mutation_types, @all_nas);
	if ($datatype eq "nt") {		
		my @ambi_nas = qw (R Y K M S W B D H V N);
		push @all_nas, @$nasRef, @ambi_nas;
	}else {
		push @all_nas, @$nasRef, "X";
	}
	for (my $i = 0; $i < @all_nas; $i++) {
		for (my $j = 0; $j < @all_nas; $j++) {
			unless ($i == $j) {
				my $mut_type = $all_nas[$i]."-".$all_nas[$j];
				push @mutation_types, $mut_type;
			}
		}
	}
	foreach my $mutation (@mutation_types) {
		print $TAB "\t\t\t$mutation";
		foreach my $position (@$informativeSitesRef) {
			my $count = 0;
			if ($infoSiteMutation->{$position}->{$mutation}) {
				$count = $infoSiteMutation->{$position}->{$mutation};
			}
			print $TAB "\t",$count;
		}
		if ($totalMutation->{$mutation}) {
			print $TAB "\t", $totalMutation->{$mutation}, "\n";
		}else {
			print $TAB "\t0\n";
		}		
	}	
}


1; #TRUE!!
 
