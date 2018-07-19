package AaronTools::FileReader;

use strict; use warnings;

use lib $ENV{'QCHASM'};

use AaronTools::Atoms qw(:BASIC :LJ);

use Exporter qw(import);

our @EXPORT = qw(grab_coords);

my $elements = ELEMENTS;

sub grab_coords {
  my $filename = $_[0];
  my @coords;
  my @atoms;
  my @flags;
  my $constraints;
  my $ligand;
  my $center;
  my $key_atoms;
  my $bonds;
  my $conformer;   #information for the conformer rotation

  if(-e $filename) {                                   #check to make sure file exists first
    open (INFILE, "<$filename") or die "Can't open $filename";

    if($filename =~ /(\S+)\.log/) {                       #G09 log file
    # Snatches last geometry from LOG file
      while (<INFILE>) {
        my $line=$_;
        if($line =~ / orientation:/) {
          @coords = ();
          @atoms = ();
		  @flags = ();
          $line = <INFILE>;
          $line = <INFILE>;
          $line = <INFILE>;
          $line = <INFILE>;
          $line = <INFILE>;
          do {
			# centernumber atomicnumber atomictypes coordinates
            if($line =~ /^\s+\d+\s+(\S+)\s+(\S*)\s+(\S+)\s+(\S+)\s+(\S+)/) {
              my $coord = [$3, $4, $5];
              push(@coords, $coord);
              push(@atoms, $elements->[$1]);
			  if ($2){
				  push(@flags, $2);
			  }else{
				push(@flags, 0);
			  }
              $line = <INFILE>;
            }
          } while(!($line =~ /--/));
        }
      }
    } elsif ($filename =~ /(\S+)\.xyz/) {         #XYZ file
      while(<INFILE>) {
        chomp;
        if($_ =~ /^\s?([a-zA-Z]+)\s+(-?\d+\.?\d*)\s+(-?\d+\.?\d*)\s+(-?\d+\.?\d*)/) {
          my $coord = [$2, $3, $4];
          push(@coords, $coord);
          push(@atoms, $1);
          push(@flags, 0);
          next;
        }
        if ($_ =~ /\s+F:(\S+)/ || ($_ =~ /^F:(\S+)/)) {			    #Constraints (F:1-2;3-4)
            my @constraints;
            my @temp = split (/;/, $1);
            while (@temp) {
                my $bond = [ map { $_ - 1 } split(/-/, shift @temp) ];
                push (@constraints, $bond);
            }
            $constraints = [@constraints];
        }
        if ($_ =~ /\s+L:(\S+)/ || ($_ =~ /^L:(\S+)/)) {                    #Ligand atoms (L:14-26)
            my @temp = map { $_ - 1 } split(/-/, $1);
            $ligand = [$temp[0]..$temp[1]];
        }
        if ($_ =~ /\s+C:(\S+)/ || ($_ =~ /^C:(\S+)/)) {			   #Reaction Center (C:13)
            $center = $1 - 1;
        }
        if ($_ =~ /\s+K:(\S+)/ || ($_ =~ /^K:(\S+)/)) {			   #Key atoms (K:14,15)
            my @temp = split (/;/, $1);
            my @key_atoms;
            while (@temp) {
                my @keys = map { $_ - 1 } split (/,/, shift @temp);
                push (@key_atoms, [@keys]);
            }
            $key_atoms = [@key_atoms];
        }
        if ($_ =~ /\s+B:(\S+)/ || ($_ =~ /^B:(\S+)/)) {			    #Not sure! (B:1-2;3-4)
            my @temp = split (/;/, $1);
            my @bonds;
            while (@temp) {
                my @bonds_frag = split (/,/, shift @temp);
                @bonds_frag = map { [ map { $_ - 1 }
                                      split (/-/, $_) ] } @bonds_frag;
                push (@bonds, [@bonds_frag]);
            }
            $bonds = [@bonds];
        }
        if ($_ =~ /\s+CF:(\S+)/ || ($_ =~ /^CF:(\S+)/)) {		    #Conformer information (CF:XXX)
            $conformer = [split (/,/, $1)];
        }

      }
      #my $correct_input = &examine_structure($key_atoms, $bonds);

      #unless ($correct_input) {
      #    print "Incorrect input information in the $filename" .
      #          "Aaron will quit at this time. Please modify the " .
      #          "Input information.\n";
      #    exit(1);
      #}

    } elsif ($filename =~ /(\S+)\.pdb/) {		#PDB file
      while(<INFILE>) {
        $_ =~ s/^\s+//;
	#Typical PDB file line:
	#ATOM     13  CB  ASP A  23      -0.219   5.194 -16.219  1.00 30.89           C
        #****         **  ***            ******   *****  ******                       *
        #This is ugly, but allows us to skip over 'missing' entries in formatted PDB file!
	#              (ATOM)     13  (CB)  (ASP) A  (23)    (  -0.219)(   5.194)( -16.219)  1.00 30.89          ( C)
        if($_ =~ /(ATOM|HETATM).......(..)..(...)....(..)....(........)(........)(........)......................(..)/) {
          chomp;
          #strip leading whitespace off of everything
          my $type = $1;
          my $atom_type = $2;
	      my $res_name = $3;
	      my $chain = $4;
	      my $x = $5;
	      my $y = $6;
          my $z = $7;
          my $element = $8;
          #strip all whitespace from element name, otherwise I can't use this as a hash key later!
          $element =~ s/\s+//;
          my $coord = [$x, $y, $z];
          push(@coords, $coord);
          push(@atoms, $element);
          push(@flags, 0);
        }
      }
    } elsif ($filename =~ /(\S+)\.com/) {	#G09 com file (Cartesian input!)
      while (<INFILE>) {
        chomp;
        $_ =~ s/^\s+//;

        my ($coord, $flag, $atom);
        if($_ =~ /^\s?([a-zA-Z]+)\s+(-?\d)\s+(-?\d+\.?\d*)\s+(-?\d+\.?\d*)\s+(-?\d+\.?\d*)\s*$/) {
            $coord = [$3, $4, $5];
            $flag = $2;
            $atom = $1;
            push(@coords, $coord);
            push(@atoms, $atom);
            push(@flags, $flag);
        } elsif($_ =~ /^\s?([a-zA-Z]+)\s+(-?\d+\.?\d*)\s+(-?\d+\.?\d*)\s+(-?\d+\.?\d*)\s*$/) {
            $coord = [$2, $3, $4];
            $flag = 0;
            $atom = $1;
            push(@coords, $coord);
            push(@atoms, $atom);
            push(@flags, $flag);
        }
      }
    }
    close(INFILE);
  }
  return (\@atoms, \@flags, \@coords, $constraints, $ligand, $center, $key_atoms, $bonds, $conformer);
} #End sub grab_coords


sub examine_structure {
    my ($key_atoms, $bonds) = @_;

    my $correct_input = 1;

    if ($key_atoms && $#{ $key_atoms } > 0) {
        if (! $bonds) {
            print {*STDERR} "more than 1 reactive fragment was found, ".
                  "so the bond connecting the two fragments should be specified. ";
            $correct_input = 0;
        }elsif ($#{ $key_atoms } != $#{ $bonds } + 1) {
            print {*STDERR} "The number of bonds connecting reactive fragments of catalyst " .
                  "doesn't match the number of reactive fragments. ";
            $correct_input = 0;
        }
    }

    return $correct_input;
}

