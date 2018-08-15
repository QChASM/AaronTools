#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'rotate';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz -x x -a 90',
    message => 'Single rotation',
    ref     => '01/ref_rot-90.xyz',
    rmsd    => 0 };
push @args,
  { args    => '01/test.xyz -x y -n 6 -w 01/n6',
    message => 'Multiple equal rotations',
    ref     => '01/n6',
    rmsd    => 0 };
push @args,
  { args    => '01/test.xyz -x z -a 90 -n 2 -w 01/a90n2',
    message => 'Multiple specific rotations',
    ref     => '01/a90n2',
    rmsd    => 0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
