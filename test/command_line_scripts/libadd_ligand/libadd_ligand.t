#!/usr/bin/env -S perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'libadd_ligand';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz',
    message => 'TM centered',
    ref     => '01/ref.xyz',
    rmsd    => 0.0 };
push @args,
  { args    => '02/test.xyz',
    message => 'Pure organic',
    ref     => '02/ref.xyz',
    rmsd    => 0.0 };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
