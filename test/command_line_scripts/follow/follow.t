#!/usr/bin/env -S perl -w

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
push @args,
  { args    => '01/trial.log -a -m 1',
    message => 'Animate and select imaginary mode',
    out     => '01/test_animate_1.xyz',
    ref     => '01/ref_animate.xyz' };
push @args,
  { args    => '01/trial.log -a -m 189',
    message => 'Animate and select another mode',
    out     => '01/test_animate_189.xyz',
    ref     => '01/ref_animate_189.xyz' };
push @args,
  { args    => '01/trial.log -l',
    message => 'List frequencies (with index for selection)',
    ref     => '01/ref_list.out' };
push @args,
  { args    => '02/trial.log',
    message => 'Bad log file',
    ref     => '02/ref_fail.out',
    out     => 'stderr.tmp' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();

