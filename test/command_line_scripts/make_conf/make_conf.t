#!/usr/bin/env -S perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'make_conf';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/in.xyz -c 50 -s 18=Pr 22=MePh3',
    message => 'Simple',
    ref     => '01/ref.xyz',
    rmsd    => 10**(-5) };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
