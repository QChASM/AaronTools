#!/usr/bin/env -S perl -w

# Validate creation of AaronTools objects

use strict;
use warnings;

use Test::More;
use Data::Dumper;

# Check loading of libraries and packages
eval {
    use lib $ENV{QCHASM};
    use lib $ENV{PERL_LIB};
    pass("Loaded libraries");
    1;
} or do {
    fail("Failed to load necessary libraries");
    die $@;
};

eval {
    use AaronTools::Geometry;
    pass("AaronTools::Geometry package available");
    1;
} or do {
    fail("Failed to import AaronTools::Geometry package");
    die $@;
};

eval {
    use AaronTools::Catalysis;
    pass("AaronTools::Catalysis package available");
    1;
} or do {
    fail("Failed to import AaronTools::Catalysis package");
    die $@;
};

sub validate_object {
    my $obj  = shift;
    my $skip = shift;

    unless ($obj) {
        fail("Object creation failed, cannot validate data structure");
    }

    my @all_keys = keys %$obj;

    foreach my $k (@all_keys) {
        if ( grep( /^$k$/, @$skip ) ) {
            # skip requested aspects of data structure
          SKIP: { skip $k, 1 if 1; }
        } elsif ( ref( $obj->{$k} ) eq 'ARRAY' ) {
            # want to know if the array ref actually contains info
            ok( @{ $obj->{$k} }, "check for $k" );
        } elsif ( ref( $obj->{$k} ) eq 'HASH' ) {
            # want to know if the hash ref actually contains info
            ok( %{ $obj->{$k} }, "check for $k" );
        } else {
            # if shallow, just check that it exists
            ok( $obj->{$k}, "check for $k" );
        }
    }
}

sub trial {
    my ( $type, $g, $gskip ) = @_;
    my ($geom);

    # Check Geometry objects
    diag("\n$type");
    eval {
        $geom = $type->new( name => $g );
        1;
    } or do {
        $geom = undef;
    };
    ok( $geom, "Object creation: $g.xyz" );
    diag($@) if $@;
    # Check things were actually read in, but skip things listed in $gskip
    validate_object( $geom, $gskip );
}

my ( @type, @geom, @skip );

push @type, 'AaronTools::Geometry';
push @geom, '01/geometry';
push @skip, ['constraints'];

push @type, 'AaronTools::Catalysis';
push @geom, '01/catalysis';
push @skip, [];

push @type, 'AaronTools::Ligand';
push @geom, 'dithiolate-4F';
push @skip, [ 'RMSD_bonds', 'constraints' ];

foreach my $idx ( 0 .. $#geom ) {
    trial( $type[$idx], $geom[$idx], $skip[$idx] );
}

done_testing();

