#!/usr/bin/perl -w

######################################################################################################
# This script can take both DNA and amino acid sequence alingment phylip file as input, runs phyml 
# program v3.0.1 using GTR model (DNA) or LG (amino acid), re-root phyml output tree at COT and calculate 
# COT sequence under GTR (DNA) or LG (Amino acid) using HYPHY v2.0
# Author: Wenjie Deng
# Date: 2009-01-14
# Modify date: 2009-03-26
# version: 1.0.1
# Modified for docker container: 2025-3
######################################################################################################

use strict;
use Bio::TreeIO;
use Bio::Tree::TreeFunctionsI;
use File::Basename;
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use Diver;
use Divein;
use DiveinParam;
use Cot;
use Cot::CotEmail;
use Diver::DiverEmail;

my ($seqFile, $seqFormat, $datatype, $treeRadio, $email, $id, $uploadDir, $docuroot, $remote_ip, $isInnodes);
BEGIN {
	$seqFile 		= shift;
	$seqFormat		= shift;
	$datatype		= shift;
	$treeRadio		= shift;
	$email 			= shift;
	$id 			= shift;	# job id
	$uploadDir 		= shift;	# directory for uploading files
	$docuroot		= shift;
	$remote_ip		= shift;
	$isInnodes		= shift;
}

my $startTime = time();	
my $hyphyExecutable = $Diver::hyphyExecutable;
my $fasttreeExecutable = $Diver::fasttreeExecutable;
my $figtree = $Diver::figtreeExecutable; 

my $logFile = $uploadDir.'/'.$id.'.log';
open (LOG, ">", $logFile) or die Cot::CotEmail::SendEmail ($id, $email, "Error", "Couldn't open $logFile: $!\n");
print LOG "Project: cot\nid: $id\nuploadDir: $uploadDir\nseqFile: $seqFile\nformat: $seqFormat\ndata type: $datatype\ntreeRadio: $treeRadio\nemail: $email\n";
print LOG "document root: $docuroot\nremote ip: $remote_ip\nisInnodes: $isInnodes\n";
my $errFile = $uploadDir.'/'.$id.'.err';

my $gapStripSeqFile = $uploadDir.'/'.$id.'.sequence_stripgap.txt';
Divein::StripGaps ($seqFile, $gapStripSeqFile);

my $fastaFile = $gapStripSeqFile.'.fas';
my ($seqCount, $seqLen) = Divein::ChangetoFasta($gapStripSeqFile, $fastaFile);

my $fasttreeOutFile	= $gapStripSeqFile.'.fasttree';					# fasttree stdout with distance matrix
my $fasttreeOutTreeFile = $gapStripSeqFile.'_fasttree_tree.tre';		# fasttree output newick tree file
my $fasttreeLogFile = $gapStripSeqFile.'.fasttree.log';	# fasttree output log file

if ($treeRadio eq 'no') {
	my @cmd = ();
	push @cmd, $fasttreeExecutable, "-quiet";
	if ($datatype eq "nt") {
	push @cmd, "-nt", "-gtr";
	}elsif ($datatype eq "aa") {
		push @cmd, "-lg";
	}
	push @cmd, "-cat", 20, "-gamma", "-nosupport";
	push @cmd, "-log", $fasttreeLogFile, "-out", $fasttreeOutTreeFile, $fastaFile;

	print LOG "Fasttree: ", join (' ', @cmd), "\n";
	
	# run fasttree for original sequence alignment
	open STDOUT, ">", $fasttreeOutFile;
	open STDERR, ">", $errFile;
	my $val = system (@cmd);
	if ($val == 0) {
		print LOG "success\n";
	}else {
		print LOG "failed: $val\n";
	}
	close STDOUT;
	close STDERR;
	die Diver::DiverEmail::SendEmail ($email, $id, 'Error', 'notree') if (-z $fasttreeOutTreeFile);
	if (-s $errFile) {
		open ERR, $errFile;
		my @lines = <ERR>;
		my $errMsg = join('', @lines);
		close ERR;
		die Cot::CotEmail::SendEmail ($id, $email, 'Error', $errMsg);
	}	
}

# append fasttree output tree to fasta file
my $fastaFileWithTree = Cot::AppendTree2Fasta ($fasttreeOutTreeFile, $fastaFile);

my $hyphyOutFile = $uploadDir.'/'.$id.'.hyphy';
my $cot_batch_file = $docuroot.'/COT_nt.bf';
if ($datatype eq 'aa') {	# amino acid
	$cot_batch_file = $docuroot.'/COT_aa.bf';
}
system ("(echo $fastaFileWithTree; echo y) | $hyphyExecutable $cot_batch_file 1>$hyphyOutFile 2>$errFile");
if (-s $errFile) {
	open ERR, $errFile;
	my @lines = <ERR>;
	my $errMsg = join('', @lines);
	close ERR;
	die Cot::CotEmail::SendEmail ($id, $email, 'Error', $errMsg);
}	
print LOG "(echo $fastaFileWithTree; echo y) | $hyphyExecutable $cot_batch_file 1>$hyphyOutFile 2>$errFile\n";

# write COT tree and sequence
my $cottreeFile = $uploadDir.'/'.$id.'.cot.tre';
my $cottreeSeq = $uploadDir.'/'.$id.'.cot.fas';
my ($cottree, $cotseq) = Divein::GetCOT ($hyphyOutFile, $cottreeFile, $datatype);
$cotseq = Divein::CleanString ($cotseq);
$cotseq =~ s/;$//;
Divein::WriteSeq ($cottreeSeq, $cotseq, 'COT', 80); 

if ($isInnodes) {	# there are internal node id in inputted newick tree, need to put them back in COT re-rooted tree
	my $originalTreeFile = $uploadDir.'/'.$id.'.sequence.txt_phyml_tree.txt';
	my $originalStdIdTreeFile = $uploadDir.'/'.$id.'.sequence_stdid.txt_phyml_tree.txt';
	my $originalTreeObj = Cot::GetNewickTree ($originalTreeFile);
	my $cotTreeObj = Cot::GetNewickTree ($cottreeFile);
	my @originalNodes = $originalTreeObj->get_nodes();
	my $internalNodeCount = 0;
	my (%nodeIdHash, %ancensterHash);
	foreach my $node (@originalNodes) {	# standardize leaf node ids in original inputted newick tree
		if ($node->is_Leaf) {
			my $nodeId = $node->id();
			if ($nodeId =~ /\W/) {
				$nodeId =~ s/\W/_/g;
				$node->id($nodeId);
			}
		}else {	# internal node, reassign id with sequencial unique id and record the relationship between the original and new ids
			$internalNodeCount++;
			my $nodeId = $node->id;	# get internal node id
			$node->id($internalNodeCount);	# assign internal node with a sequencial unique id
			$nodeIdHash{$internalNodeCount} = $nodeId;	# establish the link between new id and origianl id
		}
	}
	
	foreach my $node (@originalNodes) {
		unless ($node->is_Leaf) {	# internal node, find desendents
			my $nodeId = $node->id;	# get internal node id
			for my $child ( $node->each_Descendent ) {
				$ancensterHash{$child->id} = $nodeId;
			}			
		}
	}
	
	my @fields;
	open IN, $cottreeFile or die "couldn't open $cottreeFile: $!\n";
	while (my $line = <IN>) {
		chomp $line;
		next if $line =~ /^\s*$/;
		@fields = split /\)/, $line;
		for (my $i = 0; $i < @fields-1; $i++) {
			my $value = $fields[$i];
			my @elements = split /[\,\:]/, $value;
			my $childId = $elements[$#elements-1];
			unless ($fields[$i+1] eq ';') {
				$fields[$i+1] = $ancensterHash{$childId}.$fields[$i+1];
			}			
		}
	}
	close IN;
	
	my $cottree_w_internalnodes = $uploadDir.'/'.$id.'.cot_internal.tre';
	open OUT, ">", $cottree_w_internalnodes or die "couldn't open $cottree_w_internalnodes: $!\n";
	print OUT join (')', @fields), "\n";
	close OUT;
	my $cotObj = Cot::GetNewickTree ($cottree_w_internalnodes);
	my @cotNodes = $cotObj->get_nodes();
	foreach my $node (@cotNodes) {
		unless ($node->is_Leaf) {	# find internal nodes
			my $nodeId = $node->id;
			my $originalId = $nodeIdHash{$nodeId};
			$node->id($originalId);
		}
	}

	my $out = new Bio::TreeIO(-file => ">$cottreeFile", -format => 'newick');
	$out->write_tree($cotObj);
}

my @treefiles;
push @treefiles, $fasttreeOutTreeFile, $cottreeFile;
print LOG "treefiles: ", join(',', @treefiles), "\n";

# run FigTree
foreach my $treefile (@treefiles) {
	print LOG "$treefile\n";
	my $treeimage = $treefile;
	$treeimage =~ s/\.tre$/.pdf/;
	my @figtreecmd = ();
	push @figtreecmd, 'java', '-jar', $figtree, '-graphic', 'PDF',  '-width', '800', '-height', '600', $treefile;
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
my $statDir = $DiveinParam::statsbase;
unless (-e $statDir) {
	mkdir $statDir;
	chmod 0775, $statDir;
}
my $statFile = "$statDir/cot.stat";
open STAT, ">>", $statFile or die "couldn't open $statFile: $!\n";
print STAT "$finishTime\t$id\t$seqCount\t$seqLen\t$datatype\t$treeRadio\t$remote_ip\t$email\t$duration\n";
close STAT;

Cot::CotEmail::SendEmail ($id, $email, 'Success', 'Normal', $treeRadio, $uploadDir);

exit (0);
