#!/usr/bin/env -S perl -w

# Tests AaronTools::Catalysis map_ligand method

use strict;
use warnings;

use Test::More;

use Data::Dumper;

use lib $ENV{PERL_LIB};
use lib $ENV{QCHASM};
use AaronTools::Catalysis;

sub trial {
    my ( $cata, $ref, $ligand ) = @_;

    eval {
        $cata = new AaronTools::Catalysis( name => $cata );
        ok( @{ $cata->{coords} }, "Test catalyst has coordinates" );
        1;
    } or do {
        $cata = undef;
        fail("Couldn't create catalysis object from $_[0]");
    };
    diag($@) if $@;

    eval {
        $ref = new AaronTools::Catalysis( name => $ref );
        ok( @{ $ref->{coords} }, "Reference catalyst has coordinates" );
        1;
    } or do {
        $ref = undef;
        fail("Couldn't create catalysis object from $_[1]");
    };
    diag($@) if $@;

    eval {
        $ligand = new AaronTools::Ligand( name => $ligand );
        ok( @{ $ligand->{coords} }, "Ligand has coordinates" );
        1;
    } or do {
        $ligand = undef;
        fail("Couldn't create ligand object from $_[2]");
    };
    diag($@) if $@;

    eval {
        $cata->map_ligand($ligand);
        check_rmsd( $cata, $ref );
        1;
    } or do {
        fail("Couldn't map ligand to catalyst");
    };
    diag($@) if $@;
    return $cata;
}

sub check_rmsd {
    my ( $cata, $ref ) = @_;

	# test backbond rmsd
    my $backbone_rmsd;
    eval {
        my $cata_backbone = $cata->ligand()->backbone();
        my $ref_backbone  = $ref->ligand()->backbone();

        $backbone_rmsd = $cata_backbone->RMSD( ref_geo => $ref_backbone );

        ok( $backbone_rmsd < 10**(-5), "RMSD validation" );
        diag("Backbone RMSD: $backbone_rmsd");

        1;
    } or do {
        fail("Couldn't get rmsd between mapped and reference structures");
    };
    diag($@) if $@;
}

my @LIGANDS = ( 'R-SEGPHOS', 'Paton_EL', 'dithiolate-4F', 'squaramide-iPr' );
foreach my $i ( 1 .. @LIGANDS ) {
    my $ligand = $LIGANDS[ $i - 1 ];
    diag("Testing ligand $ligand");

    $i = sprintf( "%02s", $i );
    my $cata = trial( "$i/test", "$i/ref", $ligand );
    $cata->printXYZ( "$i/result.xyz", '', 1 );

    diag("\n");
}

done_testing();

