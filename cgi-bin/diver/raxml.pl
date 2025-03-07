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
# Modified: 2025-03-03 for docker container
######################################################################################################

use strict;
use Cwd;
use File::Basename;
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use Divein;
use Diver;
use Diver::DiverEmail;

my ($seqFileName, $seqType, $datatype, $bootstrap, $subModel);
my ($email, $diver, $id, $uploadDir, $ip, $divergences, $type, $docsRoot, $program, $heteromodel);
BEGIN {
	$id             = shift;	# job id
	$seqFileName    = shift;	# name of user uploaded sequence alingment file
	$seqType        = shift;	# sequence datatype for parameter output file (DNA or Protein)
	$datatype       = shift;	# sequence data type ('nt' or 'aa')
	$bootstrap      = shift;	# yes or no
	$subModel       = shift;	# substitution model
	$heteromodel    = shift;	# model of rate heterogeneity (GAMMA or CAT)
	$email          = shift;
	$diver		    = shift;	# format of divergence and diversity. "tree" or "pairwise" or "both"
	$uploadDir      = shift;	# directory for uploading files
	$ip             = shift;
	$divergences    = shift;
	$docsRoot       = shift;
	$program		= shift;
}

my $startTime = time();
my $raxmlExecutable = $Diver::raxmlExecutable;
my $hyphyDir = $Diver::hyphyDir;
my $hyphyExecutable = $Diver::hyphyExecutable;
my $figtree = $Diver::figtreeExecutable; 

if ($bootstrap > 0) {
	$type = 'bootstrap';		# compute aLRT only
}elsif ($diver eq "yes") {
	if ($divergences) {
		$type = 'diver';		# need to calculate divergence and diversity
	}else {
		$type = 'diversity';	# calculate diversity only
	}
	$diver = "tree";
}

chdir $uploadDir;
my $curdir = cwd();
my $logFile = $uploadDir.'/'.$id.'.log';
my $errFile = $uploadDir.'/'.$id.'.err';
my $errLog;
open $errLog, ">", $errFile or die "couldn't open $errFile: $!\n";
open (LOG, ">", $logFile) or die Diver::DiverEmail::SendEmail ($email, $id, "Error", "Couldn't open $logFile: $!\n");
print LOG "Project: raxml\nid: $id\ntype: $type\nseqFileName: $seqFileName\ndatatype: $datatype\n";
print LOG "bootstrap: $bootstrap\nsubModel: $subModel\n";
print LOG "Model of rate heterogeneity: $heteromodel\n";
print LOG "email: $email\nIP: $ip\nuploadDir: $uploadDir\ndiver: $diver\n";
print LOG "divergences: $divergences\n";
print LOG "current directory: $curdir\n";

my $parameterFile = $uploadDir.'/'.$id.'.parameters.txt';
open PARA, ">", $parameterFile or die Diver::DiverEmail::SendEmail ($email, $id, "Error", "Couldn't open $parameterFile: $!\n");
printf PARA ("%-45s%s%s", 'Input alignment sequence file:', $seqFileName, "\n");
printf PARA ("%-45s%s%s", 'Sequence data type:', $seqType, "\n");
printf PARA ("%-45s%s%s", 'Substitution model:', $subModel, "\n");
printf PARA ("%-45s%s%s", 'Model of rate hetetogeneity:', $heteromodel, "\n");
if ($bootstrap > 0) {
	printf PARA ("%-45s%s%s", 'Bootstrap:', $bootstrap, "\n");
}
if ($divergences) {
	printf PARA ("%-45s%s%s", 'Calculate divergence from:', $divergences, "\n");
}
close PARA;

my $uploadFile = $uploadDir.'/'."$id.sequence.txt";	# uploaded sequence file name
my $uploadOutgrpFile = $uploadDir.'/'."$id.outgrp.txt";		# uploaded outgroup file name if any
my $uploadgrpFile = $uploadDir.'/'."$id.group.txt";	# uploaded ingroup file name if any

my $phylipFile = $uploadFile;
my $fastaFile = $phylipFile.'.fas';
my ($seqCount, $seqLen, $nameSeq) = Divein::ChangetoFasta($phylipFile, $fastaFile);

my $raxmlOutFile = $phylipFile.'.raxml_stdout.txt';		# fasttree standard output file
my $raxmlLogFile = $phylipFile.'.raxml.log';				# fasttree output log file
my $raxmlOutTreeFile = $phylipFile.'_raxml_tree.tre';		# fasttree output newick tree file

my @cmd = ();
push @cmd, $raxmlExecutable, "-m", $heteromodel, "-p", $id;
if ($bootstrap) {
	push @cmd, "-T", 2, "-f", "a", "-x", $id, "-#", $bootstrap;
#	raxmlHPC -f a -m GTRGAMMA -p 12345 -x 12345 -# 100 -s dna.phy -n T20 
}else {
	push @cmd, "-T", 1;
}
if ($datatype eq "nt" and $subModel ne "GTR") {
	push @cmd, "--$subModel";
}
push @cmd, "-s", $phylipFile, "-n", "txt";

print LOG "RAxML: ", join (' ', @cmd), "\n";

# run first round raxml for original sequence alignment
open STDOUT, ">", $raxmlOutFile;
open STDERR, ">", $errFile;
my $val = system (@cmd);
if ($val == 0) {
	print LOG "success\n";
}else {
	print LOG "failed: $val\n";
}

die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'notree') if (-z $raxmlOutTreeFile);
if (-s $errFile) {
	open ERR, $errFile;
	my @lines = <ERR>;
	my $errMsg = join('', @lines);
	close ERR;
	die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
}

if ($bootstrap) {
	my $raxmlBootstrapFile = $phylipFile."_raxml_boot_trees.txt";
	rename "RAxML_bipartitions.txt", $raxmlOutTreeFile;
	rename "RAxML_bootstrap.txt", $raxmlBootstrapFile;
}else {
	rename "RAxML_bestTree.txt", $raxmlOutTreeFile;
}
rename "RAxML_info.txt", $raxmlLogFile;

if ($type eq 'diver' || $type eq 'diversity') {	# calculate divergence and/or diversity
	my ($distMatrixFile, $treeFile);	# for calculating pairwise and tree based distances
	# get group sequence information including group sequence status, how many groups and what sequences in each group
	my ($grpStatus, $groups, $grpSeqs) = Diver::GetGrpSeqStatus($uploadgrpFile);	
	if ($divergences) {	# calculate MRCA, Consensus, COT if applicable
		if ($divergences !~ /MRCA/ && $divergences !~ /Consensus/ && $divergences !~ /COT/) {	# only calculate divergence from a specific sequence, will need the distance value from first round fasttree 
			$treeFile = $raxmlOutTreeFile;
		}else {	# one or two or all of MRCA, Consensus and COT
			my ($outgroupList, $outgrpStatus);
			my $scdraxmlInputFile = $uploadDir.'/'.$id.'_diver_input.phy';
			if (-e $uploadOutgrpFile) {
				### remove outgrp sequences;
				($outgroupList, $outgrpStatus) = Diver::GetOutgrpStatus($id, $uploadOutgrpFile, $email);
			}
			# get array of group alignments
			my ($grpAlignments, $grpseqNum, $alignLen, $diverStatus) = Diver::GetGrpAlignment ($id, $phylipFile, $outgrpStatus, $email);
			my $seqNum = $grpseqNum;
			my @alignments = @$grpAlignments;			
			if ($divergences =~ /MRCA/) {
				# calculat MRCA;				
				# Check if ingroup nodes is monophyletic
				my $raxmlTree = Diver::GetPhymlTree ($raxmlOutTreeFile);	# Bioperl tree object of fasttree output newick tree
				my $monophyleticFlag = Diver::CheckMonophyletic ($raxmlTree, $outgroupList, $id, $email);	# flag for monophyletic test, return tree if ingroup is monophyletic
				print LOG "Initial monophyleticFlag: $monophyleticFlag\n";
				
				if (!$monophyleticFlag) {
					# first re-root the tree based on outgroup, and replace original fasttree tree with the re-rooted tree 
					my $rerootTree = Diver::RerootTree ($id, $raxmlTree, $outgroupList, $raxmlOutTreeFile, $email);
					# check monophyletic again for re-rooted tree
					$monophyleticFlag = Diver::CheckMonophyletic ($rerootTree, $outgroupList, $id, $email);
					print LOG "monophyleticFlag after re-root tree: $monophyleticFlag\n";
					if (!$monophyleticFlag) {
						die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'monophyletic', $type, $diver, $uploadDir, $seqFileName, $divergences, $program);
					}
				}
				
				# insert internal node id to rerooted tree
				my $raxmlOutTreeNodeFile 	= $phylipFile.'_raxml_tree_node.txt';	# tree file with inserted internal node id
				Diver::InsertNodeId ($raxmlTree, $raxmlOutTreeNodeFile); # now the $raxmlTree is rerooted tree object with inNode ids
		
				# get MRCA node id
				my $mrcaNodeId = Diver::GetMRCANodeId ($raxmlTree, $outgroupList);
				print LOG "MRCA node id: $mrcaNodeId\n";
				
				# append rerooted with internal node id newick tree to sequence fasta file for the input of hyphy program
				my $fastaFileWithTree = Diver::AppendTree2Fasta ($raxmlOutTreeNodeFile, $fastaFile);
				my $hyphyOutFile = $fastaFile.'.hyphy';	# output file of running hyphy program
				my $modelIdx = Diver::GetModelIndex ($subModel);
				if ($datatype eq "nt") {	# DNA sequences
					my $ancestors_nt_bf = $docsRoot."/Ancestors_nt.bf";
					system ("(echo $fastaFileWithTree; echo $modelIdx) | $hyphyExecutable $ancestors_nt_bf 1>$hyphyOutFile 2>$errFile");
					if (-s $errFile) {
						open ERR, $errFile;
						my @lines = <ERR>;
						my $errMsg = join('', @lines);
						close ERR;
						die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
					}
					print LOG "MRCA Hyphy: (echo $fastaFileWithTree; echo $modelIdx) | $hyphyExecutable $ancestors_nt_bf 1>$hyphyOutFile 2>$errFile\n";
				}else {	# amino-acid sequences
					my $templateBatchFile = $docsRoot."/Ancestors_aa_template.bf";
					my $aaAncestorBatchFile = $uploadDir.'/'."$id.aaAncestor.bf";	# batch file for construct ancestors' sequences
					my $hyphyAAModel = $subModel;
					Diver::ComposeBatchFile ($aaAncestorBatchFile, $templateBatchFile, $hyphyAAModel, $hyphyDir);	# compose batch file on the fly
					system ("echo $fastaFileWithTree | $hyphyExecutable $aaAncestorBatchFile 1>$hyphyOutFile 2>$errFile");
					if (-s $errFile) {
						open ERR, $errFile;
						my @lines = <ERR>;
						my $errMsg = join('', @lines);
						close ERR;
						die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
					}
					print LOG "MRCA Hyphy: echo $fastaFileWithTree | $hyphyExecutable $aaAncestorBatchFile 1>$hyphyOutFile 2>$errFile\n";
				}
						
				# get MRCA sequence from hyphy output
				my $hyphyMrcaSeq = Diver::GetMrcaSeq ($id, $hyphyOutFile, $mrcaNodeId, $email);
				print LOG "Hyphy MRCA: $hyphyMrcaSeq\n";
			
				# modify MRCA by place back "-" at universal "-" position and then strip gaps, because hyphy replaced "-" with "A" in MRCA at universal "-" position
				my $mrcaSeq = Diver::RefineMRCA ($hyphyMrcaSeq, $grpAlignments, $alignLen);
				print LOG "MRCA: $mrcaSeq\n";

				# add MRCA to grpAlignments
				push @alignments, "DIVEIN_MRCA\t$mrcaSeq";
				$seqNum++;
				
				# write MRCA to fasta file for user retrieving
				my $MRCAFile = $uploadDir.'/'.$id.'_MRCA.fas';	# fasta file containing MRCA sequence
				Divein::WriteSeq ($MRCAFile, $mrcaSeq, 'MRCA', 80);
			}
			
			if ($divergences =~ /Consensus/) {
				### calculat consensus;
				my $consensus = Divein::GetConsensus ($grpAlignments, $alignLen);
				print LOG "Consensus: $consensus\n";
				
				### append consensus;
				push @alignments, "DIVEIN_Consensus\t$consensus";
				$seqNum++;
				
				# write Consensus to fasta file for user retrieving
				my $consFile = $uploadDir.'/'.$id.'_cons.fas';
				Divein::WriteSeq ($consFile, $consensus, 'Consensus', 80); 
			}
			if ($divergences =~ /COT/) {
				### calculat COT;
				my $fastaFileWithTree;
				my $cot_phylip = $uploadDir.'/'.$id.'_cot_in.phy';
				my $cot_fasta = $uploadDir.'/'.$id.'_cot_in.fas';
				my @alignments4cot = @$grpAlignments;
				unshift @alignments4cot, "$grpseqNum\t$alignLen";			
				Divein::WriteFile($cot_phylip, \@alignments4cot);
				Divein::ChangetoFasta($cot_phylip, $cot_fasta);
				if (-e $uploadOutgrpFile) {	# there is outgrp file, remove outgrp sequences and do phyml without outgrp					
					my $cot_raxmlOutFile = $uploadDir.'/'.$id.'_cot.raxml';
					my $cot_raxmlOutTreeFile = $cot_phylip.'_raxml_tree.tre';		# raxml output newick tree file
					
					# run raxml for the alignment without outgroup
					my @cot_cmd = @cmd;
					pop @cot_cmd; #######
					pop @cot_cmd; #######
					pop @cot_cmd;
					push @cot_cmd, $cot_fasta, "-n", "cot.txt" ; ######
					print LOG "COT raxml: ", join(' ', @cot_cmd), "\n";
					open STDOUT, ">", $cot_raxmlOutFile;
					open STDERR, ">", $errFile;
					system(@cot_cmd);

					die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'notree') if (-z $cot_raxmlOutTreeFile);
					if (-s $errFile) {
						open ERR, $errFile;
						my @lines = <ERR>;
						my $errMsg = join('', @lines);
						close ERR;
						die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
					}
					@cot_cmd = ();
					rename "RAxML_bestTree.cot.txt", $cot_raxmlOutTreeFile;
					# append fasttree output tree to fasta file
					$fastaFileWithTree = Diver::AppendTree2Fasta ($cot_raxmlOutTreeFile, $cot_fasta);
				}else {	# no outgroup file, so can use initial outputed fasttree tree
					# append fasttree output tree to fasta file
					$fastaFileWithTree = Diver::AppendTree2Fasta ($raxmlOutTreeFile, $cot_fasta);
				}
				
				my $hyphyOutFile = $uploadDir.'/'.$id.'_cot.hyphy';
				my $cot_batch_file = $docsRoot.'/COT_nt.bf';
				if ($datatype eq 'aa') {	# amino acid
					$cot_batch_file = $docsRoot.'/COT_aa.bf';
				}
				system ("(echo $fastaFileWithTree; echo y) | $hyphyDir/HYPHYMP $cot_batch_file 1>$hyphyOutFile 2>$errFile");
				if (-s $errFile) {
					open ERR, $errFile;
					my @lines = <ERR>;
					my $errMsg = join('', @lines);
					close ERR;
					die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
				}
				print LOG "COT hyphy: (echo $fastaFileWithTree; echo y) | $hyphyDir/HYPHYMP $cot_batch_file 1>$hyphyOutFile 2>$errFile\n";
				
				# write COT tree and sequence
				my $cottreeFile = $uploadDir.'/'.$id.'_cot_out.tre';
				my $cottreeSeq = $uploadDir.'/'.$id.'_cot_out.fas';
				my ($cottree, $cotseq) = Divein::GetCOT ($hyphyOutFile, $cottreeFile, $datatype);
				$cotseq = Divein::CleanString ($cotseq);
				$cotseq =~ s/;$//;
				unless ($datatype eq "nt") {	# protein sequences
					$cotseq = Divein::RefineCOT ($cotseq, $grpAlignments, $alignLen);
				}
				### append COT;
				push @alignments, "DIVEIN_COT\t$cotseq";
				$seqNum++;
				
				# write COT to fasta file for user retrieving
				Divein::WriteSeq ($cottreeSeq, $cotseq, 'COT', 80); 
			}
			# write MRCA, Consensus, COT or sequences divergence from into a file if any
			my @divergenceNames = split /,/, $divergences;
			foreach my $name (@divergenceNames) {
				unless ($name eq 'MRCA' || $name eq 'COT' || $name eq 'Consensus') {
					if (!$diverStatus->{$name}) {
						$diverStatus->{$name} = 1;
						push @alignments, "$name\t$nameSeq->{$name}";
						$seqNum++;
					}					
				}
			}
			my $numNlen = $seqNum."\t".$alignLen;
			unshift @alignments, $numNlen;
			Divein::WriteFile ($scdraxmlInputFile, \@alignments);
			my $scdraxmlInputFastaFile = $scdraxmlInputFile;
			$scdraxmlInputFastaFile =~ s/.phy/.fas/;
			Divein::ChangetoFasta($scdraxmlInputFile, $scdraxmlInputFastaFile);
			### run second round raxml to get distance matrix;
			my $diverraxmlOutFile = $uploadDir.'/'.$id.'_diver.raxml';
			my $outTreeFile = $scdraxmlInputFastaFile.'_raxml_tree.tre';
			pop @cmd;
			pop @cmd;
			pop @cmd;
			push @cmd, $scdraxmlInputFastaFile, "-n", "divergence.txt";
			print LOG "Divergence raxml: ", join(' ', @cmd), "\n";
			open STDOUT, ">", $diverraxmlOutFile;
			open STDERR, ">", $errFile;
			system(@cmd);
			close STDOUT;
			close STDERR;
			die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'notree') if (-z $outTreeFile);
			if (-s $errFile) {
				open ERR, $errFile;
				my @lines = <ERR>;
				my $errMsg = join('', @lines);
				close ERR;
				die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
			}
			rename "RAxML_bestTree.divergence.txt", $outTreeFile;
			$treeFile = $outTreeFile;
		}
	}else {
		$treeFile = $raxmlOutTreeFile;
	}
	if ($diver eq 'tree') {
		my $tbDistHashRef = Diver::GetTreeDists ($treeFile);
		my $tbColDistFile = $uploadDir.'/'.$id.'_tbcoldist.txt';	# branch length column distance file
		# write column distance file 
		Diver::WriteColumnDistFile ($groups, $grpSeqs, $tbColDistFile, $tbDistHashRef, $divergences, $errLog, $grpStatus);
		if ($divergences) {	# calculate divergence and write to files
			my $tbDivergenceFilePrefix = $uploadDir.'/'.$id.'_tbdivergence';
			Diver::CalculateDivergence ($tbDivergenceFilePrefix, $groups, $grpSeqs, $divergences, $tbDistHashRef);
		}
		# calculate diversity and write to file
		my $tbDiversityFile = $uploadDir.'/'.$id.'_tbdiversity.txt';
		Diver::CalculateDiversity ($tbDiversityFile, $groups, $grpSeqs, $tbDistHashRef, $errLog);
		if (@$groups > 1) {	# more than one groups
			my $tbBtGrpDistFile = $uploadDir.'/'.$id.'_tbBtGrpDist.txt';
			Diver::CalculateBtwDist ($tbBtGrpDistFile, $groups, $grpSeqs, $tbDistHashRef, $errLog);
		}
	}	
}

# run FigTree
my $treeimage = $raxmlOutTreeFile;
$treeimage =~ s/\.tre$/.pdf/;
my @figtreecmd = ();
push @figtreecmd, 'java', '-jar', $figtree, '-graphic', 'PDF',  '-width', '800', '-height', '600', $raxmlOutTreeFile;
print LOG "FigTree: ", join (' ', @figtreecmd), "\n";
open STDOUT, ">", $treeimage;
open STDERR, ">", $errFile;
system(@figtreecmd);
close STDOUT;
close STDERR;

# link tree image file
my $localImageDir = $docsRoot."/treeImages";
my $treeimagename = basename($treeimage);
unless (-e $localImageDir) {
	mkdir $localImageDir, 0775;
}
my $linkfile = "$localImageDir/$treeimagename";
symlink($treeimage, $linkfile);

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
print STAT "$finishTime\t$id\t$seqCount\t$seqLen\t$datatype\t$type\t$subModel\t$ip\t$email\t$duration\t$program\n";
close STAT;

Diver::DiverEmail::SendEmail ($email, $id, 'Success', 'Normal', $type, $diver, $uploadDir, $seqFileName, $divergences, $program);

exit (0);



