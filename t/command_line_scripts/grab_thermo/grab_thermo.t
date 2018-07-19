#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

use strict;
use warnings;

use Test::More;
use lib "$ENV{QCHASM}/AaronTools/t/command_line_scripts";
require helper;

my $cmd = 'grab_thermo';
my @args;
push @args, { args => '-h', message => 'Help flag' };

foreach my $a (@args){
	helper::trial($cmd, $a);
}

done_testing();
