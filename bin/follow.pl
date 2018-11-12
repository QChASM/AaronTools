#!/usr/bin/env perl
#Reads Gaussian09 output file and checks for imaginary frequencies.
#If any are found, reads in normal mode corresponding to the "lowest" imaginary frequency and prints geometry placed 0.1 along this mode
#Now takes command line argument to follow imaginary mode in "reverse" direction

use strict;
use lib qw(/usr/local/lab/sewlab/Aaron);
use AaronTools;
use Getopt::Long;

my $reverse = 0;		#flag to follow mode in reverse direction
my $mode = 0;
my $animate = 0;		#flag to produce animation rather than a single XYZ file

GetOptions(
  'reverse' => \$reverse,
  'mode=i' => \$mode,
  'animate' => \$animate
) or die "Usage: $0 LOGFILE --reverse";

if($mode != 0) {
  die "Displacement along anything other than the first mode is not implemented yet!";
}

#Read coordinates and frequencies from log file
my @coords = grab_coords($ARGV[0]);
my ($freqs_ref, $temp, $vectors_ref) = grab_freqs($ARGV[0]);

my @freqs = @{$freqs_ref};
my @vectors = @{$vectors_ref};

if($freqs[0] > 0) {
  print "No imaginary frequencies to follow...\n";
  exit(1);
}
if($animate) {
  foreach my $step (0..20) {
    my $scale = 0.1*($step-10);
    #Shift each atom
    foreach my $atom (0..$#coords) {
      coord_shift($scale*$vectors[0][$atom][0], $scale*$vectors[0][$atom][1], $scale*$vectors[0][$atom][2], \@coords, $atom);
    }
    printXYZ(\@coords, "Following imaginary frequency","$step.xyz");
  }
} else {
  my $scale = 0.1;
  if($reverse) {
    $scale *= -1;
  }

  #Shift each atom
  foreach my $atom (0..$#coords) {
    coord_shift($scale*$vectors[0][$atom][0], $scale*$vectors[0][$atom][1], $scale*$vectors[0][$atom][2], \@coords, $atom);
  }
  printXYZ(\@coords, "Following imaginary frequency");
}

