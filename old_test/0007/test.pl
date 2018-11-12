#!/usr/bin/env -S perl -w
use strict; use warnings;

my $failed_to_submit;
my $job_found;
my $failed_to_kill;
my $QCHASM = $ENV{'QCHASM'};
eval {
    use lib $ENV{'QCHASM'};
   
    use Aaron::G_Key;
    use AaronTools::JobControl qw(get_job_template submit_job findJob killJob);

    my $Gkey = new Aaron::G_Key;

    $Gkey->read_key_from_input();

    my $wall = $Gkey->{wall};
    my $n_procs = $Gkey->{n_procs};
    my $node = $Gkey->{node};

    my $template_job = get_job_template();

    $failed_to_submit = submit_job(
        com_file=>'test.com',
        walltime=>$wall,
        numprocs=>$n_procs,
        template_job=>$template_job,
        node=>$node);
    print "Submitting test job requesting $n_procs cores and a walltime of $wall hours...\n";

    sleep(10);

    ($job_found) = findJob("$ENV{PWD}");

    if($job_found) {
      print "Killing job $job_found...\n";
      killJob($job_found);
      sleep(5);
    }
    $failed_to_kill = findJob("$QCHASM/test/0007");
    1
} or do {
    my $error = $@;

    die "Error found in code: $error\n";
};


if ($failed_to_submit) {
    die "Test failed. Failed to submit test job to the queue.\nCheck test.job in this directory for errors and revise $QCHASM/AaronTools/template.job accordingly.\n"
}

unless ($job_found) {
    die "Test Failed. Cannot find job submitted to the queue. Please find the job and kill manually. Contact catalysttrends\@uga.edu to debug findjob.\n";
}

if ($failed_to_kill) {
    die "Test Failed. Cannot kill a job on the queue. Please kill the job manually. Contact catalysttrends\@uga.edu for assistance.\n";
}

print "Test passed!\nHowever, you should check test.job in this directory to make sure the number of cores and walltime matches the above and that the memory is correct.\n";
#Leave behind .job file to be checked manually
system("rm -fr test.log");



