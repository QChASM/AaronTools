#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'rmsd_align';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/reference.xyz 01/target.xyz',
    message => 'Same system, just shifted',
    ref     => '01/reference.xyz',
    rmsd    => 10**(-8) };
push @args,
  { args    => '01/reference.xyz 01/target_tBu.xyz',
    message => 'Substituted and shifted',
    ref     => '01/result_tBu.xyz',
    rmsd    => 10**(-8) };
push @args,
  { args    => '02/reference.xyz 02/target.xyz -t 18-31',
    message => 'Using target atoms',
    ref     => '02/ref_targetatoms.xyz',
    rmsd    => 10**(-8) };
push @args,
  { args    => '02/reference.xyz 02/target.xyz -c',
    message => 'Using change order',
    ref     => '02/ref_targetatoms.xyz',
    rmsd    => 10**(-8) };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
