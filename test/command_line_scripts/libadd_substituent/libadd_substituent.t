#!/usr/bin/env -S perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'libadd_substituent';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz -t 38 -a 37 -c 2 60',
    message => 'TM center, sub on ligand',
    ref     => '01/ref_CH3.xyz',
    rmsd    => 0.0 };
push @args,
  { args    => '01/test.xyz -t 22 -a 33',
    message => 'TM center, sub is part of substrate',
    ref     => '01/ref_substrate.xyz',
    rmsd    => 0.0 };
push @args,
  { args    => '02/test.xyz -t 58 -a 43',
    message => 'Organic catalyst',
    ref     => '02/ref.xyz',
    rmsd    => 0.0 };
push @args,
  { args    => '03/test.xyz -t 1 -a 26',
    message => 'Single atom sub',
    ref     => '03/ref.xyz',
    rmsd    => 0.0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
