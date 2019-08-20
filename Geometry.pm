#Contributors Yanfei Guan and Steven E. Wheeler

use lib $ENV{'QCHASM'};
use lib $ENV{'PERL_LIB'};

use AaronTools::Constants qw(CUTOFF);
use AaronTools::Atoms qw(:BASIC :LJ);
use AaronTools::Molecules;
use AaronTools::FileReader;

our $CONNECTIVITY = CONNECTIVITY;
our $UNROTATABLE_BOND = UNROTATABLE_BOND;
our $CUTOFF = CUTOFF;
our $mass = MASS;
our $radii = RADII;
my $TMETAL = TMETAL;
our $QCHASM = $ENV{'QCHASM'};
$QCHASM =~ s|/\z||;	#Strip trailing / from $QCHASM if it exists
our $rij = RIJ;
our $eij = EIJ;

package AaronTools::Geometry;
use strict; use warnings;
use Math::Trig;
use Math::Vector::Real;
use Math::MatrixReal;
use Data::Dumper;

sub new {
    my $class = shift;
    my %param = @_;
    my $self = {
        name => $param{name},
        elements => $param{elements},
        flags => $param{flags},
        coords => $param{coords},
        connection => $param{connection},
        constraints => $param{constraints},
    };

    bless $self, $class;

    $self->{elements} //= [];
    $self->{flags} //= [];
    $self->{coords} //= [];
    $self->{connection} //= [];
    $self->{constraints} //= [];

    unless (@{$self->{coords}}) {
        if ($self->{name}) {
            if (-f "$self->{name}.xyz") {
                $self->read_geometry("$self->{name}.xyz");
            }elsif ($self->{name} && AaronTools::Molecules::built_in($self->{name})) {
                $self->{coords} = AaronTools::Molecules::coords($self->{name});
                $self->{elements} = AaronTools::Molecules::elements($self->{name});
                $self->{flags} = AaronTools::Molecules::flags($self->{name});
            }
        }
    }


    $self->refresh_connected() unless @{$self->{connection}};

    return $self;
}


sub set_name {
    my ($self, $name) = @_;
    $self->{name} = $name;
}


sub name {
    my $self = shift;
    return $self->{name};
}


sub elements {
    my $self = shift;
    return $self->{elements};
}


sub flags {
    my $self = shift;
    return $self->{flags};
}


sub coords {
    my $self = shift;
    return Math::MatrixReal->new_from_rows($self->{coords});
}


sub connection {
    my $self = shift;
    return $self->{connection};
}


sub constraints {
    my $self = shift;
    return $self->{constraints};
}


sub set_constraints {
    my ($self, $constraints) = @_;
    $self->{constraints} = $constraints;
}


sub freeze_atoms {
    my ($self, $atoms) = @_;
    for my $atom (@$atoms) {$self->{flags}->[$atom] = -1;};
}


sub copy {
    my $self = shift;
    my $new =  new AaronTools::Geometry( name => $self->{name},
                                         elements => [ @{ $self->{elements} } ],
                                         flags => [ @{ $self->{flags} }],
                                         coords => [ map { [ @$_ ] } @{ $self->{coords} } ],
                                         connection => [ map { [ @$_ ] } @{ $self->{connection} } ],
                                         constraints => [ map { [ @$_ ] } @{ $self->{constraints} } ] );
};


sub update_coords {
    my $self = shift;
    my %param = @_;

    for my $i (0..$#{ $param{targets} }) {
        $self->{coords}->[$param{targets}->[$i]] = $param{coords}->[$i];
    }
}


sub conformer_geometry {
    my $self = shift;
    my ($geo) = @_;

    unless (@{ $self->{coords} } == @{ $geo->{coords} }) {
        warn("number of atoms are not equal");
    }

    $self->update_coords( targets => [0..$#{$self->{coords}}],
                          coords => $geo->{coords} );
    $self->refresh_connected();
}


sub append {
    my ($self, $geo_2) = @_;
    my $num_self = $#{ $self->{elements} } + 1;

    $self->{elements} = [@{ $self->{elements} }, @{ $geo_2->{elements} }];
    $self->{coords} = [@{ $self->{coords} }, @{ $geo_2->{coords} }];
    $self->{flags} = [@{ $self->{flags} }, @{ $geo_2->{flags} }];

    my @connection_2_new = map{ [map {$_ + $num_self} @$_] }  @{ $geo_2->{connection} };
    $self->{connection} = [@{ $self->{connection} }, @connection_2_new];
}


sub subgeo {
    my ($self, $groups) = @_;
    $groups //= [0..$#{ $self->{elements} }];

    my @elements;
    my @flags;
    my @coords;
    my @connection;

    for my $atom (@$groups) {
        push (@elements, $self->{elements}->[$atom]);
        push (@flags, $self->{flags}->[$atom]);
        push (@coords, $self->{coords}->[$atom]);
    }
    my $subgeo = new AaronTools::Geometry( name => $self->{name},
                                           elements => [@elements],
                                           flags => [@flags],
                                           coords => [@coords]);

    return $subgeo;
}


sub splice_atom {
    my ($self, $target, $number_splice, $geo_2) = @_;

    for my $entry ('elements', 'flags', 'coords', 'connection') {
        if ($geo_2) {
            splice(@{ $self->{$entry} }, $target, $number_splice, @{ $geo_2->{$entry} });
        }else {
            splice(@{ $self->{$entry} }, $target, $number_splice);
        }
    };
}


sub delete_atom {
    my ($self, $groups) = @_;
    $groups //= [];

    for my $atom (sort { $b <=> $a } @$groups) {
        $self->splice_atom($atom, 1);
    }
}


sub separate {
    my $self = shift;

    my @atoms = (0..$#{ $self->{elements} });

    my @molecules;
    while(@atoms) {
        my $start = $atoms[0];
        my @molecule = @{ $self->get_all_connected($start) };

        my %atoms = map { $_ => 1 } @atoms;
        map {delete $atoms{$_} } @molecule;
        @atoms = keys %atoms;
        push (@molecules, \@molecule);
    }
    return \@molecules;
}


#Cuts $atom1-$atom2 bond and removes $atom2 and all connected atoms
#replaces with hydrogen along original $atom1-$atom2 bond.
#remove_fragment(\@coords, $atom1, $atom2);
sub remove_fragment {
	# atom1 = where fragment connected
	# atom2 = start of fragment (replaced with H)
    my ($self, $atom1, $atom2) = @_;

	# determine atoms in continuous fragment extending from atom2 and avoiding atom1
    my $fragment = $self->get_all_connected($atom2, $atom1);
	# save a list of all atoms, excluding atom2
    my @fragment_no_atom2 = grep { $_ != $atom2 } @$fragment;
	# change atom2 to H
    $self->{elements}->[$atom2] = 'H';
	# adjust bond length
    $self->correct_bond_length( atom1 => $atom1, atom2 => $atom2 );
	# delete all other atoms in fragment
    $self->delete_atom([@fragment_no_atom2]);
	# update connection info
    $self->get_connected();
}


sub clean_structure {
    my ($self) = @_;
    my @phantom;
    for my $i (0..$#{ $self->{elements} }) {
        if ($self->{elements}->[$i] eq 'X') {
            push (@phantom, $i);
        }
    }
    $self->delete_atom([@phantom]);
    $self->refresh_connected();
}


#makes a copy of a @coords array, mirroring x-values.  Returns new @coords array
#mirror_coords($ref_to_coords);
sub mirror_coords {
    my ($self, $axis) = @_;

    $axis //= '';

    SWITCH: {
        if ($axis =~ /[yY]/) {
            foreach my $atom (0..$#{ $self->{elements} }) {
                $self->{coords}->[$atom]->[1] *= -1;
            }
            last SWITCH;
        }
        if ($axis =~ /[zZ]/) {
            foreach my $atom (0..$#{ $self->{elements} }) {
                $self->{coords}->[$atom]->[2] *= -1;
            }
            last SWITCH;
        }
        foreach my $atom (0..$#{ $self->{elements} }) {
            $self->{coords}->[$atom]->[0] *= -1;
        }
    }
}


sub read_geometry {
    my $self = shift;
    my ($file) = @_;
    my ($elements, $flags, $coords, $constraints) = AaronTools::FileReader::grab_coords($file);

    $self->{elements} = $elements;
    $self->{flags} = $flags;
    $self->{coords} = $coords;

    if ($constraints) {
        my @constraints;
        for my $constraint (@$constraints) {
            my $d = $self->distance( atom1 => $constraint->[0],
                                     atom2 => $constraint->[1] );
            push(@constraints, [$constraint, $d]);
            $self->{constraints} = [@constraints];
        }
    }

    $self->refresh_connected();
    return 1;
}


#get connected for subgroups atoms. If subgroups are not provided,
#get connected for all atoms,
#The subgroups are used when make substituents.
sub get_connected {
  my ($self, $subgroups) = @_;
  $subgroups //= [0..$#{ $self->{elements} }];

  my $tolerance = 0.2;

  my $connected = [];
  foreach my $atom1 (@$subgroups) {
    my @row;
    foreach my $atom2 (@$subgroups) {
      my $distance = $self->distance(atom1 => $atom1, atom2 => $atom2);

      my $cutoff = $radii->{$self->{elements}->[$atom1]} +
                   $radii->{$self->{elements}->[$atom2]} +
                   $tolerance;
      if($distance < $cutoff && $atom1 != $atom2) {
        push(@row, $atom2);
      }
    }
    $self->{connection}->[$atom1] = union($self->{connection}->[$atom1], [@row]);
  }
}


sub refresh_connected {
  my $self = shift;
  my $subgroups = [0..$#{ $self->{coords} }];

  my $tolerance = 0.2;

  my @connected = ();
  foreach my $atom1 (@$subgroups) {
    my @row = ();
    foreach my $atom2 (@$subgroups) {
      my $distance = $self->distance(atom1 => $atom1, atom2 => $atom2);

      my $cutoff = $radii->{$self->{elements}->[$atom1]} +
                   $radii->{$self->{elements}->[$atom2]} +
                   $tolerance;
      if($distance < $cutoff && $atom1 != $atom2) {
        push(@row, $atom2);
      }
    }
	push @connected, [@row];
  }
  $self->{connection} = [@connected];
}


sub get_all_connected {
    #rewrite, but with recursion (see buttercup)
    #this doesn't work sometimes and I don't know why
    my ($self, $start_atom, $avoid_atom) = @_;
    my @connected = @{$self->{connection}};
    my @connected_temp = map { [@$_] } @connected;
    #remove avoid_atom from list of atoms connected to $start_atom
    if (defined $avoid_atom) {
        foreach my $atom (0..$#{$connected_temp[$start_atom]}) {
            if($connected_temp[$start_atom][$atom] == $avoid_atom) {
            $connected_temp[$start_atom][$atom] = -1;
            }
        }
    }

    my @positions = ($start_atom);
    #I can probably use something simpler than a hash here (since I'm not really using the values)
    my %visited = ( $start_atom => '0') ;	#keys are numbers of the visited atoms, values are not used

    #loop until @positions is empty
    while(@positions) {
      my $position = shift(@positions);
      foreach my $atom (@{$connected_temp[$position]}) { 	#grab all atoms connected to current atom and add to queue (unless already visited)
        if($atom >= 0 && !exists $visited{$atom}){
          push(@positions, $atom);
          $visited{$atom} = 0;
        }
      }
    }

    my @all_connected_atoms = keys %visited;
    #Check all_connected_atoms for avoid_atom
    if (defined $avoid_atom) {
        foreach (@all_connected_atoms) {
            if($_ == $avoid_atom) {
                return ();
            }
        }
    }
    #change the start_atom in the @all_connected_atoms to the first element
    if ($all_connected_atoms[1]) {
        @all_connected_atoms = grep {$_ != $start_atom} @all_connected_atoms;
        @all_connected_atoms = sort {$a <=> $b} @all_connected_atoms;
        unshift @all_connected_atoms, $start_atom;
    }
    return [@all_connected_atoms];
} #End sub get_all_connected


sub check_connectivity {
    my ($self) = @_;

    my @wrong_connectivity;

    for my $atom (0..$#{ $self->{elements} }) {
        if ($#{ $self->{connection}->[$atom] } + 1 >
            $CONNECTIVITY->{$self->{elements}->[$atom]}) {
            push(@wrong_connectivity, $atom);
         }
    }
    return [@wrong_connectivity];
}

#THIS is to check if the connectivity of the structure changed
sub examine_connectivity {
    my ($self) = shift;

    my %params = @_;

    my ($file, $thres) = ($params{file}, $params{thres});

    $self->refresh_connected();

    my $geo_ref = new AaronTools::Geometry();
    $geo_ref->read_geometry($file);

    my ($broken, $formed) = $self->compare_connectivity(geo_ref=>$geo_ref, thres=>$thres);

    $broken = [map {[split('-', $_)]} keys %{$broken}];
    $formed = [map {[split('-', $_)]} keys %{$formed}];

    return ($broken, $formed);
}

sub compare_connectivity {
    my ($self) = shift;

    my %params = @_;

    my ($geo_ref, $thres) = ($params{geo_ref}, $params{thres});

    if ($#{ $self->{connection} } != $#{ $geo_ref->{connection} }) {
        warn "Number of atoms are not equal for $self->{name}";
    }

    my %broken;
    my %formed;

    for my $atom (0..$#{$self->{connection}}) {
        if ($self->{elements}->[$atom] ne $geo_ref->{elements}->[$atom]) {
            my $atom_warn = $atom + 1;
            warn "Atom $atom_warn are not same element in two structures";
         }

         my %con1 = map {$_ => 1} @{ $self->{connection}->[$atom] };
         my %con2 = map {$_ => 1} @{ $geo_ref->{connection}->[$atom] };

         my @broken_atoms = grep { !$con1{$_} &&
            (abs($self->distance(atom1=>$atom, atom2=>$_) -
                $geo_ref->distance(atom1=>$atom, atom2=>$_)) > $thres) } keys %con2;
         my @formed_atoms = grep { !$con2{$_} &&
            (abs($self->distance(atom1=>$atom, atom2=>$_) -
                $geo_ref->distance(atom1=>$atom, atom2=>$_)) > $thres)} keys %con1;

         my @broken_bonds = map { join('-', sort($atom, $_)) } @broken_atoms;
         my @formed_bonds = map { join('-', sort($atom, $_)) } @formed_atoms;

         @broken{@broken_bonds} = ();
         @formed{@formed_bonds} = ();
     }
     return(\%broken, \%formed);
}

#put in the start and end atom, return what a substituent object.
#if the substituent is built-in, information about conformation will be
#included. Otherwise, only geometries.
sub detect_substituent {
    my $self = shift;
    my %params = @_;

    my ($target, $end) = ($params{target}, $params{end});
    my $sub_atoms = $self->get_all_connected($target, $end);

    my $substituent = $self->subgeo($sub_atoms);
    $substituent->refresh_connected();

    bless $substituent, "AaronTools::Substituent";

    $substituent->compare_lib();
    $substituent->{end} = $end;
    return $substituent;
}


sub examine_constraints {
    my $self = shift;

    my @failed;
    for my $con (@{ $self->{constraints} }) {
        unless ($con->[1]) {
            push (@failed, 0);
            next;
        }

        my $bond = $con->[0];
        my $d_con = $con->[1];

        my $d = $self->distance( atom1 => $bond->[0],
                                 atom2 => $bond->[1] );
        if ($d - $d_con > $CUTOFF->{D_CUTOFF}) {
            push (@failed, -1);
            last;
        }elsif ($d_con - $d > $CUTOFF->{D_CUTOFF}) {
            push (@failed, 1);
            last;
        }
    }

    return @failed;
}


sub distance {
    my $self = shift;
    my %param = @_;
    my ($atom1, $atom2, $geometry_2) = ( $param{atom1},
                                         $param{atom2},
                                         $param{geometry2} );

    my $bond = $self->get_bond($atom1, $atom2, $geometry_2);
    my $distance = abs($bond);
    return $distance;
}


sub change_distance {
    my $self = shift;
    my %params = @_;

    my ($atom1, $atom2, $distance,
        $by_distance,
        $move_atom2, $move_frag) = ( $params{atom1},
                                     $params{atom2},
                                     $params{distance},
                                     $params{by_distance},
                                     $params{fix_atom1},
                                     $params{translate_group} );

    $move_atom2 //= 0;
    $move_frag //= 1;

    my ($all_connected_atoms1, $all_connected_atoms2);
    if ($move_frag) {
        $all_connected_atoms2 = $self->get_all_connected($atom2, $atom1);
        if ($move_atom2) {
            $all_connected_atoms1 = $self->get_all_connected($atom1, $atom2);
        }
    }else {
        $all_connected_atoms2 = [$atom2];
        if ($move_atom2) {
            $all_connected_atoms1 = [$atom1];
        }
    }

    $self->_change_distance( all_atoms1 => $all_connected_atoms1,
                             all_atoms2 => $all_connected_atoms2,
                             atom1 => $atom1,
                             atom2 => $atom2,
                             distance => $distance,
                             by_distance => $by_distance );
}


sub _change_distance {
    my $self = shift;
    my %params = @_;

    my ($all_atoms1, $all_atoms2,
        $atom1, $atom2, $distance,
        $by_distance) = ($params{all_atoms1}, $params{all_atoms2},
                         $params{atom1}, $params{atom2}, $params{distance},
                         $params{by_distance});

    my $current_distance = $self->distance(atom1 => $atom1, atom2 => $atom2);
    my $difference;
    if ($distance) {
        $difference = $distance - $current_distance;
    }elsif($by_distance) {
        $difference = $by_distance;
    }

    my $v12 = $self->get_bond($atom2, $atom1);

    my ($v1, $v2);
    unless($all_atoms1) {
        unless( $current_distance ) {
            warn "distance between atoms $atom1 and $atom2 is 0\n";
            $current_distance = 1;
        }
        $v2 = $v12 * $difference / $current_distance;
        $v1 = V(0, 0, 0);
    }else {
        $v2 = $v12 * $difference / (2*$current_distance);
        $v1 = -$v12 * $difference / (2*$current_distance);
    }

    $self->coord_shift($v1, $all_atoms1) if $all_atoms1;
    $self->coord_shift($v2, $all_atoms2) if $all_atoms2;
}


sub correct_bond_length {
    my $self = shift;
    my %params = @_;
    my ($atom1, $atom2) = ($params{atom1}, $params{atom2});
    my $new_distance = $radii->{$self->{elements}->[$atom1]}
                       + $radii->{$self->{elements}->[$atom2]};

    $self->change_distance( atom1 => $atom1,
                            atom2 => $atom2,
                            distance => $new_distance,
                            fix_atom1 => 1,
                            translate_group => 1 );
}


sub coord_shift {
    my ($self, $v, $targets) = @_;
    $targets //= [0..$#{ $self->{coords} }];

    foreach my $atom (@$targets) {
        my $new = $self->{coords}->[$atom] + $v;
        #This is to maintain the array ref
        for my $i (0..$#{ $new }) {$self->{coords}->[$atom]->[$i] = $new->[$i]};
    }
}


sub quat_rot {
    my ($self, $a, $w, $targets) = @_;

    $targets //= [ 0..$#{ $self->{elements} }];

    for my $atom (@$targets) {
        my $vec = $self->get_point($atom);
        my $wx = $w x $vec;
        my $new_vec = $vec + 2*$a*$wx + 2*($w x $wx);
        #This is to maintain the array ref
        for my $i (0..$#{ $new_vec }) {$self->{coords}->[$atom]->[$i] = $new_vec->[$i]};
    }
}


sub genrotate {
    my ($self, $v, $angle, $targets) = @_;

    my $a = cos($angle/2);
    unless( $v->norm() ) {
        warn "vector $v has 0 length in genrotate, using y-vec instead\n";
        $v = V(0,1,0);
    };
    $v /= $v->norm();
    $v *= sin($angle/2);

    $self->quat_rot($a, $v, $targets);
}


sub rotate {
    my ($self, $axis, $angle) = @_;
    Switch:{
        if ($axis =~ /[Xx]/) {
            $self->genrotate(V(1,0,0), $angle);
            last Switch;
        }
        if ($axis =~ /[Yy]/) {
            $self->genrotate(V(0,1,0), $angle);
            last Switch;
        }
        if ($axis =~ /[Zz]/) {
            $self->genrotate(V(0,0,1), $angle);
            last Switch;
        }
        die "Can only rotate around Cartesian axes (x, y, or z)!\n";
    }
}


sub center_genrotate {
    my ($self, $point, $v, $angle, $targets) = @_;

    my $shift_v = $point =~ /^\d+$/ ?
                  $self->get_point($point) : $point;

    $self->coord_shift($shift_v*-1, $targets);
    $self->genrotate($v, $angle, $targets);
    $self->coord_shift($shift_v, $targets);
}


sub angle {
    my ($self, $atom1, $atom2, $atom3) = @_;

    my $bond1 = $self->get_bond($atom1, $atom2);
    my $bond2 = $self->get_bond($atom3, $atom2);

    my $angle = atan2($bond1, $bond2);

    return $angle;
}


sub dihedral {
    my($self, $atom1, $atom2, $atom3, $atom4) = @_;

    my $bond12 = $self->get_bond($atom1, $atom2);
    my $bond23 = $self->get_bond($atom2, $atom3);
    my $bond34 = $self->get_bond($atom3, $atom4);

    my $dihedral = atan2((($bond12 x $bond23) x ($bond23 x $bond34)) * $bond23 /
                          abs($bond23), ($bond12 x $bond23) * ($bond23 x $bond34));

    return rad2deg($dihedral);
}


#changes dihedral about bond atom1-atom2 by an angle angle_change (in radians!)
#change_dihedral(atom1, atom2, angle_change, ref_to_coords
sub change_dihedral {
    my ($self, $atom1, $atom2, $angle) = @_;

    my $connected_atoms = $self->get_all_connected($atom1, $atom2);

    if ($#{ $connected_atoms } < 0) {
        print {*STDERR} "Cannot change this dihedral angle...\n";
        return 0;
    }

    my $bond = $self->get_bond($atom2, $atom1);

    $self->center_genrotate($atom1, $bond, $angle, $connected_atoms);
}


sub set_dihedral {
    my ($self, $atom1, $atom2, $atom3, $atom4, $new_tau) = @_;

    my $tau = $self->dihedral($atom1, $atom2, $atom3, $atom4);
    $self->change_dihedral($atom2, $atom3, deg2rad($new_tau - $tau));
}


#centers molecule so that average of atom1, atom2, and atom3 is at origin, and orients molecule so that atom1 is on x-axis and atom2 and atom3 are as close as possible to XY-plane
#center_ring($atom1, $atom2, $atom3, $ref_to_coords);
sub center_ring {
    my ($self, $atom1, $atom2, $atom3) = @_;

    my $com = V(0, 0, 0);
    for my $atom ($atom1, $atom2, $atom3) {
        $com += $self->get_point($atom);
    }
    $com /= 3;

    #shift geom to COM
    $self->coord_shift(-1*$com);

    #Put atom1 along x-axis
    my $v1 = $self->get_point($atom1);
    my $vx = V(1,0,0);
    my $cross1 = $v1 x $vx;
    my $angle1 = atan2($v1, $vx);
    $self->genrotate($cross1, -$angle1);

    #Now put atom2 and atom3 in XY-plane (or as close as possible)
    my ($v2, $v3) = ($self->get_point($atom2), $self->get_poing($atom3));
    $v2->[0] = 0;
    $v3->[0] = 0;
    my $vz = V(0,0,1);
    my $cross2 = $v2 x $vz;
    my $cross3 = $v3 x $vz;
    my $angle2;
    if($v2->norm() != 0) {
      $angle2 = asin($cross2->norm()/$v2->norm());
    } else {
      $angle2 = pi()/2;
    }
    my $angle3;
    if($v3->norm() != 0) {
      $angle3 = asin($cross3->norm()/$v3->norm());
    } else {
      $angle3 = pi()/2;
    }
    my $av_angle = pi()/2 - ($angle2*2)/2;

    $self->genrotate(V(1, 0, 0), -$av_angle);
}


#rotate substitute
#sub_rotate(target,angle,\@coords)
sub sub_rotate{
   my ($self, $target, $angle) = @_;

   my ($atom2, $targets) = $self->get_sub($target);
   my $axis = $self->get_bond($target, $atom2);
   $self->center_genrotate($target, $axis, $angle, $targets);
} #End sub sub_rotate


sub get_point {
    my ($self, $atom) = @_;
    my $vector = V(@{ $self->{coords}->[$atom] });
    return $vector;
}

#This is to find the substituent for a given atom
sub get_sub{
    my ($self, $target) = @_;

    my @nearst = @{$self->{connection}->[$target]};
    #now we need to define which nearst atom is the target.
    my $min = 999;
    my $atom2;
    my $targets;
    for (@nearst) {
        my $get_all = $self->get_all_connected($target, $_);
        if ($get_all && $#{ $get_all } < $min) {
          $min = $#{ $get_all };
          $atom2 = $_;
          $targets = $get_all;
        }
    }
    return($atom2, $targets);
}


#Replaces atom $target with substituent $sub (name of XYZ file)
#Returns coords in same orientation as given, with atom ordering preserved
#&substitute($target, $sub, \@coords, $no_min);
#TO DO: after adding substituent, rotation added atoms around new bond to maxmimize distance to all other atoms!
sub substitute {
    my $self = shift;
    my %param = @_;

    my ($target, $sub, $minimize_torsion) = ( $param{target},
                                              $param{sub},
                                              $param{minimize_torsion} );

    my ($end, $old_sub_atoms) = $self->get_sub($target);

    my $sub_object = AaronTools::Substituent->new( name => $sub, end => $end );

    $self->_substitute( old_sub_atoms => $old_sub_atoms,
                                  sub => $sub_object,
                                  end => $end,
                     minimize_torsion => $minimize_torsion );


} #End sub substitute


#This is to substitute the atoms directly by providing a set of atoms number
#The constraint and to_sub will be modiyed.
#Don't call this unless you new what you are doing.
#For general users use the substitute instead by providing target and sub name.
sub _substitute {
    my $self = shift;
    my %params = @_;

    my ($old_sub_atoms, $sub, $end, $minimize_torsion) = ( $params{old_sub_atoms},
                                                           $params{sub},
                                                           $params{end},
                                                           $params{minimize_torsion} );
    my $target = $old_sub_atoms->[0];

    $sub->_align_on_geometry( geo => $self,
                           target => $target,
                              end => $end );

    #replace target with first atom of substituent
    $self->splice_atom($target, 1, $sub->subgeo([0])->copy());

    #if any element remaining in the @targets, remove them
    my $delete_atoms=[];
    for my $i(1..$#{ $old_sub_atoms }) {$delete_atoms->[$i-1] = $old_sub_atoms->[$i]};
    $target -= grep { $_ < $target } @$delete_atoms;
    $end -= grep { $_ < $end } @$delete_atoms;

    #modify the constraint, since the deleted atoms can change atom numbers
    $self->_rearrange_con_sub($delete_atoms);

    $self->delete_atom($delete_atoms);
    $self->refresh_connected();

    #build list of substituent coords
    my $old_num_atoms = $#{ $self->{elements} } + 1;
    $self->append($sub->subgeo([1..$#{ $sub->{elements} }])->copy());

    #modify the distance between end and target
    $self->get_connected([$target, ($old_num_atoms..$#{ $self->{elements} })]);
    $self->correct_bond_length( atom1 => $end, atom2 => $target );

    #keep track of new bonds
    my @new_bond = ($end, $target);
    if( $self->{rotatable_bonds} ) {
        for my $b (0..$#{$self->{rotatable_bonds}}) {
            for my $i (0..1) { #go through each atom in the bond and correct the numbering
                               #if any of the deleted atoms are between 0 and this atom,
                               #we'll need to correct the position of this atom
                for my $atom (@$delete_atoms) {
                    if( $self->{rotatable_bonds}->[$b]->[$i] > $atom ) {
                        $self->{rotatable_bonds}->[$b]->[$i] -= 1;
                    }
                }
            }
        }
    }
    push @{$self->{rotatable_bonds}}, \@new_bond;
    push @{$self->{conformers}}, @{$sub->{conformers}};
    push @{$self->{rotations}}, @{$sub->{rotations}};
    if( $sub->{rotatable_bonds} ) { #add the rotatable bonds that are already on the substituent
        for my $bond (@{$sub->{rotatable_bonds}}) { #we'll need to update the numbers of these atoms
            my @fixed_bond = @$bond;
            for my $i (0..1) {
                if( $fixed_bond[$i] != 0 ) { #if it's not the first atom, add the number of atoms in the molecule that don't belong to the substituent
                    $fixed_bond[$i] += $#{$self->{elements}} - $#{$sub->{elements}};
                } else {
                    $fixed_bond[$i] += $target;
                }
            }
            push @{$self->{rotatable_bonds}}, \@fixed_bond;
        }
    }

    if ($minimize_torsion) {
        $self->minimize_torsion(start_atom => $target,
                                  end_atom => $end);
    }

}


sub _rearrange_con_sub {
    my ($self, $delete_atoms) = @_;
    for my $constraint (@{$self->{constraints}}) {
        for my $i (0,1) {
            my $removed = grep { $_ < $constraint->[0]->[$i] } @$delete_atoms;
            $constraint->[0]->[$i] -= $removed;
        }
    }
}


sub fused_ring {
  my ($self, $target1, $target2, $type) = @_;

  #get connected atoms
  my @connected = @{ $self->{connection} };
  if($#{$self->{connection}->[$target1]} > 0
     || $#{$self->{connection}->[$target2]} > 0) {
    print {*STDERR} "Trying to substitute non-monovalent atom!\n";
    return 0;
  }

  #Figure out what needs to be added to match fused ring
  my $path_length = $self->shortest_path($target1, $target2);
  if($path_length < 3 || $path_length > 5) {
    print {*STDERR} "Can't figure out how to build fused ring connecting those two atoms...\n";
    return 0;
  }
  #check to make sure known type
  if($type !~ /a_pinene/ && $type !~ /LD_chair/ && $type !~ /LU_chair/
     && $type !~ /D_boat/ && $type !~ /U_boat/ && $type !~ /Ar/) {
    print {*STDERR} "Unknown ring type!\n";
    return 0;
  }

  my $ring;

  if ($type =~ /Ar/) {
    $ring = new AaronTools::Geometry( name => 'Ar_ring' );
    $ring->read_geometry("$QCHASM/AaronTools/Ring_fragments/six_$path_length.xyz");
  }
  else {	#Chairs
    if($path_length != 3) {
      print {*STDERR} "Can't figure out how to build fused ring connecting those two atoms...\n";
      return 0;
    } else {
      $ring = new AaronTools::Geometry( name => 'Chairs' );
      $ring->read_geometry("$QCHASM/AaronTools/Ring_fragments/Chairs/$type.xyz");
    }
  }

  #get nearest neighbors from @connected
  my $nearest_neighbor1 = $self->{connection}->[$target1]->[0];
  my $nearest_neighbor2 = $self->{connection}->[$target2]->[0];

  #shift coords so that nearest_neighbor1 is at the origin
  my $origin = $self->get_point($nearest_neighbor1);
  $self->coord_shift(-1*$origin);

  #Orient so that nearest_neighbor2 is along x-axis
  my $v1 = $self->get_point($nearest_neighbor1);
  my $v2 = $self->get_point($nearest_neighbor2);

  my $vx = V(1,0,0);
  my $vz = V(0,0,1);
  my $cross1 = $v2 x $vx;
  my $angle1 = atan2($v2, $vx);
   #accounts for sign of dot product to get sign of angle right!
  $self->genrotate($cross1, $angle1) unless (abs($cross1) == 0);

  #final rotation around x-axis to bring $target1 and $target2 into XY-plane
  $v1 = $self->get_point($target1);
  $v2 = $self->get_point($target2);
  my $chi1 = atan2($v1->[2], $v1->[1]);
  my $chi2 = atan2($v2->[2], $v2->[1]);
  my $chi = ($chi1 + $chi2)/2;
  $self->rotate('x',-$chi);

  my @sub_atoms = ($target1, $target2);
  my $coord_num_old = $#{ $self->{elements} };

  #replace target1 with 1st ring atom
  #replace target2 with 2nd ring atom
  #Add remainder of ring coords
  my $ring1 = $ring->subgeo([0])->copy();
  my $ring2 = $ring->subgeo([1])->copy();
  my $ring_remain = $ring->subgeo([2..$#{ $ring->{elements} }])->copy();
  $self->splice_atom($target1, 1, $ring1);
  $self->splice_atom($target2, 1, $ring2);
  $self->append($ring_remain->copy());
  push(@sub_atoms, $coord_num_old+1..$#{ $self->{elements} });

  #Return geometry to original orientation/position
  $self->rotate('x',$chi);
  $self->genrotate($cross1, -$angle1) unless (abs($cross1) == 0);
  $self->coord_shift($origin);

  return [@sub_atoms];
} #End sub fused_ring

#calculates  LJ-6-12 potential energy based on autodock Rij and Eij parameters
#simply ignores any atom pair involving elements for which parameters are missing (which shouldn't be anything!).
sub LJ_energy {
  my ($self) = @_;

  my $energy = 0;

  foreach my $atom1 (0..$#{ $self->{coords} }) {
    foreach my $atom2 ($atom1+1..$#{ $self->{coords} }) {
      my $string = $self->{elements}->[$atom1] . $self->{elements}->[$atom2];
      if((my $sigma = $rij->{$string}) && (my $epsilon = $eij->{$string})) {
        my $R = $self->distance(atom1 => $atom1, atom2 => $atom2);
        $energy += $epsilon*(($sigma/$R)**12 - ($sigma/$R)**6);
      }
    }
  }
  return $energy;
}


#calculates  LJ-6-12 potential energy based on autodock Rij and Eij parameters
#simply ignores any atom pair involving elements for which parameters are missing (which shouldn't be anything!).
sub LJ_energy_with {
  my ($self, $geo2) = @_;

  my $energy = 0;

  foreach my $atom1 (0..$#{ $self->{coords} }) {
    foreach my $atom2 (0..$#{ $geo2->{coords} }) {
      my $string = $self->{elements}->[$atom1] . $geo2->{elements}->[$atom2];
      if((my $sigma = $rij->{$string}) && (my $epsilon = $eij->{$string})) {
        my $R = $self->distance(atom1 => $atom1, atom2 => $atom2, geometry2 => $geo2);
        $energy += $epsilon*(($sigma/$R)**12 - ($sigma/$R)**6);
      }
    }
  }
  return $energy;
}


#finds minimum energy structure (based on LJ potential) by rotating list of target atoms around bond between $atom1 and $atom2
#TODO: if no list of @targets provided, rotate fragment that starts with atom1!
sub minimize_torsion {
    my $self = shift;
    my %param = @_;
    my ($atom1, $atom2) = ( $param{start_atom}, $param{end_atom} );

    #get all atoms on this part of the molecule
    my $targets = $self->get_all_connected($atom1, $atom2);

    my $increment = 5; #angle increment to search over

    #make a list of rotatable bonds
    my @bonds = [($atom2, $atom1)];
    if( $self->{rotatable_bonds} ) {
        for my $bond ( @{$self->{rotatable_bonds}} ) {
            #avoid doubling up on the requested bond
            if( $bond->[0] != $bonds[0]->[0] and $bond->[1] != $bonds[0]->[1] ) {
                push @bonds, $bond;
            }
        }
    }

    for my $bond (@bonds) {
        my $a1 = $bond->[0];
        my $a2 = $bond->[1];
        #if an atom in this bond is on this part of the molecule, then we'll try to
        #optimize that bond's torsional angle
        if( grep( /^$a2$/, @{$targets} ) ) {
            #get all atoms that are on one end of this bond
            my $fragment = $self->get_all_connected($a2, $a1);
            if( $fragment ) { #there might be nothing e.g. if substitute is used to put on a F -
                              #it still puts a rotatable_bond for it, but there's no fragment
                              #attached to the F
                my $E_min =$self->LJ_energy();
                my $angle_min = 0; #we'll be storing the best angle
                my $point = $self->get_point($a2);
                my $axis = $self->get_bond($a2, $a1);

                foreach my $count (1..360/$increment) {
                    my $angle = $count*$increment;
                    $self->center_genrotate($point, $axis, deg2rad($increment), $fragment);
                    my $energy = $self->LJ_energy();
                    if( $energy < $E_min ) {
                        $angle_min = $angle;
                        $E_min = $energy;
                    }
                }
                #apply the best rotation
                $self->center_genrotate($point, $axis, deg2rad($angle_min), $fragment);
            }
        }
    }
}


sub get_bond {
    my ($self, $atom1, $atom2, $geometry_2) = @_;
    $geometry_2 //= $self;

    my $pt1 = $self->get_point($atom1);
    my $pt2 = $geometry_2->get_point($atom2);

    my $bond = $pt1 - $pt2;
    return $bond;
}

sub get_fragment{
	my $self = shift;
	my $start = shift;
	my $avoid = shift;
	my $targets = shift;

	$targets //= [0..$#{$self->{elements}}];
	my @connections = @{ $self->{connection} };

	my @frag = ($start);
	my @stack = @{ $connections[$start] };
	@stack = grep { $_ != $avoid } @stack;

	while (@stack > 0){
		my $current = shift @stack;
		unless ( grep { $_ == $current } @$targets ){
			next;
		}
		my @conn = @{ $connections[$current] };
		@conn = grep { $_ != $avoid } @conn;
		for my $f (@frag){
			@conn = grep { $_ != $f } @conn;
		}
		push @stack, @conn;
		push @frag, $current;
	}

	return @frag;
}

#replaces TM center with another metal
sub change_metal {
    my $self      = shift;
    my $new_metal = shift;
	my $metal_index = shift;

    my ($old_metal, $old_radii, $new_radii);
	my $coordinated;
	my $coords = [];
	my @fragments = ();

	$metal_index //= -1;

    # error checking
    unless ( grep { $new_metal eq $_ } keys %$TMETAL ) {
        die "Replacement transition metal provided unrecognized; " .
          "failure to change metal center\n";
    }

	for (my $i=0; $i < @{$self->{elements}}; $i++){
		my $a = $self->{elements}->[$i];
		if ( grep { $a eq $_ } keys %$TMETAL ){
			$metal_index = $i;
			last;
		}
	}
    if ($metal_index < 0) {
        die "Original transition metal center unrecognized; " .
          "failure to change metal center\n";
    }

	# save old and new properties
    $old_metal = $self->{elements}->[$metal_index];
	$old_radii = $TMETAL->{$old_metal};
	$new_radii = $TMETAL->{$new_metal};

	# save connected atoms
	$coordinated = $self->{connection}->[$metal_index];

	# get fragments
	my $left_over = [0..$#{$self->{elements}}];
	@$left_over = grep { $_!= $metal_index } @$left_over;
	for my $a (@$coordinated){
		unless ( grep { $a == $_ } @$left_over ){
			next;
		}
		my @frag = $self->get_fragment($a, $metal_index, $left_over);
		for my $f (@frag){
			@$left_over = grep { $_ != $f } @$left_over;
		}

		push @fragments, \@frag;
	}
	push @fragments, $left_over;

	$coords = $self->{coords};
	for my $frag (@fragments){
		# determine shift vectors for fragments
		my $shift = V(0,0,0);
		for my $f (@$frag){
			$shift += $coords->[$f];
		}
		$shift /= @$frag;
		$shift = $coords->[$metal_index] - $shift;
		$shift -= $shift*($new_radii/$old_radii);

		# fix coords
		for my $f (@$frag){
			$coords->[$f] += $shift;
		}
	}


	# save coord changes
	$self->{coords} = $coords;
	# change atom element
	$self->{elements}->[$metal_index] = $new_metal;
}


###################
#RMSD related part#
###################
sub _sort_conn {
    # sorts connectivity array based on the maximum connectivity of the atoms
    # eg: NCH => CNH
    my ( $geom, $index ) = @_;

    my @indicies = @{ $geom->{connection}->[$index] };
    @indicies = sort { $CONNECTIVITY->{ $geom->{elements}->[$b] } <=> $CONNECTIVITY->{ $geom->{elements}->[$a] }
                     } @indicies;

    return \@indicies;
}

sub _get_order {
    # generates an atom order based on connectivity
    my ( $geom, $atoms, $start ) = @_;

    # order starts with $start
    my @order = ($start);
    # add atoms connected to $start to the stack, sorted
    my @stack = _sort_conn( $geom, $start );

	my @atoms_left = @$atoms;
    while ( @stack > 0 ) {
        # get a connectivity array from the front of the stack
        my $conn = shift @stack;

        # if those atoms aren't already in @order, add them
        for my $o (@order) {
            @$conn = grep { $_ != $o } @$conn;
        }
        push @order, @$conn;

        # push the connectivity arrays of connected atoms to back of stack
        for my $c (@$conn) {
            push @stack, _sort_conn( $geom, $c );
        }

		# if the stack is empty, push a remaining atom onto the stack
		for my $o ( @order ) {
			@atoms_left = grep { $_ != $o } @atoms_left;
		}
		if ( @stack < 1 && @atoms_left > 0 ){
			push( @stack, [shift( @atoms_left )] );
		}
    }
    return \@order;
}

sub _reorder {
    # generate connectivity-based order for each possible starting atom
    my $geom  = shift;
    my $atoms = shift;
    $atoms //= [ 0 .. $#{ $geom->elements() } ];

    my @orders;
    push @orders, $atoms;
    for my $r (@$atoms) {
		# start atoms can only be heavy atoms
        if ( ${$geom->{elements}}[$r] eq 'H' ) { next; }
        push @orders, _get_order( $geom, $atoms, $r );
    }
    return @orders;
}

sub RMSD_reorder {
    my $self   = shift;
    my %params = @_;

    my ( $geo2, $heavy_only, $atoms1_ref, $atoms2_ref ) = ($params{ref_geo},
                                                           $params{heavy_atoms},
                                                           $params{ref_atoms1},
                                                           $params{ref_atoms2});
    $heavy_only //= 0;
    $atoms1_ref //= [ 0 .. $#{ $self->{elements} } ];
    $atoms2_ref //= [ 0 .. $#{ $geo2->{elements} } ];

	# get possible orderings for each geometry
    my @orders1 = _reorder( $self, $atoms1_ref );
    my @orders2 = _reorder( $geo2, $atoms2_ref );

    my ( $min_rmsd, @min_struct );
#    my ( $time, $count, $avg_time );
    for my $o1 (@orders1) {
        for my $o2 (@orders2) {
            # test RMSD of first 10 atoms of order
            my @t1 = @{$o1};
            @t1 = splice @t1, 0, 8;
            my @t2 = @{$o2};
            @t2 = splice @t2, 0, 8;
            my $test = $self->RMSD( ref_geo     => $geo2,
                                    heavy_atoms => $heavy_only,
                                    ref_atoms1  => \@t1,
                                    ref_atoms2  => \@t2 );
            # skip ordering if worse than what we've found already
            if ( defined $min_rmsd && $test > $min_rmsd ) {
                next;
            }

#            $time = time;
#            $count++;
            my $rmsd = $self->RMSD( ref_geo     => $geo2,
                                    heavy_atoms => $heavy_only,
                                    ref_atoms1  => $o1,
                                    ref_atoms2  => $o2 );
            if ( !defined $min_rmsd || $rmsd < $min_rmsd ) {
				# save orders giving good overlap
                $min_rmsd   = $rmsd;
                @min_struct = (\@{$o1}, \@{$o2});
            }
        }
    }

	# one last RMSD giving the structure with best overlap
	return $self->RMSD( ref_geo     => $geo2,
						heavy_atoms => $heavy_only,
						ref_atoms1  => $min_struct[0],
						ref_atoms2  => $min_struct[1] );
}

sub RMSD{
    my $self = shift;

    my %params = @_;

    my ( $geo2, $heavy_only, $atoms1_ref, $atoms2_ref ) = ($params{ref_geo},
                                                           $params{heavy_atoms},
                                                           $params{ref_atoms1},
                                                           $params{ref_atoms2});
    $heavy_only //= 0;
    $atoms1_ref //= [ 0 .. $#{ $self->{elements} } ];
    $atoms2_ref //= [ 0 .. $#{ $geo2->{elements} } ];
	if ( @$atoms2_ref > @$atoms1_ref ){
		@$atoms2_ref = splice @$atoms2_ref, 0, @$atoms1_ref;
	} elsif ( @$atoms2_ref < @$atoms1_ref ){
		@$atoms1_ref = splice @$atoms1_ref, 0, @$atoms2_ref ;
	}

	my $rmsd;
	if ( defined $params{reorder} && $params{reorder} ){
		$rmsd = $self->RMSD_reorder( %params );
		return $rmsd;
	} else {
		my $cen1 = $self->get_center($atoms1_ref);
		my $cen2 = $geo2->get_center($atoms2_ref);

		$geo2 = $geo2->copy();

		$self->coord_shift( -1 * $cen1 );
		$geo2->coord_shift( -1 * $cen2 );

		for my $i ( 0 .. 2 ) {
			map { $atoms1_ref->[$_]->[$i] -= $cen1->[$i] }
			grep { $atoms1_ref->[$_] !~ /^\d+$/ } ( 0 .. $#{$atoms1_ref} );
			map { $atoms2_ref->[$_]->[$i] -= $cen2->[$i] }
			grep { $atoms2_ref->[$_] !~ /^\d+$/ } ( 0 .. $#{$atoms2_ref} );
		}

		$rmsd = $self->_RMSD( $geo2, $heavy_only, $atoms1_ref, $atoms2_ref );

		$self->coord_shift($cen2);

		for my $i ( 0 .. 2 ) {
			map { $atoms1_ref->[$_]->[$i] += $cen2->[$i] }
			grep { $atoms1_ref->[$_] !~ /^\d+$/ } ( 0 .. $#{$atoms1_ref} );
		}
		return $rmsd;
	}

}

sub _sym_SD {
    #returns the sum of the squared shortest distances between the atoms of self and ref_geom
    #really only useful for determining if two structures are exactly the same
    my $self = shift;
    my ($ref_geom) = @_;

    my $SD = 0;

    for my $i (0..$#{$self->{elements}}) {
        my $min_d;
        for my $j (0..$#{$ref_geom->{elements}}) {
            if( ${$self->{elements}}[$i] eq ${$ref_geom->{elements}}[$j] ) {
                my $d = $self->distance(atom1 => $i, atom2 => $j, geometry2 => $ref_geom );
                if( not $min_d or $d < $min_d ) {
                    $min_d = $d;
                }
                if( $d < 0.1 ) { #there's probably/hopefully nothing closer than this - slight performace improvement
                    last;
                }
            }
        }
        $SD += $min_d**2;
    }

    $SD = $SD / ($#{$self->{elements}}+1);

    return $SD;
}

sub MSD {
    my $self = shift;

    my %params = @_;

    my ($geo2, $heavy_only,
        $atoms1_ref, $atoms2_ref) = ( $params{ref_geo}, $params{heavy_atoms},
                                      $params{ref_atoms1}, $params{ref_atoms2} );

    my $msd = $self->_RMSD($geo2, $heavy_only, $atoms1_ref, $atoms2_ref, 1);

    return $msd;
}


sub _RMSD {
    my $self = shift;

    my ($geo2, $heavy_only, $atoms1_ref, $atoms2_ref, $no_rot) = @_;

    my $matrix = new Math::MatrixReal(4,4);

    for my $atom (0..$#{$atoms1_ref}) {
        if ($atoms1_ref->[$atom] =~ /^\d+$/ &&
            ($atoms2_ref->[$atom] =~ /^\d+$/) &&
            $heavy_only) {
            if ( ($self->{elements}->[$atoms1_ref->[$atom]] eq 'H')
                && ($geo2->{elements}->[$atoms2_ref->[$atom]] eq 'H') ) {
                next;
            }
        }
        my $pt1 = $atoms1_ref->[$atom] =~ /^\d+$/ ?
                  $self->get_point($atoms1_ref->[$atom]) : $atoms1_ref->[$atom];
        my $pt2 = $atoms2_ref->[$atom] =~ /^\d+$/ ?
                  $geo2->get_point($atoms2_ref->[$atom]) : $atoms2_ref->[$atom];

        $matrix += quat_matrix($pt1, $pt2);
    }

    my ($eigenvalues, $evectors) = $matrix->sym_diagonalize();

    #find smallest of four eigenvalues and save corresponding eigenvectors
    my $sd;
    my $Q = new Math::MatrixReal(1,4);
    foreach my $i (1..4) {
      my $value = $eigenvalues->element($i,1);
      if(!defined $sd || $value < $sd) {
        $sd = $value;
        $Q = $evectors->column($i);
      }
    }

    my $rmsd = 0;
    if($sd > 0) { #to avoid very small negative numbers for sd (-1e-16, etc)
      $rmsd = sqrt($sd/($#{$atoms1_ref}+1));
    }

    my $a = $Q->element(1,1);

    my $w = V($Q->element(2,1), $Q->element(3,1), $Q->element(4,1));

    unless ($no_rot){
        $self->quat_rot($a, $w);
        for my $vec (@$atoms1_ref) {
            if ($vec !~ /^\d+$/) {
                &__point_quat_rot($vec, $a, $w);
            }
        }
    }

    return $rmsd;
}


#This version of RMSD will mirror the molecules with respect to three planes
#Don't use this RMSD unless you know what you are doing, just use normal RMSD.
#This RMSD is particularly designed for non-covalent interaction.
sub RMSD_mirror {
    my $self = shift;

    my %params = @_;

    my ($geo2, $heavy_only,
        $atoms1_ref, $atoms2_ref) = ( $params{ref_geo}, $params{heavy_atoms},
                                      $params{ref_atoms1}, $params{ref_atoms2} );

    $heavy_only //= 0;
    $atoms1_ref //= [0..$#{ $self->{elements} }];
    $atoms2_ref //= [0..$#{ $geo2->{elements} }];

    my $cen1 = $self->get_center($atoms1_ref);
    my $cen2 = $geo2->get_center($atoms2_ref);

    $self->coord_shift(-1*$cen1);
    $geo2->coord_shift(-1*$cen2);

    #Run regular RMSD comparison as well as mirroring compare_geo across each plane
    #Report minimum value as the RMSD
    my @sd;
    my @Q;

    foreach my $mirrorx (0,1) {
        foreach my $mirrory (0,1) {
            foreach my $mirrorz (0,1) {
                if($mirrorx) {
                    $geo2->mirror_coords('X');
                }
                if($mirrory) {
                    $geo2->mirror_coords('Y');
                }
                if($mirrorz) {
                    $geo2->mirror_coords('Z');
                }
                my $matrix = new Math::MatrixReal(4,4);

                for my $atom (0..$#{$atoms1_ref}) {
                    my $pt1 = $self->get_point($atom);
                    my $pt2 = $geo2->get_point($atom);

                    $matrix += quat_matrix($pt1, $pt2);
                }

                my ($eigenvalues, $evectors) = $matrix->sym_diagonalize();
                #find smallest of four eigenvalues and save corresponding eigenvectors
                my $sd = 999;
                my $Q = new Math::MatrixReal(1,4);
                foreach my $i (1..4) {
                  my $value = $eigenvalues->element($i,1);
                  if($value < $sd) {
                    $sd = $value;
                    $Q = $evectors->column($i);
                  }
                }
                push (@sd, $sd);
                push (@Q, $Q);
            }
        }
    }

    my @idx_sort = sort { $sd[$a] <=> $sd[$b] } 0..$#sd;

    @sd = @sd[@idx_sort];
    @Q = @Q[@idx_sort];

    my $rmsd = 0;
    if($sd[0] > 0) { #to avoid very small negative numbers for sd (-1e-16, etc)
       $rmsd = sqrt($sd[0]/($#{$atoms1_ref}+1));
    }else {
       $rmsd = sqrt(-1*$sd[0]/($#{$atoms1_ref}+1));
    }

    my $a = $Q[0]->element(1,1);
    my $w = V($Q[0]->element(2,1), $Q[0]->element(3,1), $Q[0]->element(4,1));

    $self->quat_rot($a, $w);

    $self->coord_shift($cen2);

    return $rmsd;
}


sub align_on_subs {
    #rotates substituents (on their {rotatable_bonds}) to get $self's structure
    #as close as possible to $ref_geom's structure
    my $self = shift;
    my $ref_geom = shift;
    my $rotate_base = shift;

    $rotate_base //= 1;

    my $threshold = 1E-4;
    my $increment = 5;
    my $min_dev = $self->_sym_SD($ref_geom);
    my $delta_dev = $min_dev;

    while ($delta_dev > $threshold) { #keep trying to do better as long as we're making good improvements
        $delta_dev = $min_dev;
        if( $rotate_base ) {
            my $angle = $increment;
            my $bond_axis = $self->get_point(0);
            my $point = $self->get_point(0);
            my $min_angle = 0;

            while ($angle <= 360 ) {
                $self->center_genrotate( $point, $bond_axis, deg2rad($increment) );
                my $sd = $self->_sym_SD($ref_geom);

                if( $sd < $min_dev ) {
                    $min_dev = $sd;
                    $min_angle = $angle;
                }
                $angle += $increment;
            }
            $self->center_genrotate( $point, $bond_axis, deg2rad($min_angle));
        }

        for my $bond (@{$self->{rotatable_bonds}}) {                            #go through each bond
            my $fragment = $self->get_all_connected( $bond->[1], $bond->[0] );  #grab the atoms of the substituent
            my $angle = $increment;
            my $bond_axis = $self->get_bond( $bond->[0], $bond->[1] );
            my $point = $self->get_point( $bond->[1] );
            my $min_angle = 0;

            while ($angle <= 360 ) {                                            #rotate many times
                $self->center_genrotate( $point, $bond_axis, deg2rad($increment), $fragment );
                my $sd = $self->_sym_SD($ref_geom);

                if( $sd < $min_dev ) {
                    $min_dev = $sd;                                             #store the rotation that minimizes the deviation
                    $min_angle = $angle;
                }
                $angle += $increment;
            }
            #rotate the thing to be in the orientation that's more similar to ref_geom
            $self->center_genrotate( $point, $bond_axis, deg2rad($min_angle), $fragment );
            my $sd = $self->_sym_SD($ref_geom);
        }
        $delta_dev -= $min_dev;
    }
}


#this function map a catalyst to a ts from TS library. The old catalyst
#will be replaced by the new one. Here, $self is the geometry instance for
#the new catalyst and geo_ref is the TS geometry instance. To replace old
#catalyst, the first atom of the catalyst in the ts should be provided.
#FIXME this is a very priliminary function, and only can be used for some very specific
#purpose.
sub map_catalyst {
    my $self = shift;
    my %params = @_;
    my ($geo_ref, $bonds_LJ, $first_cat_atom) = ( $params{geo_ref},
                                                $params{bonds_LJ},
                                                $params{first_cat_atom} );

    my $mapped_cata = $self->map_molecule( geo_ref => $params{geo_ref},
                                           key_atoms1 => $params{key_atoms1},
                                           key_atoms2 => $params{key_atoms2},
                                           bonds => $params{bonds} );

    my $num_splice = $#{ $geo_ref->{elements} } - $first_cat_atom + 1;
    my $new_geo = $geo_ref->copy();

    $new_geo->splice_atom($first_cat_atom, $num_splice);
    $new_geo->append($mapped_cata->copy());
    #FIXME the catatlyst rotatation was removed
    for my $bond_LJ (@$bonds_LJ) {
        my @bond_LJ = map {$_ + $first_cat_atom} @$bond_LJ;
        $new_geo->minimize_torsion(@bond_LJ);
    }
    return $new_geo;
}


sub get_center {
    my ($self, $groups) = @_;

    $groups //= [0.. $#{ $self->{elements} }];

    my @xyz_groups = grep { $_ !~ /^\d+$/} @$groups;
    my @groups = grep{ $_ =~ /^\d+$/ } @$groups;

    my $COM = V(0, 0, 0);
    for my $atom (@groups) {
		$COM += V(@{$self->{coords}->[$atom]});}

    for my $point (@xyz_groups) {$COM += $point;}

    $COM /= $#{ $groups } + 1;

    return $COM;
}


#Find shortest path between atom1 and atom2
#Performs a breadth first search, returns length of shortest path
#returns -1 if no path found
sub shortest_path {
  my ($self, $atom1, $atom2) = @_;
  my @positions = ($atom1);
  my %visited = ( $atom1 => '0') ;	#keys are numbers of the visited atoms, values are the corresponding depths

  #loop until @positions is empty
  while(@positions) {
    my $position = shift(@positions);
    if ($position eq $atom2) {
      return $visited{$position};
    }
    foreach my $atom (@{$self->{connection}->[$position]}) { 	#if not found yet, grab all atoms connected to current atom and add to queue (unless already visited)
      if(!exists $visited{$atom}) {	#skip over element, just add atom numbers
        push(@positions, $atom);
        $visited{$atom} = $visited{$position} + 1;
      }
    }
  }
  return -1;	#return -1 if no path found in BFS
} #end shortest_path


sub rotatable_bonds {
    my $self = shift;

    my ($ref1, $ref2) = @_;

    my %bonds;
    my $empty = 1;

    for my $activei (@$ref1) {
        for my $activej (@$ref2) {
            my @path = ({$activei => -1});
            while (@path) {
                my @newpath = ();
                for my $path (@path) {
                    my ($head) = grep {$path->{$_} < 0} keys %{ $path };
                    for my $atom_next (@{$self->{connection}->[$head]}) {
                        my $new_path = { %$path };
                        $new_path->{$head} = $atom_next;

                        if ($atom_next == $activej) {
                            if ($empty) {
                                my @keys = keys %{ $new_path };
                                @bonds{@keys} = map {$new_path->{$_}} @keys;
                                $empty = 0;
                            }else {
                                for my $key (keys %bonds) {
                                    if (exists $new_path->{$key} &&
                                        ($new_path->{$key} == $bonds{$key})) {
                                            next;
                                    }else {
                                        delete $bonds{$key};
                                    }
                                }
                            }
                        }elsif (! exists $new_path->{$atom_next}) {
                            $new_path->{$atom_next} = -1;
                            push (@newpath, $new_path);
                        }
                    }
                }
                @path = @newpath;
            }
        }
    }

    for my $key (keys %bonds) {
        my $ele1 = $self->{elements}->[$key];
        my $ele2 = $self->{elements}->[$bonds{$key}];
        unless (@{$self->{connection}->[$key]} >= $CONNECTIVITY->{$ele1} ||
                @{$self->{connection}->[$bonds{$key}]} >= $CONNECTIVITY->{$ele2}) {
            my $d = $self->distance(atom1 => $key, atom2 => $bonds{$key});
            my $d_ref = $UNROTATABLE_BOND->{$ele1.$ele2} ?
                        $UNROTATABLE_BOND->{$ele1.$ele2} : $UNROTATABLE_BOND->{$ele2.$ele1} ?
                                                           $UNROTATABLE_BOND->{$ele2.$ele1} : 0;
            if ($d_ref) {
                if ($d < $d_ref) {
                    delete $bonds{$key};
                }
            }else {
                my $msg = "Unrotatable bond criterion $ele1-$ele2 is not implemented, " .
                          "This bond will be viewed as a rotatable bond\n";
                warn($msg);
            }
        }
    }
    return \%bonds;
}


sub bare_backbone {
    my $self = shift;

    my ($active_centers) = @_;

    my %backbone;
    my @active_centers = @$active_centers;

    while (@active_centers) {
        my $activei = shift @active_centers;
        my $activej = $active_centers[0] || $activei;

        my @path = ({$activei => 1, head => $activei});
        while (@path) {
            my @newpath = ();
            for my $path (@path) {
                for my $atom_next (@{$self->{connection}->[$path->{head}]}) {
                    my $new_path = { %$path };
                    $new_path->{$atom_next} = 1;

                    if (($atom_next == $activei || ($atom_next == $activej)) &&
                        (keys %{ $new_path } > 3)) {
                        @backbone{keys %{ $new_path }} = ();
                    }elsif (! exists $path->{$atom_next}) {

                        $new_path->{head} = $atom_next;
                        push (@newpath, $new_path);
                    }
                }
            }
            @path = @newpath;
        }
    }

    delete $backbone{head};

    %backbone = map { $_ => 1 } @$active_centers if (keys %backbone == 0);

    return \%backbone;
}


sub printXYZ {
    my $self = shift;

    my ($filename, $comment, $overwrite) = @_;

    my $content = $self->XYZ($comment);

    my $handle;
    if($filename) {
        if ($overwrite) {
            open $handle, ">$filename" or die "Can't open $filename\n";
        } else {
            open $handle, ">>$filename" or die "Can't open $filename\n";
        }
    }else {
        $handle = *STDOUT;
    }

    print $handle $content;
    close $handle if $filename;
}


sub XYZ {

    my $self = shift;

    my ($comment) = @_;
    $comment //= '';

    unless($comment) {

        if ($self->{constraints}) {
			my $has_constraints = 0;
            for my $constraint (@{$self->{constraints}}) {
				if ( grep { /^\D+$/ } @{ $constraint->[0] } ){ next; }
                my @bond = map { $_ + 1 } @{ $constraint->[0] };
                $comment .= "$bond[0]-$bond[1];";
				$has_constraints = 1;
            }
            $comment = " F:" . $comment if $has_constraints;
        }

        if ($self->{ligand}->{active_centers} ||
            $self->{active_centers}) {
            my $centers = $self->{ligand}->{active_centers} ? $self->{ligand}->{active_centers} :
                          $self->{active_centers};
            $comment .= " K:";
            for my $key_atoms (@{$centers}) {
                my @key_atoms = map { $_ + 1 } @$key_atoms;
                #$key_atoms = join(',', @key_atoms);
                $comment .= join(',', @key_atoms) . ";";
            }
        }

        if ($self->{center_atom}) {
            $comment .= " C:";
            my $center_atom = $self->{center_atom} + 1;
            $comment .= $center_atom;
        }

        if ($self->{RMSD_bonds}) {
            $comment .= " B:";
            for my $bonds (@{ $self->{RMSD_bonds} }) {
                for my $bond (@$bonds) {
                    my $bond_temp = join('-', map {$_ + 1} @$bond);
                    $comment .= "$bond_temp,";
                }
                $comment =~ s/,^/;/;
            }
        }

        if ($self->{ligand_atoms}) {
            $comment .= " L:";
            my $start = $self->{ligand_atoms}->[0] + 1;
            my $end = $self->{ligand_atoms}->[-1] + 1;

            $comment .= "$start-$end";
        }
    }

    $comment //= $self->{name};

    my $num_atoms = $#{ $self->{elements} } + 1;

    my $return = '';
    $return = sprintf "$num_atoms\n$comment\n";
    foreach my $atom (0..$#{ $self->{elements} }) {
       $return .= sprintf "%s%14.6f%14.6f%14.6f\n", ($self->{elements}->[$atom], @{ $self->{coords}->[$atom] });
    }
    return $return;
}



#Writes com file
#write_com(route, comment, charge, multiplicity, ref_to_coords, footer, flag)
#write_com(route, comment, charge, multiplicity, ref_to_coords, footer, flag, filename)
#where footer contains anything that goes after the coords (gen basis specification, mod redundant commands, etc)
#flag = 0 will print only elements and coords
#flag = 1 will print 0/-1 column as well
sub write_com {
    my $self = shift;
    my %params = @_;
    my ($comment, $route, $charge, $mult, $footer, $flag, $filename) = ( $params{comment},
                                                                         $params{route},
                                                                         $params{charge},
                                                                         $params{mult},
                                                                         $params{footer},
                                                                         $params{print_flag},
                                                                         $params{filename} );
    my $fh;
    $filename && open ($fh, ">$filename") || ($fh = *STDOUT);

    print $fh "$route\n\n";
    print $fh "$comment\n\n";
    print $fh "$charge $mult\n";

    foreach my $atom (0..$#{ $self->{elements} }) {
        if ($flag) {
            printf $fh "%-2s%4s%14.6f%14.6f%14.6f\n", ($self->{elements}->[$atom],
                                                       $self->{flags}->[$atom],
                                                       @{ $self->{coords}->[$atom] });
        }else {
            printf $fh "%2s%14.6f%14.6f%14.6f\n", ($self->{elements}->[$atom],
                                                       @{ $self->{coords}->[$atom] });
        }
    }

    print $fh "\n";
    if($footer) {
      print $fh "$footer\n";
    }
    print $fh "\n\n";

    close ($fh);
}


sub flatten {
    my ($self) = @_;

    my $num_atoms = $#{ $self->{elements} } + 1;
    my $geometry = "$num_atoms\\\\n\\\\n";
    foreach my $atom (0..$#{ $self->{elements} }) {
        $geometry .= "$self->{elements}->[$atom] $self->{coords}->[$atom]->[0] ".
                     "$self->{coords}->[$atom]->[1] $self->{coords}->[$atom]->[2]\\\\n";
    }

    return $geometry;
}




sub union {
    my ($a, $b) = @_;
    $a //= [];
    $b //= [];

    my @union = ();
    my %union = ();

    for my $e (@$a) { $union{$e} = 1 }
    for my $e (@$b) { $union{$e} = 1 }

    return [sort keys %union];
}


sub quat_matrix {
    my ($pt1, $pt2) = @_;
    my ($xm, $ym, $zm) = @{ $pt1 - $pt2 };
    my ($xp, $yp, $zp) = @{ $pt1 + $pt2 };

    my $temp_matrix = Math::MatrixReal->new_from_rows(
        [[$xm*$xm + $ym*$ym + $zm*$zm, $yp*$zm - $ym*$zp,          $xm*$zp - $xp*$zm,           $xp*$ym - $xm*$yp],
        [$yp*$zm - $ym*$zp,           $yp*$yp + $zp*$zp + $xm*$xm,$xm*$ym - $xp*$yp,           $xm*$zm - $xp*$zp],
        [$xm*$zp - $xp*$zm,           $xm*$ym - $xp*$yp,          $xp*$xp + $zp*$zp + $ym*$ym, $ym*$zm - $yp*$zp],
        [$xp*$ym - $xm*$yp,           $xm*$zm - $xp*$zp,          $ym*$zm - $yp*$zp,           $xp*$xp + $yp*$yp + $zm*$zm]]
    );

    return $temp_matrix;
}


#########################################
#some internal function you should never#
#call outside                           #
#########################################

sub __point_quat_rot {
    my ($vec, $a, $w) = @_;

    my $wx = $w x $vec;
    my $new_vec = $vec + 2*$a*$wx + 2*($w x $wx);
    #This is to maintain the array ref
    map {$vec->[$_] = $new_vec->[$_]} (0..2);
}


package AaronTools::NanoTube;
use strict; use warnings;
use Math::Trig;
use Math::Vector::Real;
our @ISA = qw(AaronTools::Geometry);

my $CC = 1.415;
my $CH = 1.08;

sub new {
    #initiate
    my $class = shift;
    my %params = @_;
    my $name = $params{name} ?
               "$params{name}-$params{width}-$params{length}" :
               "nt-$params{width}-$params{length}";

    my $self = new AaronTools::Geometry(name => $name);

    $self->{width} = $params{width};
    $self->{length} = $params{length};
    $self->{radius} = $params{radius};
    $self->{angular_offset} = $params{angular_offset} // 0;

    my $fragment = $self->{radius} ? 1 : 0;
    $self->{radius} //= ($self->{width} >= 2) ?
                        newton($CC, $self->{width}) : 0;
    unless ($self->{radius}) {die ("Can't build nanotube smaller than (2,2)!\n");}

    bless $self, $class;

    #make new atom geometry
    my $atom = new AaronTools::Geometry(name => 'carbon',
                                        elements => ['C'],
                                        coords => [[$self->{radius}, 0, 0]]);

    #build nano tube;
    my $CC_angle = 2*asin($CC/(2*$self->radius()));
    my $CC_halfangle = 2*asin($CC/(4*$self->radius()));
    my $CC_side = $CC*sqrt(3.0)/2.0;

    my $a = $self->angular_offset();
    my $angle = -($self->width()/2+$self->width()-1)*$CC_angle -
                $self->angular_offset()*2*($CC_angle+$CC_halfangle);
    $atom->rotate('z', $angle);

    my $shift = V(0, 0, $CC_side*($self->length()-1)/2);
    $atom->coord_shift($shift);

    my $angle_tally = 0;


    for(my $row=0; $row<$self->length(); $row++) {
        if($row%2==1) {
            if($row!=$self->length()-1 || $fragment==0) {
                $self->append($atom->copy());
            }
            $atom->rotate('z', $CC_angle+2*$CC_halfangle);
            $angle_tally += $CC_angle+2*$CC_halfangle;
        } else {
            $atom->rotate('z', $CC_halfangle);
            $angle_tally += $CC_halfangle;
        }
        for (my $ring=0; $ring<$self->width(); $ring++) {
            if($row!=$self->length()-1 || $row%2!=1 || $ring != $self->width()-1 || $fragment==0) {
                $self->append($atom->copy());
            }
            $atom->rotate('z', $CC_angle);
            $angle_tally += $CC_angle;
            if($row%2!=1 || $ring != $self->width()-1) {
                $self->append($atom->copy());
            }
            $atom->rotate('z', $CC_angle+2*$CC_halfangle);
            $angle_tally += $CC_angle+2*$CC_halfangle;
        }

        #Reset and shift
    #    slide(-$CC_side);
        $atom->coord_shift(V(0, 0, -$CC_side));
        $atom->rotate('z', -$angle_tally);
        $angle_tally = 0;
    }

    #Cap open valences
    my $Hatom = new AaronTools::Geometry(name => 'hydrogen',
                                        elements => ['H'],
                                        flags => [0],
                                        coords => [[0, 0, 0]]);

    my $numCs = $#{ $self->{elements} };
    my $Hatoms = new AaronTools::Geometry(name => 'Hs');
    foreach my $atom1 (0..$numCs) {
        my $vector = V(0, 0, 0);
        my $neighbors = 0;
        foreach my $atom2 (0..$numCs) {
            if($atom1 != $atom2) {
                if($self->distance(atom1 => $atom1, atom2 => $atom2) < $CC+0.1) {
                    $neighbors++;
                    $vector += $self->get_bond($atom2, $atom1);
                }
            }
        }
        if($neighbors < 3) {
            my $norm = abs($vector);
            $vector /= $norm;
            my $coord = [ @{ $self->get_point($atom1) - $vector } ];
            $Hatom->update_coords(targets => [0], coords => [$coord]);
            $Hatoms->append($Hatom->copy());
        }
        if($neighbors < 2) {
            die "Dangling carbon $atom1!";
        }
        if($neighbors > 4) {
            die "Too many neighbors for atom $atom1 (radius too small to accommodate $self->width() rings)";
        }
    }
    $self->append($Hatoms->copy());
    $self->refresh_connected();
    return $self;
}


sub copy {
    my $self = shift;
    my $new =  new AaronTools::Geometry( name => $self->{name},
                                         elements => [ @{ $self->{elements} } ],
                                         flags => [ @{ $self->{flags} }],
                                         coords => [ map { [ @$_ ] } @{ $self->{coords} } ],
                                         connection => [ map { [ @$_ ] } @{ $self->{connection} } ],
                                         constraints => [ map { [ @$_ ] } @{ $self->{constraints} } ] );
    for my $key ('width', 'length', 'radius', 'angular_offset') {
        $new->{$key} = $self->{$key};
    }
    bless $new, "AaronTools::NanoTube";
    return $new;
};


sub width {
    my $self = shift;
    return $self->{width};
}


sub length {
    my $self = shift;
    return $self->{length};
}


sub radius {
    my $self = shift;
    return $self->{radius};
}


sub angular_offset {
    my $self = shift;
    return $self->{angular_offset};
}


#Dirty Newton solver to get radius of closed CNTs
sub newton {
  my ($CC, $width) = @_;
  #Threshold for Newton-Raphson solver to get radius
  my $THRESH = 1E-10;

  my $lastradius = 3*$CC*$width/(2*pi()); #starting guess from conventional formula
  my $old_gap = get_CNT_gap($lastradius, $CC, $width);
  my $radius = $lastradius + 0.01; #arbitrary step to get process started
  my $gap = get_CNT_gap($radius, $CC, $width);

  #Simple Newton solver using very crude finite difference derivative
  while(abs($gap) > $THRESH) {
    my $newradius = $radius - $gap*($radius - $lastradius)/($gap - $old_gap);
    $old_gap = $gap;
    $gap = get_CNT_gap($newradius, $CC, $width);
    $lastradius = $radius;
    $radius = $newradius;
  }
  return $radius;
}


#Function to be minimized to get the radius of closed CNT
sub get_CNT_gap {
  my ($guess, $CC, $width) = @_;
  my $value = asin($CC/(2*$guess)) + asin($CC/(4*$guess)) - pi()/(2*$width);
  return $value;
}



package AaronTools::Substituent;
use strict; use warnings;
use Math::Trig;
use Math::Vector::Real;
our @ISA = qw(AaronTools::Geometry);

sub new {
    my $class = shift;
    my %params = @_;

    my $self = new AaronTools::Geometry();
    delete $self->{constraints};
    bless $self, $class;

    if (exists $params{name}) {
        $self->set_name($params{name});

        if (-f "$ENV{HOME}/Aaron_libs/Subs/$self->{name}.xyz") {
            $self->read_geometry("$ENV{HOME}/Aaron_libs/Subs/$self->{name}.xyz");
        } elsif (-f "$QCHASM/AaronTools/Subs/$self->{name}.xyz") {
            $self->read_geometry("$QCHASM/AaronTools/Subs/$self->{name}.xyz");
        } elsif ( $self->{name} ) {
            #if we don't have the substituent in the library, we can try to build it
            $self->{name} = &_replace_common_names( $self->{name} );
            $self->build_sub();
        }

        unless( $self->{conformers} ) {
            push @{$self->{conformers}}, $self->{conformer_num};
            push @{$self->{rotations}}, $self->{conformer_angle};
        }

    }

    $self->{end} = $params{end};
    #This is the potential substituent in the furture
    $self->{sub} = $params{sub};

    return $self;
}

sub build_sub {
    #this builds a substituent based on the name of the object passed to it
    #e.g. passing it an object named 4-OMe-Ph will grab the OMe and stick it on the para position of the Ph substituent
    #passing it 2-{4-OMe-Ph}Et will build 2-(p-methoxyphenyl)ethyl
    my $self = shift;

    my $basename; #basename is the thing build_sub decorates with other substituents (i.e. 4-OMe-Ph: Ph is basename, 4-OMe is a decoration)

    if( $self->{name} =~ /-/ ){
        $basename = (split /-/, $self->{name})[-1]; #grab the thing after the last hyphen - this is the basename
    }
    if( $self->{name} =~ /}/ ) {
        $basename = (split /}/, $self->{name})[-1]; #grab the thing after the last } - this is the basename
    }
    if( $self->{name} =~ /-/ and $self->{name} =~ /}/ ) { #if - and } are in the name, we'll take the one that gives the shortest basename
        my $basename1 = (split /-/, $self->{name})[-1];
        my $basename2 = (split /}/, $self->{name})[-1];
        if( length($basename1) > length($basename2) ) {
            $basename = $basename2;
        } else {
            $basename = $basename1;
        }
    }

    unless( $basename ) { die "Error while trying to build $self->{name}:\nUnable to add substituents to '$basename'\n" }
    # ^ this will generally just catch when the user has a typo in the name of something

    my $partname = substr($self->{name}, 0, -length($basename));
    $partname =~ s/-$//; #decorations are the subname minus the basename and the last hyphen
    my %parts; #dictionary for the different parts we're going to stick on the base
    my @positions; #dictionary for the corresponding positions of the parts

    my $i = 0; #the decorations are processed by sequencially removing characters from $partname
    while( length($partname) > 0 ) {
        if( $partname =~ m/^-/ ) {
            $partname =~ s/^-?//;
        }
        my ($posi) = $partname =~ m/^((\d+-)+)/; #positions are in the format nn-mm-
        unless( $posi ) { die "Error while trying to build $self->{name}:\nSubstituent positions not specified for $partname\n" };
        $partname =~ s/^$posi//;
        if( $partname =~ m/^{/ ) {
        #check to see if this part has brackets in it
            $parts{$i} = &_find_matching_brackets($partname); #grab the contents inside the first matching brackets
            $partname =~ s/^{$parts{$i}}//; #remove it from partname
        } else {
        #this'll grab the NO2 part of NO2-4-F and let 4-F be handled the next pass through the while loop
        #it'll also handle things like 2-{2-{4-OMe-Ph}Et}CHCH2 : 2-{4-OMe-Ph}Et would be the part
            my ($part) = $partname =~ m/^(\w+|(\{.*\}))/;
            $parts{$i} = $part;
            $partname =~ s/^$part//;
        }
        $posi =~ s/-$//;
        my @posis = split /-/, $posi;
        for my $p (0..$#posis) { $posis[$p] -= 1 } ;
        $positions[$i] = [@posis];
        $i += 1;
    }

    my $base = new AaronTools::Substituent( name => $basename );
    my $base_rot_sym = $base->determine_rot_sym(0);
    if( $base_rot_sym > 10 ) { #basically C_infinity
        $base->{conformer_num} = 1;
        $base->{conformer_angle} = 0;
    } elsif( $base_rot_sym != 1 ) { #C2, C3, etc
        $base->{conformer_num} = 2;
        $base->{conformer_angle} = 180/$base_rot_sym;
    } #if it's C1, we're going to have to have some info from the xyz file or build_sub

    my @n = $base->_number_atoms; #get the order of the heavy atoms

    for my $key (keys %parts) {
        my $pos_len = scalar(@{$positions[$key]});
        my $j = 0;
        while( $j < $pos_len ) { #this loop makes it so you can put 246-Me-Ph instead of 2-4-6-Me-Ph
            while( $positions[$key]->[$j] > $#n ) {
                my $p = $positions[$key]->[$j];
                $positions[$key]->[$j] = $p % 10;              #grab the ones place
                my $np = ($p - $positions[$key]->[$j])/10 - 1; #grab the tens place, take off 1 (0 indexing...)
                if( $np == -1 ) { die "Error while trying to build $self->{name}:\nEnd of register while parsing positions of $parts{$key}\n" }
                # ^ this catches when the position is greater than the number of atoms on the base (e.g. 3-Me-Et)
                # such an issue would cause an infinite loop without this die
                push @{$positions[$key]}, $np;
                $pos_len += 1; #we now have an aditional place to add this substituent
            }
            $j += 1;
        }
        for my $at (@{$positions[$key]}) {
            my $H = $base->_give_me_an_H($n[$at]); #grab an H on the nth atom
            unless( $H ) { die "Error while trying to build $self->{name}:\nCould not find an H on atom $n[$at] of $basename\n"; }
            # ^ this catches when the atom on the base has no H's left (e.g. 2-2-CF3-Ph)
            $base->substitute( target => $H, sub => $parts{$key}, minimize_torsion => 0);
        }
    }

    my $new_rot_sym = $base->check_rot_sym( $base_rot_sym );
    if( $new_rot_sym != $base_rot_sym ) { #if the new substituent doesn't have the same symmetry as the
                                          #base, we'll need to adjust the number of conformers it has
        $base->{rotations}->[0]  =  $base->{conformer_angle} * ( 1 + $base_rot_sym % 2 );
        $base->{conformers}->[0] =  360/$base->{rotations}->[0];
    } else {
        $base->{rotations}->[0]  =  $base->{conformer_angle};
        $base->{conformers}->[0] =  $base->{conformer_num};
    }

    $self->{elements}        =    $base->{elements};
    $self->{flags}           =    $base->{flags};
    $self->{coords}          =    $base->{coords};
    $self->{rotatable_bonds} =    $base->{rotatable_bonds};
    $self->{conformers}      =    $base->{conformers};
    $self->{rotations}       =    $base->{rotations};

    $self->refresh_connected();
    return 1;
}

sub _replace_common_names {
    #replace some common names with what you'd pass build_sub to build the substituent
    #could possibly include things like tBu and iPr in the future
    my $name = shift;
    #misc substituents
    $name =~ s/^Bn$/1-Ph-Me/;                           #benzyl
    $name =~ s/^MePh2/11-Ph-Me/;                        #diphenylmethyl
    $name =~ s/^MePh3/111-Ph-Me/;                       #triphenylmethyl
    $name =~ s/^EtF5$/1-CF3-11-F-Me/;                   #pentafluoroethyl
    $name =~ s/^sBu$/1-Et-Et/;                          #sec-butyl
    $name =~ s/^iBu$/1-iPr-Me/;                         #iso-butyl
    $name =~ s/^nBu$/1-{1-Et-Me}Me/;                    #n-butyl
    $name =~ s/^Pr$/1-Et-Me/;                           #n-propyl
    #misc protecting groups
    $name =~ s/^Boc$/2-tBu-COOH/;                       #t-butyloxycarbonyl
    $name =~ s/^CBz$/2-Bn-COOH/;                        #carboxybenzyl
    $name =~ s/^PMB$/4-OMe-Bn/;                         #4-methoxybenzyl
    $name =~ s/^MOM$/1-OMe-Me/;                         #methoxymethyl
    #OH protecting groups
    $name =~ s/^BOM$/1-{1-{1-Bn-OH}Me}OH/;              #benzyloxymethyl acetal
    $name =~ s/^R-EE$/1-{1-Me-1-{1-Et-OH}Me}OH/;        #ethoxyethyl acetal
    $name =~ s/^S-EE$/1-{1-{1-Et-OH}-1-Me-Me}OH/;       #ethoxyethyl acetal
    $name =~ s/^TBDPS$/1-{1-tBu-11-Ph-SiH3}OH/;         #t-butyldiphenylsilyl ether
    $name =~ s/^TBS$/1-{1-tBu-11-Me-SiH3}OH/;           #t-butyldimethylsilyl ether
    $name =~ s/^TIPS$/1-{111-iPr-SiH3}OH/;              #triisopropylsilyl ether
    $name =~ s/^TES$/1-{111-Et-SiH3}OH/;                #triethylsilyl ether
    $name =~ s/^Troc$/1-{2-{1-{111-Cl-Me}Me}-COOH}-OH/; #2,2,2-trichloroethyl carbonate

    return $name;
}

sub _find_matching_brackets {
    #returns the contents inside the first pair of matching brackets in the string
    my $str = shift;

    my $position = 1;
    my $counter = 0; #counter ++ when { is found
                     #counter -- when } is found
                     #return when counter = 0
    while( $position <= length($str) ) {
        my $s = substr $str, 0, $position;
        if( $s =~ m/{$/ ) {
            $counter += 1;
        } elsif( $s =~ m/}$/ ) {
            $counter -= 1;
        }
        if( $counter == 0 ) {
            my ($out) = $s =~ m/^{(.*)}$/;
            return $out;
        }
        $position += 1;
    }
}

sub _number_atoms {
    #determines order of atoms on straight alkyl chains and phenyl rings
    #I would not trust it with things that are not straight alkyl chains or phenyl rings
    #this should probably be made more robust
    my $self = shift;
    my @out; #output array - nth item in this array is the nth atom (e.g. for Et, $out[1] will be the index of C in CH3)

    my $natoms = $#{$self->{elements}};

    my @heavy_atoms; #list of non-H atoms

    for my $i (0..$#{$self->{elements}}) {
        if( ${$self->{elements}}[$i] ne 'H' ) {
            push @heavy_atoms, $i;
        }
    }

    if( not @heavy_atoms ) {
        return @out; #there are no heavy atoms (i.e. you tried to number the atoms of H)
    }

    my $i = $heavy_atoms[0]; #assume the first heavy atom is the atom we'd call number 1
    $out[0] = $i;
    my $b;

    while( $#out < $#heavy_atoms ) { #this will go until all heavy atoms are in the list
        my $distance = -1;
        for my $j (@{$self->{connection}->[$i]}) {
            if( grep( /^$j$/, @heavy_atoms ) ) {
                my $d = $self->distance(atom1 => $i, atom2 => $j);
                if( ($d < $distance or $distance < 0) and not grep( /^$j$/, @out ) ) {
                    $distance = $self->distance(atom1=> $i, atom2=> $j);
                    $b = $j;
                }
            }
        }
        if( $b != $i ) {
            push @out, $b;  #add the closest heavy atom to the list
            $i = $b;
        } else { #if we try to add the atom we just added, walk backwards until we get on a different branch
            ($i) = grep { $out[$_] eq $i } (0..$#out);
            $i -= 1;
            $b = $i;
        }
    }

    $i = 1;
    while($i <= $#out) { #get rid of atoms that don't have hydrogen bonded to them
        my $Hs = 0;      #this'll cause fusion C's to be skipped in things like naphthyl
        for my $bonded (@{$self->{connection}->[$out[$i]]}) {
            if( $self->{elements}->[$bonded] eq 'H' ) {
                $Hs += 1;
                last;
            }
        }
        if( $Hs == 0 ) {
            splice @out, $i, 1;
        } else {
            $i += 1;
        }
    }

    return @out;
}

sub _give_me_an_H {
    #finds an H bonded to a given atom
    my $self = shift;
    my $at = shift;
    my $H; #atom number of an H on atom number at
    my $natoms = $#{$self->{elements}};
    my $min_dot = -1;
    my $bondv = $self->get_point(0);
    $bondv = $bondv / abs($bondv);
    for my $i (@{$self->{connection}->[$at]}) {
        if( ${$self->{elements}}[$i] eq 'H' ) {
            my $hv = $self->get_bond($i, $at);
            $hv = $hv / abs($hv);
            my $dot = $bondv * $hv;
            #find the H most parallel to origin-atom0 vector
            if( $dot > $min_dot or $min_dot == -1) {
                $min_dot = $dot;
                $H = $i;
            }
        }
    }

    return $H;
}

sub determine_rot_sym {
    #determines order of rotational axis (e.g. C3, C2, C1, etc) about the new bond for a substituent
    #it spins around the x axis and sees how many times the deviation between the rotated structure
    #and the unrotated structure is 0ish - structures must be very symmetric for this to work
    my $self = shift;
    my $atom = shift;

    my $increment = 15; #angle increment to search over
    if( $#{$self->{elements}} < 1 ) {
        return 360/$increment; #don't bother checking when there's just one atom (e.g. F, Cl,...)
    }

    my $targets = [(0..$#{$self->{elements}})];
    my $SD_min = 1E-4; #it's a low bar to be symmetric
    my $order = 0;
    my $axis = $self->get_point($atom);
    my $ref_geom = $self->copy; #unrotated copy

    my $angle = $increment;
    while( $angle <= 360 ){
        $self->center_genrotate($axis, $axis, deg2rad($increment), $targets );
        my $sd = $self->_sym_SD($ref_geom); #check deviation from unrotated strux
        if($sd < $SD_min) {
            $order = 360/$angle;
            last;
        }
        $angle += $increment;
    }

    return $order;
}

sub check_rot_sym {
    #checks to see if the substituent still has a certain degree of rotational symmetry
    #applies a C_n rotation and spins the rotatable bonds to see if the deviation between
    #the rotated structure and the original is small
    my $self = shift;
    my $order = shift; #n in C_n for the level of rotational symmetry we're expecting

    my $threshold = 5E-1; #really easy threshold b/c we'd have to do a really small increment otherwise
    my $increment = 5;
    my $ref_geom = $self->copy; #make a copy
    my $axis = $self->get_point(0);
    my $sub_atoms = [(0..$#{$self->{elements}})];
    $ref_geom->center_genrotate($axis, $axis, deg2rad(360/$order), $sub_atoms); #apply the C_n operation

    $self->align_on_subs($ref_geom, 0);

    my $SD = $self->_sym_SD($ref_geom);
    if( $SD < $threshold ) { #after we've checked all the bonds, see if the deviation is below the threshold
        return $order;
    } else {
        return 1; #if it isn't symmetry is 'broken', and it's now just a C1
    }
}

sub copy {
    my $self = shift;

    my $new =  new AaronTools::Geometry( name => $self->{name},
                                         elements => [ @{ $self->{elements} } ],
                                         flags => [ @{ $self->{flags} }],
                                         coords => [ map { [ @$_ ] } @{ $self->{coords} } ],
                                         connection => [ map { [ @$_ ] } @{ $self->{connection} } ] );

    bless $new, "AaronTools::Substituent";
    $new->{end} = $self->{end};
    $new->{sub} = $self->{sub};
    $new->{conformer_num} = $self->{conformer_num};
    $new->{conformer_angle} = $self->{conformer_angle};
    $new->{conformers} = $self->{conformers};
    $new->{rotations} = $self->{rotations};
    $new->{rotatable_bonds} = $self->{rotatable_bonds};
    return $new;
};


sub end {
    my $self = shift;
    return $self->{end};
}


sub read_geometry {
    my ($self, $file) = @_;

    my ($elements, $flags, $coords, $constraints, $ligand,
        $TM, $key_atoms, $bonds, $conformer) = AaronTools::FileReader::grab_coords($file);

    $self->{elements} = $elements;
    $self->{flags} = $flags;
    $self->{coords} = $coords;
    $self->{conformer_num} = $conformer->[0];
    $self->{conformer_angle} = $conformer->[1];

    $self->refresh_connected();
}


sub compare_lib {
    my $self = shift;

    my $subs = {};

    open (my $fh, "<$QCHASM/AaronTools/Subs/subs") or die "Cannot open $QCHASM/AaronTools/Subs/subs";

    while (<$fh>) {
        chomp;
        if ($_ =~ /[0-9a-zA-Z]/) {
            my $name = $_;
            my $sub = new AaronTools::Substituent( name => $name );
            delete $sub->{coords};
            delete $sub->{flags};
            $subs->{$name} = $sub;
        }
    }

    for my $sub (keys %{ $subs }) {
        if ($#{ $subs->{$sub}->{elements} } != $#{ $self->{elements} }) {
            delete $subs->{$sub};
        }else {
            $subs->{$sub}->{visited} = {};
            $subs->{$sub}->{open_set} = { 0 => $subs->{$sub}->{elements}->[0] };
        }
    }
    #initiate $self_sub
    my $self_sub = {};
    $self_sub->{connection} = $self->{connection};
    $self_sub->{elements} = $self->{elements};
    $self_sub->{visited} = {};
    $self_sub->{open_set} = { 0 => $self->{elements}->[0] };

    while (%{ $subs } && %{ $self_sub->{open_set} }) {
        for my $sub (keys %{ $subs }) {
            unless(&_same_nodes($subs->{$sub}->{open_set}, $self_sub->{open_set})) {
                delete $subs->{$sub};
                next;
            }else {
                &_move_to_next_layer($subs->{$sub});
            }
        }
        &_move_to_next_layer($self_sub);
    }

    my @subs = keys %{ $subs };
    if ($#subs < 0) {
#        print {*STDERR} "Cannot determine the type of substituent, so no conformer information retrieved.\n";
    }elsif ($#subs == 0) {
       $self->{name} = $subs[0];
       $self->{conformer_num} = $subs->{$subs[0]}->{conformer_num};
       $self->{conformer_angle} = $subs->{$subs[0]}->{conformer_angle};
    }else {
       print {*STDERR} "Multiple similar substituents were found, but cannot tell which one it is (No conformer information): \n";
       print "@subs\n";
    }
}


#align the substituent to a bond of geometry object
sub _align_on_geometry {
    my $self = shift;
    my %params = @_;

    my ($geo, $target, $end) = ($params{geo}, $params{target}, $params{end});

    #Rotate to align along nearest_neighbor-target bond then shift sub_coords to nearest_neighbor position
    my $nearst_v = $geo->get_point($end);
    my $target_v = $geo->get_point($target);

    my $bond_axis = $target_v - $nearst_v;

    $bond_axis /= $bond_axis->norm();

    #sub_coords are aligned along x-axis, so find rotation axis that transforms x-axis to bond_axis
    my $v_x = V(1,0,0);
    my $cross = $v_x x $bond_axis;
    unless( $cross->norm() ) { $cross = V(0,1,0); };
    my $angle = atan2($bond_axis, $v_x);

    $self->genrotate($cross, $angle);
    $self->coord_shift($nearst_v);

    my $current_distance = $self->distance( atom1 => 0, atom2 => $end,
                                           geometry2 => $geo);
    my $current_bond = $self->get_bond( 0, $end, $geo);

    my $new_distance = $radii->{$self->{elements}->[0]}
                       + $radii->{$geo->{elements}->[$end]};

    my $difference = $new_distance - $current_distance;

    my $v12 = $current_bond * $difference / $new_distance;

    $self->coord_shift($v12);
}


#######################
#Some useful functions#
#######################
sub _same_nodes {
    my ($set1, $set2) = @_;

    my %set1 = %{ $set1 };
    my %set2 = %{ $set2 };

    my $same_nodes = 1;

    if (keys %set1 != keys %set2) {
        $same_nodes = 0;
    }else {
        my @keys_set1 = sort {$a <=> $b} keys %set1;
        while(%set1 && $same_nodes) {
            my $i = shift @keys_set1;
            my $j;
            my $found = 0;
            for my $j_temp (keys %set2) {
                if ($set1{$i} eq $set2{$j_temp}) {$found = 1; $j=$j_temp; last;}
            }
            unless ($found) {
                $same_nodes = 0
            }else{ delete $set1{$i}; delete $set2{$j}; }
        }
    }

    if (%set2) {$same_nodes = 0};

    return $same_nodes;
}


sub _move_to_next_layer {
    my ($set) = @_;

    for my $key (keys %{ $set->{open_set} } ) {
        $set->{visited}->{$key} = $set->{open_set}->{$key};
        delete $set->{open_set}->{$key};

        for my $connected (@{ $set->{connection}->[$key] }) {
            if (! exists $set->{visited}->{$connected}) {
                $set->{open_set}->{$connected} = $set->{elements}->[$connected];
            }
        }
    }
}
