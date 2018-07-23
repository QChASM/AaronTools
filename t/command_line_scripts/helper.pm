#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

package helper;
use strict;
use warnings;

use Test::More;
use Data::Dumper;

use lib $ENV{QCHASM};
use AaronTools::Geometry;

sub trial {
    my $cmd  = shift;
    my $args = shift;
    my ( $err, $test, $ref, $success );

    system "$cmd $args->{args} 2>stderr.tmp 1>stdout.tmp";
    ok( !$?, "$args->{message}: $args->{args}" );
    open $err, '<', 'stderr.tmp';
    diag(<$err>) if $?;
    close $err;

    if ( defined $args->{ref} ) {
        unless ( defined $args->{out} ) {
            $args->{out} = 'stdout.tmp';
        }

        if ( $args->{rmsd} ) {
            $success = test_rmsd( $args->{out}, $args->{ref}, $args->{rmsd},
                                  $args->{reorder} );
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

    system "rm stdout.tmp stderr.tmp";
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
    my $reorder   = 0;

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
    if ( $rmsd < $threshold ) {
        return 1;
    }
    return 0;
}

1;
