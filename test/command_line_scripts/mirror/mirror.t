#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use Test::More;
use lib "$ENV{QCHASM}/AaronTools/t/command_line_scripts";
require helper;

my $cmd = 'mirror';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz',
    message => 'Default to mirror x',
    ref     => '01/ref_x.xyz',
    rmsd    => 0 };
push @args,
  { args    => '01/test.xyz -x x',
    message => 'Mirror x',
    ref     => '01/ref_x.xyz',
    rmsd    => 0 };
push @args,
  { args    => '01/test.xyz -x y',
    message => 'Mirror y',
    ref     => '01/ref_y.xyz',
    rmsd    => 0 };
push @args,
  { args    => '01/test.xyz -x z',
    message => 'Mirror z',
    ref     => '01/ref_z.xyz',
    rmsd    => 0 };
push @args,
  { args    => '02/test.xyz -x z',
    message => 'Larger example structure',
    ref     => '02/ref.xyz',
    rmsd    => 0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
