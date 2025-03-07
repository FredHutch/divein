package DiveinParam;

use strict;
use warnings;
use Carp qw[croak carp];
use Data::Dumper;


=head1 NAME

Common -- package for common parameters used in DIVEIN

=head1 SYNOPSIS


=head1 METHODS


=cut

our $documentroot = $ENV{'DOCUMENT_ROOT'};
our $uploadbase = "$documentroot/outputs";
our $statsbase = "$documentroot/stats";
our $logbase = "$documentroot/log";
our $bs_jobTable = 'bs_jobqueue';
our $jobTable = 'jobqueue';



1; #TRUE!!
 
