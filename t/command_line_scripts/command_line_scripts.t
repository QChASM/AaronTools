#!/usr/bin/perl -w

# Tests command line scripts

use strict;
use warnings;

use Test::More;

my @tests = (
	'grab_coords',
#	'grab_thermo',
#	'rmsd_align',
	'angle',
#	'dihedral',
#	'rotate',
#	'genrotate',
#	'genshift',
#	'mirror',
#	'substitute',
#	'precat',
#	'cat_screen',
#	'cat_substitute',
#	'map_ligand',
#	'libadd_ligand',
#	'libadd_substituent'
);

# run each test
my @failed;
foreach my $t (@tests) {
    eval {
        chdir($t);
        my $status = system "./$t.t >/dev/null";
#		if (-e 'stderr.tmp'){
#			open my $err, '<', 'stderr.tmp';
#			while (my $e = <$err>){
#				if ( $e !~ /^# / ){
#					print($e);
#				}
#			}
#			system "rm stderr.tmp";
#		}
        push @failed, $t if ($status);
        chdir('..');
        ok( !$status, "Ran test for: $t.t" );
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
