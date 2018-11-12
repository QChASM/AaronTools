#!/usr/bin/env -S perl -w

# Tests AaronTools::Catalysis->screen_subs functionality

use strict;
use warnings;

use Test::More;
use Data::Dumper;

eval {
	use lib $ENV{PERL_LIB};
    use lib $ENV{QCHASM};
    use AaronTools::Catalysis;
    1;
};
diag($@) if $@;

sub trial {
    my ( $test, $refs, $component, $subs, $reorder ) = @_;
    my $t = "$_[0]";

    eval {
        $test = new AaronTools::Catalysis( name => "$t/test" );
        ok( $test->{coords}, "Read in coords: $t/test.xyz" );
        1;
    } or do {
        $test = undef;
        fail("Trouble creating Catalysis object from $t/test.xyz");
    };
    diag($@) if $@;

    my @results;
    eval {
        @results = $test->screen_subs( $component, %{$subs} );
        1;
    } or do {
        @results = ();
    };
    ok( @results, "Call screen_subs" );
    diag($@) if $@;

    my $idx = 0;
    foreach my $r ( @{$refs} ) {
        $r = "$t/$r";
        my $ref;
        eval {
            $ref = new AaronTools::Catalysis( name => $r );
            ok( $ref->{coords}, "Read in reference coords: $r.xyz" );
            1;
        } or do {
            $ref = undef;
            fail("Trouble creating Catalysis object from $r.xyz");
        };
        diag($@) if $@;

        eval {
            my $rmsd =
              $results[ $idx++ ]->RMSD( ref_geo => $ref, reorder => $reorder );
            ok( $rmsd < 0.2, "Substituted result should match reference" );
            1;
        } or do {
            fail("Couldn't calculate RMSD: $r");
        };
        diag($@) if $@;
    }
}

my $test    = '01';
my $subs    = [ 'Me', 'Et', 'Cl', 'tBu' ];
my $reorder = 0;
trial( $test, $subs, 'ligand', { 14 => $subs }, $reorder );

done_testing();
