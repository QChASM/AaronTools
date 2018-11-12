#!/usr/bin/env perl

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
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
    rmsd    => 10**(-6) };
push @args,
  { args    => '01/test.xyz -v 1 2 -a 3.1415926535 -r',
    message => 'Single rotation (bond)',
    ref     => '01/ref_bond-rot-180.xyz',
    rmsd    => 10**(-5) }; # rmsd allowance higher due to radain conversion
push @args,
  { args    => '01/test.xyz -v 1 2 -n 6 -w 01/n6',
    message => 'Multiple equal rotations',
    ref     => '01/n6',
    rmsd    => 10**(-6) };
push @args,
  { args    => '02/test.xyz -t 31-41 -v 27 31 -a 90 -n 2 -w 02/a90n2',
    message => 'Multiple rotations on target atoms',
    ref     => '02/a90n2',
    rmsd    => 10**(-6) };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
