#!/usr/bin/env -S perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'genshift';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz -v 2.59311 -0.03600 0.00004',
    message => 'Shift by vector',
    ref     => '01/ref_vector.xyz',
    rmsd    => 0.0 };
push @args,
  { args    => '01/test.xyz -v 1',
    message => 'Center atom',
    ref     => '01/ref_center.xyz',
    rmsd    => 0.0 };
push @args,
  { args    => '01/test.xyz -v 1 2',
    message => 'Center bond',
    ref     => '01/ref_bond.xyz',
    rmsd    => 0.0 };
push @args,
  { args    => '02/test.xyz -v -2.431440 -0.060891 0 -t 1-7,8-17',
    message => 'Shifting target atoms',
    ref     => '02/ref_target.xyz',
    rmsd    => 0.0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
