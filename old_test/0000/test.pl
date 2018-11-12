#!/usr/bin/env -S perl -w
use strict; use warnings;

my $fail;

unless ($ENV{'QCHASM'}) {
    warn "FATAL! Environmental variable \$QCHASM is not set.\n" .
         "Please set the path to QCHASM directory as \$QCHASM environmental variable.\n";
    $fail = 1;
}

unless ($ENV{'QUEUE_TYPE'}) {
    warn "FATAL! Environmental variable \$QUEUE_TYPE is not set.\n" .
         "Please set the type of queue as \$QUEUE_TYPE environmental variable.\n";
    $fail = 1;
}

unless ($ENV{'PERL_LIB'}) {
    warn "FATAL! Environmental variable \$PERL_LIB is not set.\n" .
         "Please set the path to your perl library as \$QUEUE_TYPE environmental variable.\n";
    $fail = 1;
}else {
    use lib $ENV{'PERL_LIB'};
    my $perl_lib = $ENV{'PERL_LIB'};
    eval {
        require Math::Vector::Real;
    }or do {
        warn "FATAL! cannot find Math::Vector::Real module anywhere," .
             " please install it under $perl_lib.";
        $fail = 1;
    };

    eval {
        require Math::MatrixReal;
    }or do{
        warn "FATAL! cannot find Math::Matrix module anywhere," .
             " please install it under $perl_lib.";
        $fail = 1;
    }
}

if ($ENV{'QCHASM'}) {
    my $QCHASM = $ENV{'QCHASM'};

    unless (-f "$QCHASM/AaronTools/template.job") {
        warn "WARNING! No template.job found in $QCHASM/AaronTools\n" .
             "While you can use most features of AaronTools without template.job\n" .
             "you will not be able to run AARON!\n" .
             "Please set up a template.job following the tutorial: https://github.com/QChASM/Aaron/wiki/Getting-Started-with-AARON-and-AaronTools\n";
        $fail = 0;
     }

     unless (-f "$QCHASM/Aaron/.aaronrc") {
        warn "WARNING! No .aaronrc file found in $QCHASM/Aaron for the group.\n" .
              "You are highly recommanded to make a custom .aaronrc file in $QCHASM/Aaron.\n" .
              "Otherwise, test 0007 will fail.\n";
        $fail = 0;
     }
}

my $HOME = $ENV{'HOME'};
unless (-f "$HOME/.aaronrc") {
    warn "WARNING! No custom keywords file .aaronrc found in your home directory.\n".
          "You are highly recommanded to make a custom .aaronrc file in $HOME for yourself.\n";
    $fail = 0;
}

if ($fail) {
    die "Required file missing!\n"
}

print "Test past!\n";
             


