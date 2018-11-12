#!/usr/bin/env -S perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
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
  { args    => '03/tBuOH.xyz -s 1,3=Cl 4=Et',
    ref     => '03/ref.xyz',
    out     => '03/test.xyz',
    rmsd    => 0.5,
	reorder => 1,
    message => 'multiple targets and substituents' };
push @args,
  { args => '04/iPrPh-NC5C.xyz -s 49=Me 47=Me 21=Me 19=Me 67=Me 39=Me',
    ref => '04/ref.xyz',
	out => '03/test.xyz',
	rmsd => 0.5,
	reorder => 1,
	message => 'Oddly ordered substituents' };

push @args,
  { args => '05/methane.xyz -s 1=22-{3-5-CF3-Ph}Et',
    ref => '05/ref.xyz',
	out => '05/test.xyz',
	rmsd => 10E-5,
	reorder => 1,
	message => 'building substituents' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
