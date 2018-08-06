#!/usr/bin/perl -w

# Tests follow script

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'follow';
my @args;

push @args,
  { args    => '-h',
    message => 'Help flag' };
push @args,
  { args    => '01/trial.log',
    message => "Test default",
    out     => '01/test_default.xyz',
    ref     => '01/ref_default.xyz' };
push @args,
  { args    => '01/trial.log -r',
    message => 'Test reverse',
    out     => '01/test_reverse.xyz',
    ref     => '01/ref_reverse.xyz' };
push @args,
  { args    => '01/trial.log -a',
    message => 'Test animate',
    out     => '01/test_animate.xyz',
    ref     => '01/ref_animate.xyz' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();

