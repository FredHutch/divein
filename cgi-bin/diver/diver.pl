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
use File::Basename;
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;
use Diver;
use Diver::DiverEmail;

my ($seqFileName, $seqType, $datatype, $bootstrap, $subModel, $freqRadio, $ttRatio, $proportion, $subRateCat, $gamma, $treeImprovType);
my ($opt, $email, $diverFormat, $id, $uploadDir, $ip, $divergences, $type, $program, $r_seed);
BEGIN {
	$id             = shift;	# job id
	$seqFileName    = shift;	# name of user uploaded sequence alingment file
	$seqType        = shift;	# sequence datatype for parameter output file (DNA or Protein)
	$datatype       = shift;	# sequence data type ('nt' or 'aa')
	$bootstrap      = shift;	# yes or no
	$subModel       = shift;	# substitution model
	$freqRadio      = shift;	# equilibrium frequencies
	$ttRatio        = shift;	# transition/transversion ratio
	$proportion     = shift;	# proportion of invariable sites
	$subRateCat     = shift;	# number of substitution rate categories
	$gamma          = shift;	# Gamma distribution parameter
	$treeImprovType = shift;	# type of tree improvement
	$opt            = shift;	# optimise topology, branch lengths or rate parameters
	$email          = shift;
	$diverFormat    = shift;	# format of divergence and diversity. "tree" or "pairwise" or "both"
	$uploadDir      = shift;	# directory for uploading files
	$ip             = shift;
	$divergences    = shift;
	$program        = shift;
	$r_seed         = shift;
}

my $startTime = time();
my $phymlExecutable = $Diver::phymlExecutable;
my $hyphyDir = $Diver::hyphyDir;
my $hyphyExecutable = $Diver::hyphyExecutable;
my $figtree = $Diver::figtreeExecutable; 
my $docuroot = $DiveinParam::documentroot;

if ($bootstrap > 0) {
	$type = 'bootstrap';	# bootstrap only
}elsif ($bootstrap < 0) {
	$type = 'aLRT';			# compute aLRT only
}elsif ($divergences) {
	$type = 'diver';		# need to calculate divergence and diversity
}else {
	$type = 'diversity';	# calculate diversity only
}

my $logFile = $uploadDir.'/'.$id.'.log';
my $errFile = $uploadDir.'/'.$id.'.err';
my $errLog;
open $errLog, ">", $errFile or die "couldn't open $errFile: $!\n";
open (LOG, ">", $logFile) or die Diver::DiverEmail::SendEmail ($email, $id, "Error", "Couldn't open $logFile: $!\n");
print LOG "Project: phyml\nid: $id\ntype: $type\nseqFileName: $seqFileName\ndatatype: $datatype\n";
print LOG "bootstrap: $bootstrap\nsubModel: $subModel\nfreqRadio: $freqRadio\nttRatio: $ttRatio\n";
print LOG "proportion: $proportion\nsubRateCat: $subRateCat\ngamma: $gamma\ntreeImprovType: $treeImprovType\n";
print LOG "optimize: $opt\nemail: $email\nIP: $ip\nuploadDir: $uploadDir\ndiverFormat: $diverFormat\n";
print LOG "divergences: $divergences\nProgram: $program\nJob seed: $r_seed\n";

my $equiFreq = ($freqRadio eq 'm' ? 'Optimized' : 'Empirical');
my $uploadFile = $uploadDir.'/'."$id.sequence.txt";	# uploaded sequence file name
my $uploadOutgrpFile = $uploadDir.'/'."$id.outgrp.txt";		# uploaded outgroup file name if any
my $uploadgrpFile = $uploadDir.'/'."$id.group.txt";	# uploaded ingroup file name if any

my $phylipFile = $uploadFile;
my $fastaFile = $phylipFile.'.fas';
my ($seqCount, $seqLen, $nameSeq) = Divein::ChangetoFasta($phylipFile, $fastaFile);

my $phymlOutFile = $phylipFile.'.phyml';					# phyml stdout with distance matrix
my $phymlOutTreeFile = $phylipFile.'_phyml_tree.txt';		# phyml output newick tree file

my $parameterFile = $uploadDir.'/'.$id.'.parameters.txt';
open PARA, ">", $parameterFile or die Diver::DiverEmail::SendEmail ($email, $id, "Error", "Couldn't open $parameterFile: $!\n");
printf PARA ("%-45s%s%s", 'Input alignment sequence file:', $seqFileName, "\n");
printf PARA ("%-45s%s%s", 'Sequence data type:', $seqType, "\n");
printf PARA ("%-45s%s%s", 'Substitution model:', $subModel, "\n");
if ($freqRadio) {
	printf PARA ("%-45s%s%s", 'Equilibrium frequencies:', $freqRadio eq 'm' ? 'Optimized' : 'Empirical', "\n");
}
unless ($ttRatio eq '') {
	printf PARA ("%-45s%s%s", 'Transition/transversion ratio:', $ttRatio eq 'e' ? 'Estimated' : $ttRatio, "\n");
}
unless ($proportion eq '') {
	printf PARA ("%-45s%s%s", 'Proportion of invariable sites:', $proportion eq 'e' ? 'Estimated' : $ttRatio, "\n");
}
printf PARA ("%-45s%s%s", 'Number of substitution rate categories:', $subRateCat, "\n");
unless ($gamma eq '') {
	printf PARA ("%-45s%s%s", 'Gamma distribution parameter:', $gamma eq 'e' ? 'Estimated' : $gamma, "\n");
}
unless ($treeImprovType eq '') {
	printf PARA ("%-45s%s%s", 'Type of tree improvement:', $treeImprovType eq 'BEST' ? 'Best of NNI & SPR' : $treeImprovType, "\n");
}
printf PARA ("%-45s%s%s", 'Optimise tree:', $opt eq 'tlr' ? 'Topology + branch lengths' : $opt eq 'lr' ? 'Branch lengths only' : 'None', "\n");
unless ($bootstrap == 0) {
	if ($bootstrap > 0) {
		printf PARA ("%-45s%s%s", 'Bootstrap replications:', $bootstrap, "\n");
	}else {
		printf PARA ("%-45s%s%s", 'Compute aLRT:', $bootstrap == -5 ? 'approximate Bayes' : $bootstrap == -4 ? 'SH-like' : $bootstrap == -2 ? 'Chi2-based' : 'aLRT statistics', "\n");
	}
}
if ($divergences) {
	printf PARA ("%-45s%s%s", 'Calculate divergence from:', $divergences, "\n");
}
unless ($diverFormat eq '') {
	printf PARA ("%-45s%s%s", 'Calculate divergence/diversity based on:', $diverFormat eq 'pairwise' ? 'Pairwise distance' : $diverFormat eq 'tree' ? 'Tree' : 'Both of pairwise distance and tree', "\n");
}
printf PARA ("%-45s%s%s", 'Job seed:', $r_seed, "\n");
close PARA;

my $command = "$phymlExecutable -i $phylipFile -d $datatype -q -b $bootstrap -m $subModel -v $proportion -c $subRateCat -o $opt --print_mat_and_exit --leave_duplicates --r_seed $r_seed";
$command .= " -a $gamma" if $gamma;
$command .= " -f $freqRadio" if $freqRadio;
$command .= " -t $ttRatio" if $ttRatio;
$command .= " -s $treeImprovType" if $treeImprovType;
$command .= " >$phymlOutFile";

my @cmd = ();
push @cmd, $phymlExecutable, '-i', $phylipFile, '-d', $datatype, '-q', '-b', $bootstrap, '-m', $subModel, '-v', $proportion, '-c', $subRateCat, '-o', $opt, '--print_mat_and_exit', '--leave_duplicates', '--r_seed', $r_seed;
push @cmd, '-a', $gamma if $gamma;
push @cmd, '-f', $freqRadio if $freqRadio;
push @cmd, '-t', $ttRatio if $ttRatio;
push @cmd, '-s', $treeImprovType if $treeImprovType;

# run first round phyml for original sequence alignment
print LOG "PhyML: ", join (' ', @cmd), "\n";
open STDOUT, ">", $phymlOutFile;
open STDERR, ">", $errFile;
system (@cmd);

if (-s $errFile) {
	open ERR, $errFile;
	my @lines = <ERR>;
	my $errMsg = "PhyML:\n".join('', @lines);
	close ERR;
	die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
}
die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'notree') if (-z $phymlOutTreeFile);

if ($type eq 'diver' || $type eq 'diversity') {	# calculate divergence and/or diversity
	my ($distMatrixFile, $treeFile);	# for calculating pairwise and tree based distances
	# get group sequence information including group sequence status, how many groups and what sequences in each group
	my ($grpStatus, $groups, $grpSeqs) = Diver::GetGrpSeqStatus($uploadgrpFile);	
	if ($divergences) {	# calculate MRCA, Consensus, COT if applicable
		if ($divergences !~ /MRCA/ && $divergences !~ /Consensus/ && $divergences !~ /COT/) {	# only calculate divergence from a specific sequence, will need the distance value from first round phyml 
			$distMatrixFile = $phymlOutFile;	
			$treeFile = $phymlOutTreeFile;
		}else {	# one or two or all of MRCA, Consensus and COT
			my ($outgroupList, $outgrpStatus);
			my $scdPhymlInputFile = $uploadDir.'/'.$id.'_diver_input.phy';
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
				my $phymlTree = Diver::GetPhymlTree ($phymlOutTreeFile);	# Bioperl tree object of phyml output newick tree
				my $monophyleticFlag = Diver::CheckMonophyletic ($phymlTree, $outgroupList, $id, $email);	# flag for monophyletic test, return tree if ingroup is monophyletic
				print LOG "Initial monophyleticFlag: $monophyleticFlag\n";
				
				if (!$monophyleticFlag) {
					# first re-root the tree based on outgroup, and replace original phyml tree with the re-rooted tree 
					my $rerootTree = Diver::RerootTree ($id, $phymlTree, $outgroupList, $phymlOutTreeFile, $email);
					# check monophyletic again for re-rooted tree
					$monophyleticFlag = Diver::CheckMonophyletic ($rerootTree, $outgroupList, $id, $email);
					print LOG "monophyleticFlag after re-root tree: $monophyleticFlag\n";
					if (!$monophyleticFlag) {
						$phymlOutTreeFile =~ /(.*)txt$/;
						my $newTreeFile = $1.'tre';
						rename $phymlOutTreeFile, $newTreeFile;
						die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'monophyletic', $type, $diverFormat, $uploadDir, $seqFileName, $divergences, $program);
					}
				}
				
				# insert internal node id to rerooted tree
				my $phymlOutTreeNodeFile 	= $phylipFile.'_phyml_tree_node.txt';	# tree file with inserted internal node id
				Diver::InsertNodeId ($phymlTree, $phymlOutTreeNodeFile); # now the $phymlTree is rerooted tree object with inNode ids
		
				# get MRCA node id
				my $mrcaNodeId = Diver::GetMRCANodeId ($phymlTree, $outgroupList);
				print LOG "MRCA node id: $mrcaNodeId\n";
				
				# append rerooted with internal node id newick tree to sequence fasta file for the input of hyphy program
				my $fastaFileWithTree = Diver::AppendTree2Fasta ($phymlOutTreeNodeFile, $fastaFile);
				my $hyphyOutFile = $fastaFile.'.hyphy';	# output file of running hyphy program
				my $modelIdx = Diver::GetModelIndex ($subModel);
				my $ancestors_nt_bf = $docuroot."/Ancestors_nt.bf";
				if ($datatype eq "nt") {	# DNA sequences
					system ("(echo $fastaFileWithTree; echo $modelIdx) | $hyphyExecutable $ancestors_nt_bf 1>$hyphyOutFile 2>$errFile");
					if (-s $errFile) {
						open ERR, $errFile;
						my @lines = <ERR>;
						my $errMsg = "MRCA Hyphy:\n".join('', @lines);
						close ERR;
						die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
					}
					print LOG "MRCA Hyphy: (echo $fastaFileWithTree; echo $modelIdx) | $hyphyExecutable $ancestors_nt_bf 1>$hyphyOutFile 2>$errFile\n";
				}else {	# amino-acid sequences
					my $templateBatchFile = $docuroot."/Ancestors_aa_template.bf";
					my $aaAncestorBatchFile = $uploadDir.'/'."$id.aaAncestor.bf";	# batch file for construct ancestors' sequences
					my $hyphyAAModel = $subModel;
					if ($subModel eq "Blosum62") {
						$hyphyAAModel = "BLOSUM62";
					}elsif ($subModel eq "CpREV") {
						$hyphyAAModel = "cpREV";
					}elsif ($subModel eq "HIVb") {
						$hyphyAAModel = "HIVBetween";
					}elsif ($subModel eq "HIVw") {
						$hyphyAAModel = "HIVWithin";
					}elsif ($subModel eq "MtREV") {
						$hyphyAAModel = "mtREV24";
					}elsif ($subModel eq "MtMam") {
						$hyphyAAModel = "mtMAM";
					}elsif ($subModel eq "RtREV") {
						$hyphyAAModel = "rtREV";
					}elsif ($subModel eq "DCMut") {
						$hyphyAAModel = "Dayhoff";
					}
					Diver::ComposeBatchFile ($aaAncestorBatchFile, $templateBatchFile, $hyphyAAModel, $hyphyDir);	# compose batch file on the fly
					system ("echo $fastaFileWithTree | $hyphyExecutable $aaAncestorBatchFile 1>$hyphyOutFile 2>$errFile");
					if (-s $errFile) {
						open ERR, $errFile;
						my @lines = <ERR>;
						my $errMsg = "MRCA Hyphy:\n".join('', @lines);
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
					my $cot_phymlOutFile = $uploadDir.'/'.$id.'_cot.phyml';
					my $cot_phymlOutTreeFile = $cot_phylip.'_phyml_tree.txt';		# phyml output newick tree file
					
					# run phyml for the alignment without outgroup
					my @cot_cmd = @cmd;
					for (my $i = 0; $i < @cot_cmd; $i++) {
						if ($cot_cmd[$i] eq $phylipFile) {
							$cot_cmd[$i] = $cot_phylip;
							last;
						}
					}
					print LOG "COT Phyml: ", join(' ', @cot_cmd), "\n";
					open STDOUT, ">", $cot_phymlOutFile;
					open STDERR, ">", $errFile;
					system(@cot_cmd);
					die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'notree') if (-z $cot_phymlOutTreeFile);
					if (-s $errFile) {
						open ERR, $errFile;
						my @lines = <ERR>;
						my $errMsg = "COT Phyml:\n".join('', @lines);
						close ERR;
						die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
					}
					@cot_cmd = ();
					# append phyml output tree to fasta file
					$fastaFileWithTree = Diver::AppendTree2Fasta ($cot_phymlOutTreeFile, $cot_fasta);
					# replace back with phylipFile and phymlOutFile in command for further replacement to get distance matrix via phyml
					#$command =~ s/$cot_phylip/$phylipFile/;
					#$command =~ s/>$cot_phymlOutFile/>$phymlOutFile/;
				}else {	# no outgroup file, so can use initial outputed phyml tree
					# append phyml output tree to fasta file
					$fastaFileWithTree = Diver::AppendTree2Fasta ($phymlOutTreeFile, $cot_fasta);
				}
				
				my $hyphyOutFile = $uploadDir.'/'.$id.'_cot.hyphy';
				my $cot_batch_file = $docuroot.'/COT_nt.bf';
				if ($datatype eq 'aa') {	# amino acid
					$cot_batch_file = $docuroot.'/COT_aa.bf';
				}
				system ("(echo $fastaFileWithTree; echo y) | $hyphyExecutable $cot_batch_file 1>$hyphyOutFile 2>$errFile");
				if (-s $errFile) {
					open ERR, $errFile;
					my @lines = <ERR>;
					my $errMsg = "COT hyphy:\n".join('', @lines);
					close ERR;
					die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
				}
				print LOG "COT hyphy: (echo $fastaFileWithTree; echo y) | $hyphyExecutable $cot_batch_file 1>$hyphyOutFile 2>$errFile\n";
				
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
			Divein::WriteFile ($scdPhymlInputFile, \@alignments);
			### run second round phyml to get distance matrix;
			my $diverPhymlOutFile = $uploadDir.'/'.$id.'_diver.phyml';
			my $outTreeFile = $scdPhymlInputFile.'_phyml_tree.txt';
			for (my $i = 0; $i < @cmd; $i++) {
				if ($cmd[$i] eq $phylipFile) {
					$cmd[$i] = $scdPhymlInputFile;
					last;
				}
			}
			print LOG "Divergence Phyml: ", join(' ', @cmd), "\n";
			open STDOUT, ">", $diverPhymlOutFile;
			open STDERR, ">", $errFile;			
			system(@cmd);
			close STDOUT;
			close STDERR;
			die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'notree') if (-z $outTreeFile);
			if (-s $errFile) {
				open ERR, $errFile;
				my @lines = <ERR>;
				my $errMsg = "Divergence Phyml:\n".join('', @lines);
				close ERR;
				die Diver::DiverEmail::SendEmail ($email, $id, 'Error', $errMsg);
			}
			$distMatrixFile = $diverPhymlOutFile;
			$treeFile = $outTreeFile;
		}
	}else {
		$distMatrixFile = $phymlOutFile;
		$treeFile = $phymlOutTreeFile;
	}
	if ($diverFormat eq 'pairwise' || $diverFormat eq 'both') {
		my $pwDistHashRef = Diver::GetPairwiseDists ($distMatrixFile);
		my $pwColDistFile = $uploadDir.'/'.$id.'_pwcoldist.txt';	# pairwise column distance file
		Diver::WriteColumnDistFile ($groups, $grpSeqs, $pwColDistFile, $pwDistHashRef, $divergences, $errLog, $grpStatus);
		if ($divergences) {	# calculate divergence and write to files
			my $pwDivergenceFilePrefix = $uploadDir.'/'.$id.'_pwdivergence';
			Diver::CalculateDivergence ($pwDivergenceFilePrefix, $groups, $grpSeqs, $divergences, $pwDistHashRef);
		}
		# calculate diversity and write to file
		my $pwDiversityFile = $uploadDir.'/'.$id.'_pwdiversity.txt';
		Diver::CalculateDiversity ($pwDiversityFile, $groups, $grpSeqs, $pwDistHashRef, $errLog);
		if (@$groups > 1) {	# more than one groups
			my $pwBtGrpDistFile = $uploadDir.'/'.$id.'_pwBtGrpDist.txt';
			Diver::CalculateBtwDist ($pwBtGrpDistFile, $groups, $grpSeqs, $pwDistHashRef, $errLog);
		}
	}
	if ($diverFormat eq 'tree' || $diverFormat eq 'both') {
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
$phymlOutTreeFile =~ /(.*)txt$/;
my $newTreeFile = $1.'tre';
rename $phymlOutTreeFile, $newTreeFile;

# run FigTree
my $treeimage = $newTreeFile;
$treeimage =~ s/\.tre$/.pdf/;
my @figtreecmd = ();
push @figtreecmd, 'java', '-jar', $figtree, '-graphic', 'PDF',  '-width', '800', '-height', '600', $newTreeFile;
print LOG "FigTree: ", join (' ', @figtreecmd), "\n";
open STDOUT, ">", $treeimage;
open STDERR, ">", $errFile;
system(@figtreecmd);
close STDOUT;
close STDERR;

# link tree image file
my $localImageDir = $docuroot."/treeImages";
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

my $finishTime = localtime();
chomp $finishTime;
my $statDir = $docuroot."/stats";
unless (-e $statDir) {
	mkdir $statDir;
	chmod 0775, $statDir;
}
print LOG "statsDir: $statDir\n";
close LOG;
close $errLog;
my $statFile = "$statDir/diver.stat";
open STAT, ">>", $statFile or die "couldn't open $statFile: $!\n";
print STAT "$finishTime\t$id\t$seqCount\t$seqLen\t$datatype\t$type\t$subModel\t$ip\t$email\t$duration\t$program\n";
close STAT;

Diver::DiverEmail::SendEmail ($email, $id, 'Success', 'Normal', $type, $diverFormat, $uploadDir, $seqFileName, $divergences, $program);

exit (0);
