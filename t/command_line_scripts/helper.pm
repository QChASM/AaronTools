#!/usr/bin/perl -w

# Test import of coordinates from various filetypes

package helper;
use strict;
use warnings;

use Test::More;
use Data::Dumper;

sub trial {
    my $cmd  = shift;
    my $args = shift;
    my ( $err, $test, $ref, $success );

    system "$cmd $args->{args} 2>stderr.tmp 1>stdout.tmp";
    ok( !$?, "$args->{message}: \n    $cmd $args->{args}" );
    open $err, '<', 'stderr.tmp';
    diag(<$err>) if $?;
    close $err;

    if ( defined $args->{ref} ) {
        unless ( defined $args->{out} ) {
            $args->{out} = 'stdout.tmp';
        }

        open $test, '<', $args->{out};
        open $ref,  '<', $args->{ref};
        $success = 1;
        while ( defined( my $t = <$test> ) && defined( my $r = <$ref> ) ) {
            $success = $success && ( $t eq $r );
            last unless $success;
        }
        ok( $success,
            "Test output should match expected output: \n    $cmd $args->{args}"
        );
    }

    system "rm stdout.tmp stderr.tmp";
}

1;
