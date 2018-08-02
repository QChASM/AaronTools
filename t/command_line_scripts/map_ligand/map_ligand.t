#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use Test::More;
use lib "$ENV{QCHASM}/AaronTools/t/command_line_scripts";
require helper;

my $cmd = 'map_ligand';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz -l bi-isoquinoline-NN-dioxide',
    message => 'TM centered',
    ref     => '01/ref.xyz',
    rmsd    => 10**(-8),
    reorder => 0 };
push @args,
  { args    => '02/test.xyz -l squaramide',
    message => 'Organic',
    ref     => '02/ref.xyz',
    rmsd    => 10**(-8),
    reorder => 0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
