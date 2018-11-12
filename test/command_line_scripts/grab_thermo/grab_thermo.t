#!/usr/bin/env -S perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'grab_thermo';
my @args;
push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/1.log',
    message => 'Single file',
    ref     => "01/1.ref" };
push @args,
  { args    => '01/*.log',
    message => 'Output file',
    out     => '01/test.csv',
    ref     => "01/ref.csv" };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
