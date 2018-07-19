#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use Test::More;
use lib "$ENV{QCHASM}/AaronTools/t/command_line_scripts";
require helper;

my $cmd = 'substitute';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '-a',
    message => 'Available flag' };
push @args,
  { args    => '01/methane.xyz -s 1=OH',
    message => 'Simple' };
push @args,
  { args    => '01/methane.xyz -s 1=OH -o 01/test.xyz -f',
    ref     => '01/ref.xyz',
    out     => '01/test.xyz',
    rmsd    => 0.2,
    message => 'with output file' };
push @args,
  { args    => '02/methanol.xyz -s 3,4,5=Me -o 02/test.xyz -f',
    ref     => '02/ref.xyz',
    out     => '02/test.xyz',
    rmsd    => 0.2,
    message => 'multiple targets' };
push @args,
  { args    => '03/tBuOH.xyz -s 4=Et 1,3=Cl -o 03/test.xyz -f',
    ref     => '03/ref.xyz',
    out     => '03/test.xyz',
    rmsd    => 0.2,
    message => 'multiple targets and substituents' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
	last;
}

done_testing();
