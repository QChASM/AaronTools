#!/usr/bin/env perl

=head1 SYNOPSIS

Provides utilities for common interactions with AaronTools

=cut

use lib $ENV{'QCHASM'};

package _utils;
use strict;
use Data::Dumper;

my $debug = 1;

sub get_geom {

=head2 get_geom($file)

Gets geometry object from file

=cut

    use AaronTools::Geometry;

    my $file = shift;
    my $geom = new AaronTools::Geometry();
    $geom->{name} = $file;
    $geom->read_geometry($file);
    unless ( @{ $geom->elements() } ) {
        print {*STDERR} ("\nCouldn't read geometry: $file\n\n");
        return 0;
    }
    return $geom;
}

sub get_cat {

=head2 get_cat($file, \%substituents)

Gets catalysis object from file. Optional substituent information can be provided.

\%substituents = {'ligand'=>{ atom=>label, ... }, 'substrate'=>{ atom=>label, ... }}

=cut

    use AaronTools::Catalysis;

    my $file = shift;

    my %params;
    $params{substituents} = shift;
    ( $params{name} ) = ( $file =~ /(.*)\..*?$/ );

    my $relnum = shift;

    # creat Catalysis object
    my $cat = new AaronTools::Catalysis( 'name' => $params{name} );

    # if substituent info provided, make atom numbering relative, if necessary
    if ( $params{substituents} && !($relnum) ) {
        # this gets the number to subtract for relative numbering
        my $ligstart = get_ligstart($cat);
        my $substart = get_substart($cat);

        # update info hash to reflect numbering change
        foreach my $sub ( keys %{ $params{substituents}{ligand} } ) {
            $params{substituents}{ligand}{ $sub - $ligstart } =
              delete $params{substituents}{ligand}{$sub};
        }
        foreach my $sub ( keys %{ $params{substituents}{substrate} } ) {
            $params{substituents}{substrate}{ $sub - $substart } =
              delete $params{substituents}{substrate}{$sub};
        }

    }
    # update catalysis object with substituent info, if provided
    $cat = new AaronTools::Catalysis(%params) if ( $params{substituents} );

    # check for success
    unless ( @{ $cat->{elements} } ) {
        print {*STDERR} ("\nCouldn't read catalyst geometry: $file\n\n");
        return 0;
    }
    return $cat;
}

sub get_lig {

=head2 get_lig($file)

Reads in ligand object from .xyz file or by built-in name

=cut

    use AaronTools::Catalysis;

    my $file = shift;
    my $lig;
    if ( $file =~ /.*\.xyz$/ ) {
        $lig = new AaronTools::Ligand( name => ( $file =~ /(.*)\..*?$/ ) );
    } else {
        $lig = new AaronTools::Ligand( name => $file );
    }
    unless ( @{ $lig->{elements} } ) {
        print {*STDERR} ("\nCouldn't read ligand geometry: $file\n\n");
        return 0;
    }
    return $lig;
}

sub get_outfile {

=head2 get_outfile($filebase, $path, \@appends, $sep)

Generates an outfile name for printXYZ() methods

outfile = path/filebase_appends.xyz (sep defaults to _)

path is created if necessary, filebase is stripped of path if necessary

=cut

    # prints to STDOUT if $path == ''
    # or saves to infile_append1_append2_etc.xyz
    # $path= '-', defaults to cwd
    my $filebase = shift;
    my $path     = shift;
    my $appends  = shift(@_) // [];
    my $sep      = '_';

    my $outfile = '';
    if ( $path ne '-' ) {
        # strip just file name (no path or file extension)
        $outfile = $filebase;
        $outfile =~ s/(.*\/)?(.*)\..*?$/$2/;
        if ( $path ne '' ) {
            unless ( -d $path ) {
                system "mkdir -p $path";
            }
            # if no directory specified, write to cwd
            # make sure we don't have double path seperators!
            if ( $path =~ /.*\/$/ ) {
                $outfile = $path . $outfile;
            } else {
                $outfile = $path . '/' . $outfile;
            }
        }
        foreach my $append (@$appends) {
            $outfile .= $sep . $append;
        }
        $outfile .= '.xyz';
    }
    return $outfile;
}

sub strip_dir {

=head2 strip_dir($fname)

Removes the directory path and returns only the file name

=cut

    my $fname = shift;
    $fname =~ s/(.*\/)*(.*)/$2/;
    return $fname;
}

sub mkdirsfor {

=head2 mkdirsfor( FILENAME )

Creates the directory structure necessary to save FILENAME

=cut

    my $path = shift;
    if ( $path eq strip_dir($path) ) { return; }
    $path =~ s/(.*\/)*(.*)/$1/;
    system "mkdir -p $path";
}

sub handle_overwrite {

=head2 handle_overwrite( $outfile )

Queries the user to see if it is ok to overwrite the file, if it exists. Returns the (possibly edited) file name.

=cut

    my $outfile     = shift;
    my $old_outfile = $outfile;
    while ( $outfile && -f $outfile ) {
        my $ans;
        do {
            $ans = '';
            print "File $outfile exists... Ok to overwrite? [y/N]: ";
            $ans = <STDIN>;
            chomp $ans;
        } while ( $ans !~ /^y(es)?$/i && $ans !~ /^no?$/i && $ans !~ /^$/ );
        if ( $ans !~ /^y(es)?$/i ) {
            print "New name: ";
            $outfile = <STDIN>;
            chomp $outfile;
            if ( $outfile =~ /^$/ ) {
                $outfile = $old_outfile;
            } elsif ( $outfile =~ /^stdout$/i ) {
                $outfile = '';
            }
        } else {
            last;
        }
    }
    return $outfile;
}

sub get_ligstart {

=head2 get_ligstart($catalysis)

Returns a value to be subtracted from an atom index to switch from absolute to relative indexing

=cut

    my $cat = shift;
    return ( sort { $a <=> $b } @{ $cat->{ligand_atoms} } )[0];
}

sub get_substart {

=head2 get_substart($catalysis)

Returns a value to be subtracted from an atom index to switch from absolute to relative indexing

=cut

    my $cat = shift;
    return ( sort { $a <=> $b } @{ $cat->{substrate_atoms} } )[0];
}

sub get_sub_numbers {

=head2 get_sub_numbers($catalysis_object, $component_name)

Returns a hash, keyed by substituent labels provided during catalyst object generation, with values corresponding to AaronTools' atom numbering for the substituent.

=cut

    my $geom      = shift;
    my $component = shift;

    my %convert;
    # determine requested target atom, in aaron's number scheme
    foreach my $aaron_num ( keys %{ $geom->{$component}{substituents} } ) {
        my $target;
        if ( $geom->{$component}->{substituents}->{$aaron_num}->{sub} ) {
            # only add to screen_sub convert if it was a substituent requested
            $target =
              $geom->{$component}->{substituents}->{$aaron_num}->{sub};
        } else {
            # but not ones that were simply auto-detected
            next;
        }

        if ( $convert{$target} ) {
            $convert{$target} .= "," . $aaron_num;
        } else {
            $convert{$target} = $aaron_num;
        }
    }
    return %convert;
}

sub get_available_subs {
    my @available =
      grep { s/.*\/(.*).xyz/$1/ } <$ENV{QCHASM}/AaronTools/Subs/*.xyz>;
    if ( -d "$ENV{HOME}/Aaron_libs/Subs" ) {
        push @available,
          grep { s/.*\/(.*).xyz/$1/ } <$ENV{HOME}/Aaron_libs/Subs/*.xyz>;
    }
    my $count = 0;
    foreach my $a (@available) {
        print sprintf( "%18s", $a );
        if ( ++$count % 3 == 0 ) {
            print "\n";
        }
    }
    print "\n";
}

1;
