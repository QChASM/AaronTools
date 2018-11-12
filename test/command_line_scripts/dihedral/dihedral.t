#!/usr/bin/env -S perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'dihedral';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz -p 26 25 31 32',
    message => 'Print dihedral',
    ref     => '01/print.ref' };
push @args,
  { args    => '01/test.xyz -p 26 25 31 32 -r',
    message => 'Print dihedral in radians',
    ref     => '01/print_radian.ref' };
push @args,
  { args    => '01/test.xyz -c 58 43 15',
    message => 'Change dihedral',
    out     => '01/test_change.xyz',
    ref     => '01/ref_change.xyz',
    rmsd    => 0 };
push @args,
  { args    => '01/test.xyz -s 8 1 23 19 -60',
    message => 'Set dihedral',
    out     => '01/test_set.xyz',
    ref     => '01/ref_set.xyz',
    rmsd    => 0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
