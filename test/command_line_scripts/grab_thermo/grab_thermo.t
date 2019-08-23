#!/usr/bin/env perl

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
  { args    => '01/1.log 01/2.log 01/3.log 01/4.log 01/5.log 01/6.log 01/7.log 01/8.log 01/9.log 01/10.log 01/11.log 01/12.log 01/13.log',
    message => 'CSV file from multiple log files',
    out     => '01/test.csv',
    ref     => "01/ref.csv" };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
