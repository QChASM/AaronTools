#!/usr/bin/env perl

# Test import of coordinates from various filetypes

package helper;
use strict;
use warnings;

use Test::More;
use Data::Dumper;

use lib $ENV{QCHASM};
use lib $ENV{PERL_LIB};
use AaronTools::Geometry;
use AaronTools::Catalysis;

sub trial {
    my $cmd  = shift;
    my $args = shift;
    my ( $err, $test, $ref, $success );

    $cmd = "$ENV{QCHASM}/AaronTools/bin/$cmd";
    if ( defined $args->{out} ) {
        system
          "$cmd $args->{args} -o $args->{out} -f 2>stderr.tmp 1>stdout.xyz";
    } else {
        system "$cmd $args->{args} 2>stderr.tmp 1>stdout.xyz";
    }
    ok( !$?, "$args->{message}: $args->{args}" );
    open $err, '<', 'stderr.tmp';
    diag(<$err>) if $?;
    close $err;

    if ( defined $args->{ref} ) {
        unless ( defined $args->{out} ) {
            $args->{out} = 'stdout.xyz';
        }

        if ( defined $args->{rmsd} ) {
            $success = test_rmsd( $args->{out}, $args->{ref}, $args->{rmsd},
                                  $args->{reorder} );
        } elsif ( defined $args->{backbone} ) {
            $success = test_backbone_rmsd( $args->{out}, $args->{ref},
                                          $args->{backbone}, $args->{reorder} );
        } else {
            $success = test_file_contents( $args->{out}, $args->{ref} );
        }

        my $error = '';
        if ( $success !~ /^[01]$/ ) {
            $error   = $success;
            $success = 0;
        }
        ok( $success,
            "Test output should match expected output" );
        diag($error) if $error;

    }

    system "rm stdout.xyz stderr.tmp";
}

sub test_file_contents {
    my $test    = shift;
    my $ref     = shift;
    my $success = 1;

    open TEST, '<', $test;
    open REF,  '<', $ref;
    while ( defined( my $t = <TEST> ) && defined( my $r = <REF> ) ) {
        $success = $success && ( $t eq $r );
        last unless $success;
    }

    return $success;
}

sub test_rmsd {
    my $test      = shift;
    my $ref       = shift;
    my $threshold = shift;
    my $reorder   = shift;
    $reorder //= 0;

    # handle lists of files produced by things like cat_screen
    my ( @ref, @test );
    eval {
        if ( -d $ref ) {
            opendir my ($d), $ref;
            @ref = readdir $d;
            @ref = grep { $_ =~ /ref.*\.xyz/ } @ref;
            @ref = map { $ref . '/' . $_ } @ref;
            closedir $d;
            for my $r (@ref) {
                my $t = $r;
                $t =~ s/ref/test/;
                push @test, $t;
            }
        } else {
            @ref  = ($ref);
            @test = ($test);
        }
        1;
    } or do {
        return $@;
    };

    for ( my $i = 0; $i < @ref; $i++ ) {
        my $ref  = $ref[$i];
        my $test = $test[$i];
        my $rmsd;

        eval {
            $test = new AaronTools::Geometry( name => $test =~ /(.*)\.xyz/ );
            $ref  = new AaronTools::Geometry( name => $ref =~ /(.*)\.xyz/ );

            $rmsd = $test->RMSD( ref_geo => $ref, reorder => $reorder );
            1;
        } or do {
            return $@;
        };

        diag("RMSD: $rmsd");
        if ( $rmsd > $threshold ) {
            return 0;
        }
    }
    return 1;
}

sub test_backbone_rmsd {
    my $test      = shift;
    my $ref       = shift;
    my $threshold = shift;
    my $reorder   = shift;
    $reorder //= 0;

    # handle lists of files produced by things like cat_screen
    my ( @ref, @test );
    eval {
        if ( -d $ref ) {
            opendir my ($d), $ref;
            @ref = readdir $d;
            @ref = grep { $_ =~ /ref.*\.xyz/ } @ref;
            @ref = map { $ref . '/' . $_ } @ref;
            closedir $d;
            for my $r (@ref) {
                my $t = $r;
                $t =~ s/ref/test/;
                push @test, $t;
            }
        } else {
            @ref  = ($ref);
            @test = ($test);
        }
        1;
    } or do {
        return $@;
    };

    for ( my $i = 0; $i < @ref; $i++ ) {
        my $ref  = $ref[$i];
        my $test = $test[$i];
        my $rmsd;

        eval {
            $test = new AaronTools::Catalysis( name => $test =~ /(.*)\.xyz/ );
            $ref  = new AaronTools::Catalysis( name => $ref =~ /(.*)\.xyz/ );

			my $test_backbone = $test->ligand()->backbone();
			my $ref_backbone = $ref->ligand()->backbone();
            $rmsd = $test_backbone->RMSD( ref_geo => $ref_backbone, reorder => $reorder );
            1;
        } or do {
            return $@;
        };

        diag("Backbone RMSD: $rmsd");
        if ( $rmsd > $threshold ) {
            return 0;
        }
    }
    return 1;
}

1;
