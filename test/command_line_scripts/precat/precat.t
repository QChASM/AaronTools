#!/usr/bin/env perl

# Test import of coordinates from various filetypes

use strict;
use warnings;

use lib "$ENV{QCHASM}/AaronTools/test/command_line_scripts";

use Test::More;
require helper;

my $cmd = 'precat';
my @args;
push @args, { args => '-h', message => 'Help flag' };

foreach my $a (@args){
	helper::trial($cmd, $a);
}

done_testing();
