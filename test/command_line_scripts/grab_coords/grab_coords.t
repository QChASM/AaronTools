#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'grab_coords';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/test.com',
    ref     => '01/ref.xyz',
    message => 'com file read' };
push @args,
  { args    => '01/test.log',
    ref     => '01/ref.xyz',
    message => 'log file read' };
push @args,
  { args    => '01/test.xyz',
    ref     => '01/ref.xyz',
    message => 'xyz file read' };
push @args,
  { args    => '01/test.xyz',
    ref     => '01/ref.xyz',
    out     => '01/testout.xyz',
    message => 'output flag' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
