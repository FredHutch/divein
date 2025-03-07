package Diver;

use strict;
use warnings;
use Divein;
use Bio::TreeIO;
use Bio::Tree::TreeFunctionsI;
use Carp qw[croak carp];


=head1 NAME

Common -- package for  routines used in diver

=head1 SYNOPSIS


=head1 METHODS


=cut


our $hyphyDir 				= '/var/www/html/HYPHY';	# hyphy-r592
our $hyphyExecutable 		= '/usr/local/bin/HYPHYMP';	# hyphy-r592
our $phymlExecutable		= '/usr/local/bin/phyml';

our $fasttreeExecutable		= '/usr/local/bin/FastTreeDbl';
our $raxmlExecutable		= '/usr/local/bin/raxmlHPC-PTHREADS';

our $figtreeExecutable      = '/usr/local/bin/figtree.jar';

sub GetOutgroup {
	my ($outgrpFileLines) = @_;
	my (@outgroups, @stdOutgrps, @outgrpInfo, %outgrpStatus);
	
	foreach my $line (@$outgrpFileLines) {
		next if $line =~ /^\s*$/;
		$line = Divein::CleanString ($line);
		if (!$outgrpStatus{$line}) {
			push @outgroups, $line;	
			$line =~ s/\W/_/g;
			push @stdOutgrps, $line;
			$outgrpStatus{$line} = 1;
		}		
	}

	if (!@outgroups) {
		print "<p>Error: Couldn't get sequence names from outgroup file. Please check the outgroup file.</p>";
		Divein::PrintFooter();
	}
	push @outgrpInfo, \@outgroups, \@stdOutgrps;
	return \@outgrpInfo;
}

sub GetIngroup {
	my $grpFileLines = shift;
	my (@ingroups, @grpNstdseqnames, @grpInfo, %seqGrp);
	foreach my $line (@$grpFileLines) {
		next if $line =~ /^\s*$/;
		$line = Divein::CleanString ($line);
		my ($group, $seqName) = split /\t/, $line;
		$seqName = Divein::CleanString ($seqName);
		$group = Divein::CleanString ($group);
		if (defined $group && defined $seqName) {
			if (!$seqGrp{$seqName}) {
				$seqGrp{$seqName} = $group;
				push @ingroups, $seqName;
				$seqName =~ s/\W/_/g;
				$group = "MRCA" if ($group =~ /^MRCA$/i);
				my $grpNstdseqname = $group."\t".$seqName;
				push @grpNstdseqnames, $grpNstdseqname;
			}else {
				if ($seqGrp{$seqName} ne $group) {
					print "<p>Error: sequence $seqName was assigned into two different groups: $group and $seqGrp{$seqName}.</p>";
					Divein::PrintFooter();
				}
			}			
		}else {
			print "<p>Here it is! No group and sequence name pair for group: $group and sequence: $seqName in group file.</p>";
			Divein::PrintFooter();
		}
	}

	if (!@ingroups) {
		print "<p>Error: Couldn't get sequence names from defined group file. Please check the group file.</p>";
		Divein::PrintFooter();
	}
	push @grpInfo, \@ingroups, \@grpNstdseqnames;
	return \@grpInfo;
}

sub CheckNameMatch {
	my ($seqNamesRef, $outgroupRef, $ingroupRef) = @_;
	my %seqNamesHash;
	foreach my $seqName (@$seqNamesRef) {
		$seqNamesHash{$seqName} = 1;		
	}
	
	if ($outgroupRef && $ingroupRef) {
		my (%outgrpSeqHash, %ingrpSeqHash);
		foreach my $outgrpSeq (@$outgroupRef) {
			$outgrpSeqHash{$outgrpSeq} = 1;
		}
		foreach (@$ingroupRef) {
			if ($outgrpSeqHash{$_}) {
				print "<p>Error: The sequence name $_ exists in both ingroup and outgroup file.</p>";
				Divein::PrintFooter();
			}
		} 
	}
	if ($outgroupRef) {
		foreach (@$outgroupRef) {
			if (!$seqNamesHash{$_}) {
				print "<p>Error: Outgroup sequence name $_ doesn't match sequence name in alignment file.</p>";
				Divein::PrintFooter();
			}
		}
	}
	if ($ingroupRef) {
		foreach (@$ingroupRef) {
			if (!$seqNamesHash{$_}) {
				print "<p>Error: Ingroup sequence name $_ doesn't match sequence name in alignment file.</p>";
				Divein::PrintFooter();
			}
		}
	}
}

sub GetOutgrpStatus {
	my ($id, $outgroupFile, $email) = @_;
	my (@outgroup, %outgrpStatus);
	
	open(IN, $outgroupFile) || die SendEmail ($email, $id, "Error", "Couldn't open $outgroupFile: $!");
	while(my $outgrpName = <IN>) {
		chomp $outgrpName;
		next if ($outgrpName =~ /^\s*$/);
		if($outgrpName) {
			push(@outgroup, $outgrpName);
			$outgrpStatus{$outgrpName} = 1;
		}
	}
	close IN;

	return (\@outgroup, \%outgrpStatus);
}

sub GetGrpAlignment {
	my ($id, $phylipFile, $outgrpStatus, $email) = @_;
	my (@grpAlignments, $seqNum, $alignLen, %diverStatus);
	open(IN, $phylipFile) || die SendEmail ($email, $id, "Error", "Couldn't open $phylipFile: $!");
	while(my $line = <IN>) {
		chomp $line;
		next if ($line =~ /^\s*$/);
		if ($line =~ /^(\d+)\s+(\d+)/) {
			$seqNum = $1;
			$alignLen = $2;
		}elsif ($line =~ /^(\S+)\s+/) {
			my $name = $1;
			if ($outgrpStatus->{$name}) {
				$seqNum--;
			}else {
				$diverStatus{$name} = 1;
				push @grpAlignments, $line;
			}
		}
	}
	close IN;
	return (\@grpAlignments, $seqNum, $alignLen, \%diverStatus);
}

sub StripGaps {
	my ($grpAlignments, $alignLen) = @_;
	my (@seqNames, @gapstripAlignments, %nameSeq);
	my $gapstripAlignLen = $alignLen;
	foreach my $line (@$grpAlignments) {
		if ($line =~ /^(\S+)\t(\S+)$/) {
			my $seqName = $1;
			my $seq = $2;
			push @seqNames, $seqName;
			my @nas = split //, $seq;
			$nameSeq{$seqName} = \@nas;
		}
	}
	 
	for (my $i = 0; $i < $alignLen; $i++) {
		my $flag = 0;
		foreach my $seqName (@seqNames) {
			unless ($nameSeq{$seqName}->[$i] eq '-') {
				$flag = 1;
				last;
			}
		}
		unless ($flag) {
			$gapstripAlignLen--;
			foreach (@seqNames) {
				$nameSeq{$_}->[$i] = '';
			}
		}
	}
	foreach (@seqNames) {
		my $gapstripAlignment = $_."\t".join ('', @{$nameSeq{$_}});
		push @gapstripAlignments, $gapstripAlignment;
	}
	return (\@gapstripAlignments, $gapstripAlignLen);
}

sub GetPhymlTree {
	my $phymlOutTreeFile = shift;
	my $input = new Bio::TreeIO(-file   => $phymlOutTreeFile,
                                -format => "newick");

	my $tree = $input->next_tree;
	return $tree;
}

sub CheckMonophyletic {
	my ($treeObj, $outgroupListRef, $id, $email) = @_;
	my (@ingroupNodes, @outgroupNodes, %outgroupNodesHash);

	foreach (@$outgroupListRef) {
		my $outgrpNode = $treeObj->find_node(-id => $_);
		if ($outgrpNode) {
			push @outgroupNodes, $outgrpNode;
			$outgroupNodesHash{$outgrpNode} = 1;
		}else {
			my $errorMsg = "No sequence $_ in tree\n";
			die SendEmail ($email, $id, "Error", $errorMsg);
		}
		
	}
	my @taxa = $treeObj->get_leaf_nodes;
	foreach my $taxon (@taxa) {
		unless ($outgroupNodesHash{$taxon}) {
			push @ingroupNodes, $taxon;
		}
	}
	my $monophyleticFlag;
	foreach my $outgroup (@outgroupNodes) {
		if( $treeObj->is_monophyletic(-nodes => \@ingroupNodes, -outgroup => $outgroup) ) {
			$monophyleticFlag = 1;
		}else {
			$monophyleticFlag = 0;
			last;
		}
	}
	return $monophyleticFlag;
}

sub RerootTree {
	my ($id, $phymlTree, $outgroupListRef, $phymlOutTreeFile, $email) = @_;
	my (@outgroupNodes, @outgroupNodesCopy);
	foreach (@$outgroupListRef) {
		my $outgrpNode = $phymlTree->find_node(-id => $_);
		if ($outgrpNode) {
			push @outgroupNodes, $outgrpNode;
		}else {
			my $errorMsg = "No sequence $_ in tree\n";
			die SendEmail ($email, $id, "Error", $errorMsg);
		}		
	}
	# find common ancestor of outgroup
	while (@outgroupNodes > 1) {
		my $ancester = $phymlTree->get_lca(-nodes => [shift @outgroupNodes, shift @outgroupNodes]);
		push @outgroupNodes, $ancester;
	}
	my $lca = shift @outgroupNodes;
	# re-root tree
	if ($phymlTree->reroot($lca)) {
		my $out = new Bio::TreeIO(-file => ">$phymlOutTreeFile", -format => 'newick');
		$out->write_tree($phymlTree);		
	}
	return $phymlTree;	# re-rooted tree object
}

sub InsertNodeId {
	my ($tree, $phymlOutRerootTreeNodeFile) = @_;
	my $nodeIndex = 0;
	my @nodes = $tree->get_nodes;
	foreach my $node (@nodes) {	
		unless ($node->is_Leaf) {
			$nodeIndex++;
			my $id = "InNode".$nodeIndex;
			$node->id($id); 
		}
	}
	
	my $out = new Bio::TreeIO(-file => ">$phymlOutRerootTreeNodeFile", -format => 'newick');
	$out->write_tree($tree);
}

sub AppendTree2Fasta {
	my ($phymlTreeFile, $fastaFile) = @_;
	open(IN, $phymlTreeFile) || die "cann't open phyml tree file: $phymlTreeFile\n";
	my $tree;
	while (<IN>) {
		chomp;
		$tree = $_;
	}
	close IN;
	my $fastaFileWithTree = $fastaFile."_tree";
	open IN, $fastaFile or die "Couldn't open $fastaFile: $!\n";
	open OUT, ">$fastaFileWithTree" or die "Couldn't open $fastaFileWithTree: $!\n";
	while (<IN>) {
		print OUT $_;
	}
	print OUT "\n\n$tree\n";
	return $fastaFileWithTree;
}

sub GetMRCANodeId {
	my ($rerootNodeTree, $outgroupListRef) = @_;
	my (@ingroupNodes, %outgroupNodesHash);
	foreach (@$outgroupListRef) {
		my $outgrpNode = $rerootNodeTree->find_node(-id => $_);
		if ($outgrpNode) {
			$outgroupNodesHash{$outgrpNode} = 1;
		}
	}
	my @taxa = $rerootNodeTree->get_leaf_nodes;
	foreach my $taxon (@taxa) {
		unless ($outgroupNodesHash{$taxon}) {
			push @ingroupNodes, $taxon;
		}
	}
	
	while (@ingroupNodes > 1) {
		my $lca = $rerootNodeTree->get_lca(-nodes => [shift @ingroupNodes, shift @ingroupNodes]);
		push @ingroupNodes, $lca;
	}
	my $mrcaNode = shift @ingroupNodes;
	return $mrcaNode->id();
}

sub GetModelIndex {
	my ($subModel) = @_;
	my $modelIdx = 0;
	if ($subModel eq "JC69") {
		$modelIdx = 1;
	}elsif ($subModel eq "HKY85") {
		$modelIdx = 2;
	}elsif ($subModel eq "F81") {
		$modelIdx = 4;
	}elsif ($subModel eq "K80") {
		$modelIdx = 5;
	}elsif ($subModel eq "TN93") {
		$modelIdx = 6;
	}else {
		$modelIdx = 3; # GTR 
	}
	return $modelIdx;
}

sub ComposeBatchFile {
	my ($aaAncestorBatchFile, $templateBatchFile, $aaModel, $hyphyDir) = @_;
	open IN, $templateBatchFile or die "couldn't open $templateBatchFile: $!";
	open OUT, ">$aaAncestorBatchFile" or die "couldn't open $aaAncestorBatchFile: $!";
	while (my $line = <IN>) {
		chomp $line;
		if ($line =~ /options \[\"1\"\]/) {
			$line = "options [\"1\"] = \"$hyphyDir/TemplateBatchFiles/TemplateModels/EmpiricalAA/"."$aaModel\";";
		}elsif ($line =~ /ExecuteAFile/) {
			$line = "ExecuteAFile (\"$hyphyDir/TemplateBatchFiles/TemplateModels/Custom_AA_empirical.mdl\", options);";
		}
		print OUT "$line\n";
	}
	close IN;
	close OUT;
}

sub GetMrcaSeq {
	my ($id, $hyphyOutFile, $mrcaNodeId, $email) = @_;
	my $seqFlag = my $errorFlag = 0;
	my $mrcaSeq = my $errorMsg = "";
	open IN, $hyphyOutFile or die "Couldn't open $hyphyOutFile: $!\n";
	while (my $line = <IN>) {
		chomp $line;
		next if ($line =~ /^\s*$/);
		if ($line =~ /^Error:/i) {	# Error massage from running Hyphy
			$errorFlag = 1;
			$errorMsg .= $line."\n";
		}elsif ($errorFlag) {
			$errorMsg .= $line."\n";
		}elsif ($line eq "#$mrcaNodeId") {
			$seqFlag = 1;
		}elsif ($seqFlag) {
			$mrcaSeq = $line;
			last;
		}
	}
	close IN;
	
	if ($errorFlag) {	# Error in running Hyphy
		die SendEmail ($email, $id, "Error", $errorMsg);
	} 
	return $mrcaSeq;
}

sub RefineMRCA {
	my ($hyphyMrcaSeq, $grpAlignments, $alignLen) = @_;
	my (@seqNames, %nameSeq);
	foreach my $line (@$grpAlignments) {
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
			if ($nameSeq{$seqName}->[$i] eq "-") {
				$dashFlag = 1;
			}else {
				$dashFlag = 0;
				last;
			}
		}
		if ($dashFlag) {
			substr ($hyphyMrcaSeq, $i, 1, "_");
		}
	}
	$hyphyMrcaSeq =~ s/\_/\-/g;
	
	return $hyphyMrcaSeq;
}

sub GetGrpSeqStatus {
	my $grpFile = shift;
	my (%grpSeqStatus, @groups, $grpSeqs, %grpStatus);
	open IN, $grpFile or die "Couldn't open $grpFile: $!\n";
	while (my $line = <IN>) {
		chomp $line;
		next if ($line =~ /^\s*$/);
		my ($grp, $seqName) = split /\t/, $line;
		$grpSeqStatus{$seqName} = 1;
		unless ($grpStatus{$grp}) {
			$grpStatus{$grp} = 1;
			push @groups, $grp;
		}
		push @{$grpSeqs->{$grp}}, $seqName;
	}
	close IN;
	return (\%grpSeqStatus, \@groups, $grpSeqs);
}

sub GetTreeDists {
	my ($treeFile) = @_;
	my $blDistHash;
	
	my $input = new Bio::TreeIO(-file   => $treeFile,
                                -format => "newick");

	my $treeObj = $input->next_tree;
	my @leafNodes = $treeObj->get_leaf_nodes;
	while (@leafNodes > 1) {
		my $firstNode = shift @leafNodes;
		my $firstNodeId = $firstNode->id();
		foreach my $ingroupNode (@leafNodes) {
			my $secondNodeId = $ingroupNode->id();
			my $Nodedist = $treeObj->distance(-nodes => [$firstNode, $ingroupNode]);
			$blDistHash->{$firstNodeId}->{$secondNodeId} = $blDistHash->{$secondNodeId}->{$firstNodeId} = $Nodedist;
		}
	}
	return $blDistHash;
}

sub GetPairwiseDists {
	my ($phymlOutFile) = @_;
	my (@seqNames, @seqnNames, $pwDistHash);	
	my $flag = my $count = 0;
	open IN, $phymlOutFile or die "Couldn't open $phymlOutFile: $!\n";
	while (my $line = <IN>) {
		chomp $line;
		next if ($line =~ /^\s*$/);
		if ($line =~ /Distance\s+matrix\s+\(after\s+optimisation\)/) {
			$flag = 1;
			next;
		}
		if ($flag && $line =~ /^(\d+)$/) {
			$count = $1;
			next;
		}
		if ($line =~ /^\./) {
			$flag = 0;
		}
		if ($flag) {
			if ($line =~ /^(.*)$/) {
				my $seqnName = $1;				
				push @seqnNames, $seqnName;
				$seqnName =~ /^(\S+)\s+/;
				my $seqName = $1;
				push @seqNames, $seqName;
			}
		}
	}
	close IN;
	foreach my $seqnName (@seqnNames) {
		$seqnName =~ /^(\S+)\s+(\S+)(.*)$/;
		my $name = $1;
		my $dists = $2.$3;	
		my @distances = split /\s+/, $dists;
		for (my $i = 0; $i < scalar @distances; $i++) {
			unless ($name eq $seqNames[$i]) {					
				$pwDistHash->{$name}->{$seqNames[$i]} = $distances[$i];				
			}
		}		
	}
	return $pwDistHash;
}

sub WriteColumnDistFile {
	my ($groups, $grpSeqs, $ColDistFile, $DistHash, $divergence, $errLog, $grpStatus) = @_;
	
#	my (%seqGrpHash, @groups, %grpStatus, $grpNameDist, $grpDist);
	open OUT, ">", $ColDistFile or die print $errLog "Couldn't open $ColDistFile: $!\n";
	print OUT "Group1\tGroup2\tId1\tId2\tDistance\n";
	if ($divergence) {
		my @names = split /\,/, $divergence;
		foreach my $name (@names) {
			if ($name eq 'MRCA') {
				foreach my $group (@$groups) {
					foreach my $seqName (@{$grpSeqs->{$group}}) {
						if (defined $DistHash->{DIVEIN_MRCA}->{$seqName}) {
							print OUT "MRCA\t$group\tDIVEIN_MRCA\t$seqName\t$DistHash->{DIVEIN_MRCA}->{$seqName}\n";
						}elsif (defined $DistHash->{seqName}->{DIVEIN_MRCA}) {
							print OUT "MRCA\t$group\tDIVEIN_MRCA\t$seqName\t$DistHash->{seqName}->{DIVEIN_MRCA}\n";
						}else {
							print $errLog "Error: no distance value between MRCA and $seqName\n";
						}				
					}
				}
			}elsif ($name eq 'Consensus') {
				foreach my $group (@$groups) {
					foreach my $seqName (@{$grpSeqs->{$group}}) {
						print OUT "Consensus\t$group\tDIVEIN_Consensus\t$seqName\t$DistHash->{DIVEIN_Consensus}->{$seqName}\n";
						print $errLog "Error: no distance value between Consensus and $seqName\n" if (!defined $DistHash->{DIVEIN_Consensus}->{$seqName})				
					}
				}
			}elsif ($name eq 'COT') {
				foreach my $group (@$groups) {
					foreach my $seqName (@{$grpSeqs->{$group}}) {
						print OUT "COT\t$group\tDIVEIN_COT\t$seqName\t$DistHash->{DIVEIN_COT}->{$seqName}\n";
						print $errLog "Error: no distance value between COT and $seqName\n" if (!defined $DistHash->{DIVEIN_COT}->{$seqName});				
					}
				}
			}elsif (!$grpStatus->{$name}) {
				foreach my $group (@$groups) {
					foreach my $seqName (@{$grpSeqs->{$group}}) {
						if (defined $DistHash->{$name}->{$seqName}) {
							print OUT "$name\t$group\t$name\t$seqName\t$DistHash->{$name}->{$seqName}\n";
						}elsif (defined $DistHash->{$seqName}->{$name}) {
							print OUT "$name\t$group\t$name\t$seqName\t$DistHash->{$seqName}->{$name}\n";
						}else {
							print $errLog "Error: no distance value between $name and $seqName\n";
						}
					}
				}
			}
		}
	}
	
	my @groups_copy = @$groups;
	
	while (@groups_copy) {
		my $firstgrp = shift @groups_copy;
		my @firstgrpSeqs = @{$grpSeqs->{$firstgrp}};
		for (my $i = 0; $i < @firstgrpSeqs; $i++) {	# print distance between same group
			my $firstName = $firstgrpSeqs[$i];
			for (my $j = $i+1; $j < @firstgrpSeqs; $j++) {
				my $secondName = $firstgrpSeqs[$j];
				print OUT "$firstgrp\t$firstgrp\t$firstName\t$secondName\t$DistHash->{$firstName}->{$secondName}\n";
				print $errLog "Error: no distance value between $firstName and $secondName\n" if (!defined $DistHash->{$firstName}->{$secondName});
			}
		}
		if (@groups_copy) {	# there is more groups, print out distances between different groups
			foreach my $secondgrp (@groups_copy) {
				my @secondgrpSeqs = @{$grpSeqs->{$secondgrp}};
				for (my $i = 0; $i < @firstgrpSeqs; $i++) {
					my $firstName = $firstgrpSeqs[$i];
					for (my $j = 0; $j < @secondgrpSeqs; $j++) {
						my $secondName = $secondgrpSeqs[$j];
						print OUT "$firstgrp\t$secondgrp\t$firstName\t$secondName\t$DistHash->{$firstName}->{$secondName}\n";
						print $errLog "Error: no distance value between $firstName and $secondName\n" if (!defined $DistHash->{$firstName}->{$secondName});
					}
				}
			}
		}
	}
}

sub WriteDivergenceFile {
	my ($divergenceFile, $groups, $grpSeqs, $distHashRef, $commonSeq) = @_;
	open(OUT, ">$divergenceFile") or die "Couldn't open divergence output file $divergenceFile: $!\n";
	print OUT "Group\tNumber of sequences\tMean\tStandard error\tMin\tQ1\tMedian\tQ3\tMax\n";
	foreach my $group (@$groups) {
		my @divergence;
		my $seqcount = 0;
		for my $seq (@{$grpSeqs->{$group}}) {	
			unless ($commonSeq eq $seq) {	# for the case of divergence for a specific sequence
				push @divergence, $distHashRef->{$commonSeq}->{$seq};
			}
			++$seqcount;			
		}
		
		if (@divergence) {
			my @divergenceResult = DoStatistics(@divergence);
			print OUT "$group\t$seqcount";
			foreach (@divergenceResult) {
				my $value = int ($_ * 100000000 + 0.5) / 100000000;
				print OUT "\t$value";
			}
			print OUT "\n";
		}
	}
	close OUT;
}

sub CalculateDivergence {
	my ($divergenceFilePrefix, $groups, $grpSeqs, $divergences, $distHashRef) = @_;
	my @diverseqNames = split /,/, $divergences;
	foreach my $seqName (@diverseqNames) {
		if ($seqName eq "MRCA") {
			my $divergenceFile = $divergenceFilePrefix.'_MRCA.txt';
			WriteDivergenceFile ($divergenceFile, $groups, $grpSeqs, $distHashRef, 'DIVEIN_MRCA');
		}elsif ($seqName eq "Consensus") {
			my $divergenceFile = $divergenceFilePrefix.'_Cons.txt';
			WriteDivergenceFile ($divergenceFile, $groups, $grpSeqs, $distHashRef, 'DIVEIN_Consensus');
		}elsif ($seqName eq "COT") {
			my $divergenceFile = $divergenceFilePrefix.'_COT.txt';
			WriteDivergenceFile ($divergenceFile, $groups, $grpSeqs, $distHashRef, 'DIVEIN_COT');
		}else {			
			my $divergenceFile = $divergenceFilePrefix.'_'.$seqName.'_Seq.txt';
			WriteDivergenceFile ($divergenceFile, $groups, $grpSeqs, $distHashRef, $seqName);					
		}		
	}	
}

sub CalculateDiversity {
	my ($diversityFile, $groups, $grpSeqs, $DistHashRef, $errLog) = @_;	
	open OUT, ">$diversityFile" || die "Couldn't open diversity output file $diversityFile: $!\n";
	print OUT "Group\tNumber of sequences\tMean\tStandard error\tMin\tQ1\tMedian\tQ3\tMax\n";
	foreach my $group (@$groups) {
		my @diversity;
		my @grpSeqnames = @{$grpSeqs->{$group}};
		if (scalar @grpSeqnames == 1) {	# for the case of only one sequence in the group
			push @diversity, 0;
		}else {	# at least two sequences in the group
			for (my $i = 0; $i < @grpSeqnames; $i++) {	# print distance between same group
				my $firstName = $grpSeqnames[$i];
				for (my $j = $i+1; $j < @grpSeqnames; $j++) {
					my $secondName = $grpSeqnames[$j];
					push @diversity, $DistHashRef->{$firstName}->{$secondName};
					print $errLog "Error: no distance value between $firstName and $secondName\n" if (!defined $DistHashRef->{$firstName}->{$secondName});
				}
			}
		}
		
		if (@diversity) {
			my $seqcount = scalar @grpSeqnames;
			my @diversityResult = DoStatistics(@diversity);
			print OUT "$group\t$seqcount";
			foreach (@diversityResult) {
				my $value = int ($_ * 100000000 + 0.5) / 100000000;
				print OUT "\t$value";
			}
			print OUT "\n";
		}
	}
	close OUT;
}

sub CalculateBtwDist {
	my ($btwGrpDistFile, $groups, $grpSeqs, $DistHashRef, $errLog) = @_;
	open OUT, ">$btwGrpDistFile" or die "Couldn't open $btwGrpDistFile: $!\n";
	print OUT "Group1\tNumber of sequences\tGroup2\tNumber of sequences\tMean\tStandard error\tMin\tQ1\tMedian\tQ3\tMax\n";
	for (my $i = 0; $i < @$groups; $i++) {
		my $firstGrp = $groups->[$i];
		my @firstgrpSeqs = @{$grpSeqs->{$firstGrp}};
		for (my $j = $i+1; $j < @$groups; $j++) {
			my $secondGrp = $groups->[$j];
			my @secondgrpSeqs = @{$grpSeqs->{$secondGrp}};
			my @betweenGroupDists;
			for (my $k = 0; $k < @firstgrpSeqs; $k++) {
				my $firstName = $firstgrpSeqs[$k];
				for (my $l = 0; $l < @secondgrpSeqs; $l++) {
					my $secondName = $secondgrpSeqs[$l];
					push @betweenGroupDists, $DistHashRef->{$firstName}->{$secondName};
					print $errLog "Error: no distance value between $firstName and $secondName\n" if (!defined $DistHashRef->{$firstName}->{$secondName});
				}
			}
			if (@betweenGroupDists) {
				my $seqcount1 = scalar @firstgrpSeqs;
				my $seqcount2 = scalar @secondgrpSeqs;
				my @betweenGroupDistsResult = DoStatistics (@betweenGroupDists);
				print OUT "$firstGrp\t$seqcount1\t$secondGrp\t$seqcount2";
				foreach (@betweenGroupDistsResult) {
					my $value = int ($_ * 100000000 + 0.5) / 100000000;
					print OUT "\t$value";
				}
				print OUT "\n";
			}
		}
	}
	close OUT;
}

sub DoStatistics {
	my @diverArray = @_;
	@diverArray = sort {$a<=>$b} @diverArray;
	
	my ($avg, $std, $sem, $median, $q1, $q3, $min, $max, $arraySize);
	my @resultArray = ();
	$arraySize = scalar @diverArray;
	
	# calculate average
	my $diver = 0;
	foreach (@diverArray) {
		$diver += $_;
	}
	$avg = $diver / $arraySize;
	
	# calculate standard deviation
	my $squareSum = 0;
	foreach (@diverArray) {
		$squareSum += ($_ - $avg)*($_ - $avg);
	}
	if($arraySize == 1) {
		$std = 0;
	}else {
		$std = sqrt($squareSum / ($arraySize - 1));
	}
	$sem = $std / sqrt($arraySize);
	
	# calculate median, first quartile, third quartile
	if($arraySize == 1) {
		$median = $min = $q1 = $max = $q3 = $avg;
	}elsif($arraySize == 2) {
		$median = $avg;
		$min = $q1 = $diverArray[0];
		$max = $q3 = $diverArray[1];
	}elsif($arraySize == 3) {
		$median = $diverArray[1];
		$min = $q1 = $diverArray[0];
		$max = $q3 = $diverArray[2];
	}else {
		my $middle = int($arraySize / 2);
		my @firstHalf;
		my @secondHalf;
		my $secondHalfStart;
		
		if($arraySize % 2 == 0) {
			$secondHalfStart = $middle;					
		}else {
			$secondHalfStart = $middle + 1;
		}
		
		for(my $i = 0; $i < $middle; $i++) {
			push(@firstHalf, $diverArray[$i]);
		}
		for(my $i = $secondHalfStart; $i < $arraySize; $i++) {
			push(@secondHalf, $diverArray[$i]);
		}
		
		$median = GetMedian(@diverArray);
		$q1 = GetMedian(@firstHalf);
		$q3 = GetMedian(@secondHalf);
		$min = $diverArray[0];
		$max = $diverArray[$arraySize-1];
	}
	return ($avg, $sem, $min, $q1, $median, $q3, $max);
}

sub GetMedian {
	my @inArray = @_;
	my $arraySize = scalar @inArray;
	my $median;
	my $middle = int($arraySize / 2);
	
	if($arraySize % 2 == 0) {
		$median = ($inArray[$middle-1] + $inArray[$middle]) / 2;
	}else {
		$median = $inArray[$middle];
	}
	
	return $median;
}


1; #TRUE!!
 
