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
    message => 'Simple',
    ref     => '01/ref.xyz',
    reorder => 1,
    rmsd    => 10**(-5) };
push @args,
  { args    => '01/methane.xyz -s 1=OH',
    ref     => '01/ref.xyz',
    out     => '01/test.xyz',
    rmsd    => 10**(-5),
    reorder => 1,
    message => 'with output file' };
push @args,
  { args    => '02/methanol.xyz -s 3,4,5=Me',
    ref     => '02/ref.xyz',
    out     => '02/test.xyz',
    rmsd    => 10**(-5),
    reorder => 1,
    message => 'multiple targets' };
push @args,
  { args    => '03/tBuOH.xyz -s 1,3=Cl 4=Et -m',
    ref     => '03/ref.xyz',
    out     => '03/test.xyz',
    rmsd    => 0.2,
    reorder => 1,
    message => 'multiple targets and substituents, with minimize' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
