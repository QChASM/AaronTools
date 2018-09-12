#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

package helper;
use strict;
use warnings;

use Test::More;
use Data::Dumper;

use lib $ENV{QCHASM};
use lib $ENV{PERL_LIB};
use AaronTools::Geometry;

sub trial {
    my $cmd  = shift;
    my $args = shift;
    my ( $err, $test, $ref, $success );

    $cmd = "$ENV{QCHASM}/AaronTools/bin/$cmd";
    if (    defined $args->{out}
         && $args->{out} ne 'stderr.tmp'
         && $args->{out} ne 'stdout.tmp' )
    {
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
    my $success = 0;

    unless ( -f $test && -f $ref ) {
        diag "File $ref does not exist"  unless ( -f $ref );
        diag "File $test does not exist" unless ( -f $test );
        return 0;
    }

    open TEST, '<', $test;
    open REF,  '<', $ref;
    my $first = 1;
    while ( defined ( my $t = <TEST> ) && defined ( my $r = <REF> ) ) {
        $success = ( $success || $first ) && ( $t eq $r );
        $first = 0;
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

1;
