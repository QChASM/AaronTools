#!/usr/bin/perl -w

# Move through testing directories in the appropriate order

use strict;
use warnings;

use Test::More;
use Data::Dumper;

my @tests = ( 'environment_setup',
              'object_creation',
              'substitute',
              'screen_subs',
              'map_ligand' );

# run each test
my @failed;
foreach my $t (@tests) {
    diag("\n\n$t\n\n\n");
    eval {
        chdir($t);
        my $status = system "./$t.t";
        push @failed, $t if ($status);
        chdir('..');
        ok( !$status, "Ran test for: $t.t" );
        1;
    } or do {
        fail("Couldn't test: $t.t");
    };
    diag($@) if $@;
}

done_testing();
# Summary of failed tests
diag( "Failed tests for:" );
foreach my $f ( @failed ){
	diag( "    $f" );
}

