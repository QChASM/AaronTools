#!/usr/bin/perl -w

# Tests substitute functionality on Geometry and Catalysis objects

use strict;
use warnings;

use Test::More;
use Data::Dumper;

use lib $ENV{QCHASM};
use_ok('AaronTools::Geometry');
use_ok('AaronTools::Catalysis');

sub trial {
    my ( $type, $test, $ref, $subs ) = @_;

    eval {
        $test = new $type( name => $test );
        ok( @{ $test->{coords} }, "Test has coordinates" );
        1;
    } or do {
        $test = undef;
        fail("Read in $_[1]");
    };
    diag($@) if $@;

    eval {
        $ref = new $type( name => $ref );
        ok( @{ $ref->{coords} }, "Reference has coordinates" );
        1;
    } or do {
        fail("Read in $_[2]");
        $ref = undef;
    };
    diag($@) if $@;

    my $test_name = "Substitute $subs->{target} on $subs->{component}";
    my $rmsd;
    eval {
        $test->substitute( $subs->{component},
                           $subs->{target} => $subs->{subs} );
        pass($test_name);
        1;
    } or do {
        fail($test_name);
    };
    diag($@) if $@;

    eval {
        $rmsd = $test->RMSD( ref_geo => $ref );
        ok( $rmsd < 0.2, "RMSD validation" );
        diag("RMSD: $rmsd") if ( $rmsd > 0.2 );
        1;
    } or do {
        fail("RMSD could not be calculated");
    };
    diag($@) if $@;
}

my @trials;
push @trials,
  [ 'AaronTools::Catalysis', '01',
    { component => 'ligand', target => 'Ph', subs => 'Me' } ];

foreach my $t (@trials) {
    trial( $t->[0], "$t->[1]/test", "$t->[1]/ref",
           $t->[2] );
}

done_testing();

