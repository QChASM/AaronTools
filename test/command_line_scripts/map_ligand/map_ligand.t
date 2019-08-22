#!/usr/bin/env perl

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'map_ligand';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args     => '01/test.xyz -l bi-isoquinoline-NN-dioxide',
    message  => 'TM centered',
    ref      => '01/ref.xyz',
    backbone => 10**-6,
    reorder  => 0 };
push @args,
  { args     => '02/test.xyz -l squaramide',
    message  => 'Organic',
    ref      => '02/ref.xyz',
    backbone => 0.25,
    reorder  => 0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
