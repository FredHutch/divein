package Cot;

use strict;
use warnings;
use Bio::TreeIO;
use Bio::Tree::TreeFunctionsI;


=head1 NAME

Common -- package for  routines used in cot

=head1 SYNOPSIS


=head1 METHODS


=cut


our $hyphyDir 			= '/var/www/html/HYPHY';	# hyphy-r592
our $phymlExecutable	= '/usr/local/bin/phyml';

sub StandardizeTreeNodeId {
	my ($tree, $uploadTreeFile) = @_;
	my $isInnodes = 0;
	my @nodes = $tree->get_nodes();
	foreach my $node (@nodes) {
		if ($node->is_Leaf) {
			my $nodeId = $node->id();
			if ($nodeId =~ /\W/) {
				$nodeId =~ s/\W/_/g;
				$node->id($nodeId);
			}
		}else {
			$isInnodes = 1;
			$node->id('');
		}
	}
	my $out = new Bio::TreeIO(-file => ">$uploadTreeFile", -format => 'newick');
	$out->write_tree($tree);
	return $isInnodes;
}

sub GetNewickTree {
	my $newickTreeFile = shift;
	
	my $input = new Bio::TreeIO(-file   => $newickTreeFile,
                                -format => "newick");
	
	my $tree = $input->next_tree;
	
	return $tree;
}

sub AppendTree2Fasta {
	my ($phymlTreeFile, $fastaFile) = @_;
	my $phymlTree = '';
	open TREE, $phymlTreeFile or die "Couldn't open phyml output tree file: $!\n";
	while (my $line = <TREE>) {
		chomp $line;
		next if $line =~ /^\s*$/;
		$phymlTree .= $line;
	}
	close TREE;
	my $fastaFileWithTree = $fastaFile.'_tre';
	open FASTA, $fastaFile or die "Couldn't open $fastaFile: $!\n";
	open FASTATREE, ">$fastaFileWithTree" or die "Couldn't open $fastaFileWithTree: $!\n";
	while (<FASTA>) {
		print FASTATREE $_;
	}
	print FASTATREE "\n",$phymlTree,"\n";
	close FASTATREE;
	close FASTA;

	return $fastaFileWithTree;
}


1; #TRUE!!
 
