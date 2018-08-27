#!/bin/bash

cd $QCHASM/AaronTools/test

# command line scripts
files="$(find -regex './command_line_scripts/cat_screen/.*/test_.*') "
files+="$(find -regex './command_line_scripts/cat_substitute/.*/test_.*') "
files+="$(find -regex './command_line_scripts/dihedral/.*/test_.*') "
files+="$(find -regex './command_line_scripts/follow/.*/test_.*') "
files+="$(find -regex './command_line_scripts/genrotate/.*/test_.*') "
files+="$(find -regex './command_line_scripts/grab_coords/.*/testout.xyz') "
files+="$(find -regex './command_line_scripts/grab_thermo/.*/test.csv') "
files+="$(find -regex './command_line_scripts/rotate/.*/test_.*') "
files+="$(find -regex './command_line_scripts/substitute/.*/test.xyz') "

# other tests
files+="$(find -regex './job_setup/test.(job|e.*|o.*)') "
files+="$(find -regex './map_ligand/.*/result.xyz') "
files+="$(find -regex './substitute.*/result.xyz') "

# for f in $files; do echo $f; done

/bin/rm -f $files
