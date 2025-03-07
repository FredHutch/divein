#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp 'fatalsToBrowser';
use lib "$ENV{'DOCUMENT_ROOT'}/lib";
use DiveinParam;
use Divein;

my $q = new CGI;
my $id = $q->param('id');
my $type = $q->param('type');
my $format = $q->param('format');
my $diverseqNames = $q->param('diverseqNames');
my $program = $q->param('program');
my $uploadbase = $DiveinParam::uploadbase;
my $uploadDir = $uploadbase."/$id";

print $q->header;
if ($id !~ /^\d+$/ || ($type && $type !~ /^[A-Za-z]+$/) || ($format && $format !~ /^[A-Za-z]+$/) || ($diverseqNames && $diverseqNames !~ /^[\w,]+$/)) {
	print "Invalid input, process terminated.<br>";
	exit;
}
Divein::Print_header('diver', 'result');

print "<div id='indent'>";
if ($program eq "phyml") {
	print "<h2>Phylogeny/Divergence/Diversity results by PhyML 3.3.20220408</h2>";
}elsif ($program eq "fasttree") {
	print "<h2>Phylogeny/Divergence/Diversity results by FastTree 2.1.10</h2>";
}elsif ($program eq "raxml") {
	print "<h2>Phylogeny/Divergence/Diversity results by RAxML 8.2.12</h2>";
}elsif ($program eq "hd") {
	print "<h2>Hamming distance and diversity</h2>";
}
print "<p>Parameter settings for the job id of $id:</p>";
print "<table board=0>";
my $parameterFile = $uploadDir."/".$id.".parameters.txt";
open PARA, $parameterFile or die "couldn't open $parameterFile: $!\n";
while (my $line = <PARA>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	my ($first, $second) = split /:\s+/, $line;
	$first = $first.":";
	$second = $second;
	print "<tr><td align=left width=460>$first</td><td align=left>$second</td></tr>";
}
close PARA;
print "</table>";
print "<hr>";
print "<p>Please click following links to check the results:</p>";
print "<table board=0>";

if ($type) {
	if ($type eq 'aLRT') {
		print "<tr><td align=left width=460>MLE tree with aLRT:</td><td><a href=view.cgi?id=$id&file=.sequence.txt_".$program."_tree.pdf class='blue' target=_blank>view</a>";
	}else {
		print "<tr><td align=left width=460>MLE tree:</td><td><a href=view.cgi?id=$id&file=.sequence.txt_".$program."_tree.pdf class='blue' target=_blank>view</a>";
	}
}

if ($program eq "phyml") {
	print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt_phyml_tree.tre class='blue'>download</a></td></tr>";
	print "<tr><td align=left>MLE parameters:</td><td><a href=view.cgi?id=$id&file=.sequence.txt_phyml_stats.txt class='blue' target=_blank>view</a>";
	print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt_phyml_stats.txt class='blue'>download</a></td></tr>";
}elsif ($program eq "fasttree") {
	print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt_fasttree_tree.tre class='blue'>download</a></td></tr>";
	print "<tr><td align=left>MLE parameters:</td><td><a href=view.cgi?id=$id&file=.sequence.txt.fasttree.log class='blue' target=_blank>view</a>";
	print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt.fasttree.log class='blue'>download</a></td></tr>";
}elsif ($program eq "raxml") {
	print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt_raxml_tree.tre class='blue'>download</a></td></tr>";
	print "<tr><td align=left>MLE parameters:</td><td><a href=view.cgi?id=$id&file=.sequence.txt.raxml.log class='blue' target=_blank>view</a>";
	print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt.raxml.log class='blue'>download</a></td></tr>";
}

if ($program eq "hd") {
	if (-s $uploadDir.'/'.$id.'_pwcoldist.txt') {
		print "<tr><td align=left width=460>Pairwise distance column matrix:</td><td><a href=view.cgi?id=$id&file=_pwcoldist.txt&chart_type=histogram class='blue' target=_blank>view</a>";
		print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwcoldist.txt class='blue'>download</a></td></tr>";
	}
	if (-s $uploadDir.'/'.$id.'_pwdiversity.txt') {	
		print "<tr><td align=left>Pairwise based diversity within group:</td><td><a href=view.cgi?id=$id&file=_pwdiversity.txt&chart_type=Diversity class='blue' target=_blank>view</a>";
		print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwdiversity.txt class='blue'>download</a></td></tr>";
	}
	if (-s $uploadDir.'/'.$id.'_pwBtGrpDist.txt') {	
		print "<tr><td align=left>Pairwise distance between groups:</td><td><a href=view.cgi?id=$id&file=_pwBtGrpDist.txt class='blue' target=_blank>view</a>";
		print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwBtGrpDist.txt class='blue'>download</a></td></tr>";
	}
}else {
	unless ($type eq 'aLRT') {
		if ($type eq 'bootstrap') {
			if ($program eq "phyml") {
				print "<tr><td align=left>Bootstrap trees:</td><td><a href=view.cgi?id=$id&file=.sequence.txt_phyml_boot_trees.txt class='blue' target=_blank>view</a>";
				print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt_phyml_boot_trees.txt class='blue'>download</a></td></tr>";
				print "<tr><td align=left>Bootstrap parameters:</td><td><a href=view.cgi?id=$id&file=.sequence.txt_phyml_boot_stats.txt class='blue' target=_blank>view</a>";
				print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt_phyml_boot_stats.txt class='blue'>download</a></td></tr>";
			}elsif ($program eq "raxml") {
				print "<tr><td align=left>Bootstrap trees:</td><td><a href=view.cgi?id=$id&file=.sequence.txt_raxml_boot_trees.txt class='blue' target=_blank>view</a>";
				print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=.sequence.txt_raxml_boot_trees.txt class='blue'>download</a></td></tr>";
			}		
		}else {
			if ($type eq 'diver') {	
				if (-s $uploadDir.'/'.$id.'_MRCA.fas') {
					print "<tr><td align=left>MRCA sequence:</td><td><a href=view.cgi?id=$id&file=_MRCA.fas class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_MRCA.fas class='blue'>download</a></td></tr>";
				
				}
				if (-s $uploadDir.'/'.$id.'_cons.fas') {
					print "<tr><td align=left>Concensus sequence:</td><td><a href=view.cgi?id=$id&file=_cons.fas class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_cons.fas class='blue'>download</a></td></tr>";
				
				}
				if (-s $uploadDir.'/'.$id.'_cot_out.fas') {
					print "<tr><td align=left>COT sequence:</td><td><a href=view.cgi?id=$id&file=_cot_out.fas class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_cot_out.fas class='blue'>download</a></td></tr>";
				
				}
			}
		
			if ($format eq 'pairwise' || $format eq 'both') {
				if (-s $uploadDir.'/'.$id.'_pwcoldist.txt') {
					print "<tr><td align=left>Pairwise distance column matrix:</td><td><a href=view.cgi?id=$id&file=_pwcoldist.txt&chart_type=histogram class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwcoldist.txt class='blue'>download</a></td></tr>";
				}			
				if (-s $uploadDir.'/'.$id.'_pwdivergence_MRCA.txt') {
					print "<tr><td align=left>Pairwise based divergence from MRCA:</td><td><a href=view.cgi?id=$id&file=_pwdivergence_MRCA.txt&chart_type=Divergence class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwdivergence_MRCA.txt class='blue'>download</a></td></tr>";
				}
				if (-s $uploadDir.'/'.$id.'_pwdivergence_Cons.txt') {
					print "<tr><td align=left>Pairwise based divergence from Consensus:</td><td><a href=view.cgi?id=$id&file=_pwdivergence_Cons.txt&chart_type=Divergence class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwdivergence_Cons.txt class='blue'>download</a></td></tr>";
				}
				if (-s $uploadDir.'/'.$id.'_pwdivergence_COT.txt') {
					print "<tr><td align=left>Pairwise based divergence from COT:</td><td><a href=view.cgi?id=$id&file=_pwdivergence_COT.txt&chart_type=Divergence class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwdivergence_COT.txt class='blue'>download</a></td></tr>";
				}
				if ($diverseqNames) {
					my @seqNames = split /,/, $diverseqNames;
					foreach my $seqName (@seqNames) {
						if (-s $uploadDir.'/'.$id.'_pwdivergence_'.$seqName.'_Seq.txt') {
							print "<tr><td align=left>Pairwise based divergence from sequence $seqName:</td><td><a href=view.cgi?id=$id&file=_pwdivergence_".$seqName."_Seq.txt&chart_type=Divergence class='blue' target=_blank>view</a>";
							print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwdivergence_$seqName"."_Seq.txt class='blue'>download</a></td></tr>";
						}
					}
				}
			
				if (-s $uploadDir.'/'.$id.'_pwdiversity.txt') {	
					print "<tr><td align=left>Pairwise based diversity:</td><td><a href=view.cgi?id=$id&file=_pwdiversity.txt&chart_type=Diversity class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwdiversity.txt class='blue'>download</a></td></tr>";
				}
				if (-s $uploadDir.'/'.$id.'_pwBtGrpDist.txt') {	
					print "<tr><td align=left>Pairwise distance between groups:</td><td><a href=view.cgi?id=$id&file=_pwBtGrpDist.txt class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_pwBtGrpDist.txt class='blue'>download</a></td></tr>";
				}
			}
		
			if ($format eq 'tree' || $format eq 'both') {
				if (-s $uploadDir.'/'.$id.'_tbcoldist.txt') {
					print "<tr><td align=left>Tree based distance column matrix:</td><td><a href=view.cgi?id=$id&file=_tbcoldist.txt&chart_type=histogram class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_tbcoldist.txt class='blue'>download</a></td></tr>";
				}			
				if (-s $uploadDir.'/'.$id.'_tbdivergence_MRCA.txt') {
					print "<tr><td align=left>Tree based divergence from MRCA:</td><td><a href=view.cgi?id=$id&file=_tbdivergence_MRCA.txt&chart_type=Divergence class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_tbdivergence_MRCA.txt class='blue'>download</a></td></tr>";
				}
				if (-s $uploadDir.'/'.$id.'_tbdivergence_Cons.txt') {
					print "<tr><td align=left>Tree based divergence from Consensus:</td><td><a href=view.cgi?id=$id&file=_tbdivergence_Cons.txt&chart_type=Divergence class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_tbdivergence_Cons.txt&files_location=$uploadDir class='blue'>download</a></td></tr>";
				}
				if (-s $uploadDir.'/'.$id.'_tbdivergence_COT.txt') {
					print "<tr><td align=left>Tree based divergence from COT:</td><td><a href=view.cgi?id=$id&file=_tbdivergence_COT.txt&chart_type=Divergence class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?ID=$id"."_tbdivergence_COT.txt class='blue'>download</a></td></tr>";
				}
				if ($diverseqNames) {
					my @seqNames = split /,/, $diverseqNames;
					foreach my $seqName (@seqNames) {
						if (-s $uploadDir.'/'.$id.'_tbdivergence_'.$seqName.'_Seq.txt') {
							print "<tr><td align=left>Tree based divergence from sequence $seqName:</td><td><a href=view.cgi?id=$id&file=_tbdivergence_".$seqName."_Seq.txt&chart_type=Divergence class='blue' target=_blank>view</a>";
							print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_tbdivergence_$seqName"."_Seq.txt class='blue'>download</a></td></tr>";
						}
					}
				}
			
				if (-s $uploadDir.'/'.$id.'_tbdiversity.txt') {	
					print "<tr><td align=left>Tree based diversity:</td><td><a href=view.cgi?id=$id&file=_tbdiversity.txt&chart_type=Diversity class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_tbdiversity.txt class='blue'>download</a></td></tr>";
				}
				if (-s $uploadDir.'/'.$id.'_tbBtGrpDist.txt') {	
					print "<tr><td align=left>Tree distance between groups:</td><td><a href=view.cgi?id=$id&file=_tbBtGrpDist.txt class='blue' target=_blank>view</a>";
					print "&nbsp;&nbsp;<a href=download.cgi?id=$id&file=_tbBtGrpDist.txt class='blue'>download</a></td></tr>";
				}
			}
		
			print "</table>";
		
			if (-s $uploadDir.'/'.$id.'_pwcoldist.txt' || -s $uploadDir.'/'.$id.'_tbcoldist.txt') {
				my $logfile = $uploadDir."/".$id.".log";
				my $email = '';
				open LOG, "<", $logfile or die "couldn't open $logfile: $!\n";
				while (my $line = <LOG>) {
					chomp $line;
					if ($line =~ /email: (\S+)/) {
						$email = $1;
					}
				}
				print "<hr>";
				print "<form enctype='multipart/form-data' action=\"/cgi-bin/tst/grp.cgi\" name='tstForm' method='post'>";
				print "<input type=hidden name='projectId' value=$id>";
				print "<input type=hidden name='uploadDir' value=$uploadDir>";
				print "<input type=hidden name='email' value=$email>";
				print "<table board=0>";
				print "<tr><td align=left width=460>Perform Two-Sample Tests via outputted pairwise distances:</td>";
				print "<td align=left><input type='submit' value='   Go    '></td></tr>";
				print "</table>";
			}
			
			my $uploadTstLogFile = $uploadDir."/".$id."_tst.log";
			if (-s $uploadTstLogFile) {
				my $t = my $df = my $Pt = my $Pz = 0;
				open TST, $uploadTstLogFile or die "couldn't open $uploadTstLogFile: $!\n";
				while (my $line = <TST>) {
					chomp $line;
					if ($line =~ /T=(\S+)/) {
						$t = $1;
					}elsif ($line =~ /df=(\S+)/) {
						$df = $1;
					}elsif ($line =~ /Z-test P=(\S+)/) {
						$Pz = $1;
					}elsif ($line =~ /T-test P=(\S+)/) {
						$Pt = $1;
					}
				}
				print "<hr>";
				print "<p>Two-Sample Test result:</p>";
				print "<table board=0>";
				print "<tr><td align=left width=460>T Score:</td><td align=left>$t</td></tr>";
				print "<tr><td>Degrees of freedom:</td><td>$df</td></tr>";
				print "<tr><td>Z-test P value:</td><td>$Pz</td></tr>";
				print "<tr><td>T-test P value:</td><td>$Pt</td></tr>";
			}
		}
	}
}

print "</table>";
Divein::PrintFooter();
