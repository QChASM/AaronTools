#!/usr/bin/env -S perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'angle';
my @args;
push @args, { args => '-h', message => 'Help flag' };
push @args, { args    => '-a 60 58 59 01/ref.xyz',
              message => 'Get angle in degrees',
              ref     => '01/angle.ref' };
push @args, { args    => '-a 60 58 59 01/ref.xyz -r',
              message => 'Get angle in radians',
              ref     => '01/radian.ref' };

foreach my $a (@args) {
    helper::trial( $cmd, $a );
}

done_testing();
