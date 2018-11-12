#!/usr/bin/env perl

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'cat_screen';
my @args;
push @args, { args    => '-h',
              message => 'Help flag' };
push @args, { args    => '01/test.xyz -l 38=H,Cl,tBu -w 01/L-38',
              message => 'Sub on one ligand atom',
              ref     => '01/L-38',
              rmsd    => '0.2' };
push @args, { args    => '01/test.xyz -s 24=H,OH,OMe -w 01/s-24',
              message => 'Sub on one substrate atom',
              ref     => '01/s-24',
              rmsd    => '0.2' };
push @args, { args    => '01/test.xyz -l 38=Cl,OH 51=Me,tBu -w 01/L-38-51',
              message => 'Sub on two ligand atoms',
              ref     => '01/L-38-51',
              rmsd    => '0.2' };
push @args, { args    => '01/test.xyz -l 38,51=OH,Me -w 01/L-38.51',
              message => 'Sub symmetrically on two ligand atoms',
              ref     => '01/L-38.51',
              rmsd    => '0.2' };
push @args, { args    => '01/test.xyz -l 38=OH,Cl -s 24=OH,OMe -w 01/L-38_s-24',
              message => 'Sub on both ligand and substrate atoms',
              ref     => '01/L-38_s-24',
              rmsd    => '0.2' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
