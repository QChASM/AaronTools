#!/usr/bin/perl -w

# Tests AaronTools::Catalysis map_ligand method

use strict;
use warnings;

use Test::More;

use Data::Dumper;

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
}

sub check_rmsd {
    my ( $cata, $ref ) = @_;
    my ( $total_rmsd, $backbone_rmsd );
    eval {
        my $cata_backbone = $cata->ligand()->backbone();
        my $ref_backbone  = $ref->ligand()->backbone();

        $total_rmsd = $cata->RMSD( ref_geo => $ref );
        $backbone_rmsd = $cata_backbone->RMSD( ref_geo => $ref_backbone );

        ok( $total_rmsd < 1.0 && $backbone_rmsd < 0.1,
            "Mapped structure should match reference." );
        diag("Total RMSD: $total_rmsd");
        diag("Backbone RMSD: $backbone_rmsd");

        1;
    } or do {
        fail("Couln't get rmsd between mapped and reference structures");
    };
    diag($@) if $@;
}

#my @LIGANDS = ( 'S-SEGPHOS', 'Paton_EL', 'dithiolate-4F', 'squaramide-iPr' );
my @LIGANDS = ( 'S-SEGPHOS' );
foreach my $i ( 1 .. @LIGANDS ) {
    my $ligand = $LIGANDS[ $i - 1 ];
	diag("Testing ligand $ligand");

    $i = sprintf( "%02s", $i );
    trial( "$i/test", "$i/ref", $ligand );

	diag("\n");
}

done_testing();

