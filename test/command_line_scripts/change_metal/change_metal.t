#!/usr/bin/env perl

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'change_metal';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz -m Xy',
    message => 'Bad replacement metal',
    err     => 1,
    ref     => '01/bad_TM.ref' };
push @args,
  { args    => '02/test.xyz -m Pd',
    message => 'No TM in reference',
    err     => 1,
    ref     => '02/bad_geom.ref' };
push @args,
  { args    => '01/test.xyz -m Pd',
    message => 'Replace with same row TM',
    ref     => '01/same_row.xyz' };
push @args,
  { args    => '01/test.xyz -m Co',
    message => 'Replace with same group TM',
    ref     => '01/same_group.xyz' };
push @args,
  { args    => '01/test.xyz -m Cr',
    message => 'Replace with different row and different group TM',
    ref     => '01/different.xyz' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
