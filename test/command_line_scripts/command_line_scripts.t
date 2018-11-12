#!/usr/bin/env perl

# Tests command line scripts

use strict;
use warnings;

use Test::More;

my @tests = (
	'grab_coords',
	'grab_thermo',
	'rmsd_align',
	'angle',
	'dihedral',
	'rotate',
	'genrotate',
	'genshift',
	'mirror',
	'substitute',
#	'precat',
	'cat_screen',
	'cat_substitute',
	'map_ligand',
	'libadd_ligand',
	'libadd_substituent',
	'follow'
);

# run each test
my @failed;
foreach my $t (@tests) {
    eval {
        chdir($t);
        my $status = system "./$t.t >/dev/null 2>stderr.tmp";
        push @failed, $t if ($status);
        ok( !$status, "Ran test for: $t.t" );
		if ($status && -f 'stderr.tmp'){
			open ERR, '<', 'stderr.tmp';
			while (my $e = <ERR>){
				diag($e)
			}
		}
		system "rm stderr.tmp" if ( -f 'stderr.tmp' );
        chdir('..');
        1;
    } or do {
        fail("Couldn't test: $t.t");
    };
    diag($@) if $@;
}

# Summary of failed tests
diag( "\nFailed tests for:" ) if @failed;
foreach my $f ( @failed ){
	diag( "    $f" );
}
diag("\n");
done_testing();
