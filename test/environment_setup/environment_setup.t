#!/usr/bin/env perl

# Test environmental variables are set appropriately
# and that necessry configuration files are found

use strict;
use warnings;

use Test::More;

ok( $ENV{QCHASM},
    "QCHASM environmental variable should be set to QCHASM path." );

ok( $ENV{PERL_LIB},
    "PERL_LIB environmental variable should be set to the appropriate path." );
SKIP: {
    skip "Cannot check for required modules without \$PERL_LIB set.", 2
      if ( not $ENV{PERL_LIB} );

    use lib $ENV{PERL_LIB};
    require_ok "Math::Vector::Real";
    require_ok "Math::MatrixReal";
}

done_testing();
