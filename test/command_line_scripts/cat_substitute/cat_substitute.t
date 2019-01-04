#!/usr/bin/env perl

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'cat_substitute';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.xyz -l 45=H',
    message => 'One ligand sub',
    out     => '01/test_45-H.xyz',
    ref     => '01/ref_45-H.xyz',
    rmsd    => 0.2 };
push @args,
  { args    => '01/test.xyz -s 22=OH',
    message => 'One substrate sub',
    out     => '01/test_22-OH.xyz',
    ref     => '01/ref_22-OH.xyz',
    rmsd    => 0.2 };
push @args,
  { args    => '01/test.xyz -l 45=H 43=CF3',
    message => 'Multiple ligand subs',
    out     => '01/test_45-H_43-CF3.xyz',
    ref     => '01/ref_45-H_43-CF3.xyz',
    rmsd    => 0.2 };
push @args,
  { args    => '01/test.xyz -l 43,45=CF3 -s 22=OH',
    message => 'Multiple ligand and substrate subs',
    out     => '01/test_43-CF3_45-CF3_22-OH.xyz',
    ref     => '01/ref_43-CF3_45-CF3_22-OH.xyz',
    rmsd    => 0.2 };
push @args,
  { args    => '02/test.xyz -l 52=Me -s 20=OH',
    message => 'Minimze new sub',
    out     => '02/test_min.xyz',
    ref     => '02/ref_min.xyz',
    rmsd    => 0.3 };
push @args,
  { args    => '04/test.xyz -l 76=Ph',
	message => 'Ringed backbone',
	out		=> '04/test_76-Ph.xyz',
	ref		=> '04/ref_76-Ph.xyz',
	rmsd	=> '0.2' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
