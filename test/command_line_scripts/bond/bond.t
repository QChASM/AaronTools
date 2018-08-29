#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'bond';
my @args;
push @args,
  { args => '-h', message => 'Help flag' };
push @args,
  { args    => '-p 6 10 01/ref.xyz',
    message => 'Print bond length',
    ref     => '01/print.ref' };
push @args,
  { args    => '-s 6 10 1 01/ref.xyz',
    message => 'Set bond length',
    ref     => '01/set.xyz' };
push @args,
  { args    => '-c 6 10 -0.5 01/ref.xyz',
    message => 'Change bond length',
    ref     => '01/change.xyz' };
push @args,
  { args => '-s 1 11 1.3 -x 1 01/ref.xyz',
    message => 'Set and fix atom 1',
	ref => '01/set_fix.xyz' };
push @args,
  { args => '-c 1 11 0.2 -x 2 01/ref.xyz',
    message => 'Change and fix atom 2',
	ref => '01/change_fix.xyz' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
