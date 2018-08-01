#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use Test::More;
use lib "$ENV{QCHASM}/AaronTools/t/command_line_scripts";
require helper;

my $cmd = 'genrotate';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz -v -1.38208 0.01104 -0.00003 -a 90',
    message => 'Single rotation (vector)',
    ref     => '01/ref_vect-rot-90.xyz',
    rmsd    => '0.0' };
push @args,
  { args    => '01/test.xyz -v 1 2 -a 3.1415926535 -r',
    message => 'Single rotation (bond)',
    ref     => '01/ref_bond-rot-180.xyz',
    rmsd    => 1 * 10**(-5) };
push @args,
  { args    => '01/test.xyz -v 1 2 -n 6 -w 01/n6',
    message => 'Multiple equal rotations',
    ref     => '01/n6',
    rmsd    => 0.0 };
push @args,
  { args    => '02/test.xyz -t 31-41 -v 27 31 -a 90 -n 2 -w 02/a90n2',
    message => 'Multiple rotations on target atoms',
    ref     => '02/a90n2',
    rmsd    => 0.0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
