#!/usr/bin/perl -w

# Test job submission and findjob

use strict;
use warnings;

use Test::More;

use lib $ENV{PERL_LIB};
my $QCHASM = $ENV{QCHASM};
$QCHASM =~ s/(.*)\/?/$1/;

# test loading package
eval {
    use lib $ENV{'QCHASM'};
    use AaronTools::JobControl qw(get_job_template submit_job findJob killJob getStatus);
    pass("Loaded packages");
    1;
} or do {
    fail("Failed to import Aaron package(s)");
    die $@;
};

# generate job file
my $wall = 2;
my $n_procs = 2;

my $template_job;
eval {
    $template_job = get_job_template();
    ok("Read job template");
    1;
} or do {
    fail("Could not get job template");
    die $@;
};

# submit job
my $submit_fail = submit_job( com_file     => 'test.com',
                              walltime     => $wall,
                              numprocs     => $n_procs,
                              template_job => $template_job );
ok( !$submit_fail, "Testing job submission" );
if ($submit_fail) {
    die "Failed to submit test job to the queue.\n"
      . "Check $QCHASM/Aaron/test/job_setup/test.job for errors and revise "
      . "$QCHASM/AaronTools/template.job accordingly.\n";
} else {
    diag(   "Submitting test job requesting $n_procs cores "
          . "and walltime of $wall hours..." );
    sleep(10);
}

# find job
my ($job_found) = findJob("$ENV{PWD}");
ok( $job_found, "Find job" );

# check job status
my $status = getStatus($job_found);
ok( $status =~ /[QR]/, "Job status: $status" );

# try to submit already submitted job (should fail)
my $submit_fail = submit_job( com_file     => 'test.com',
                              walltime     => $wall,
                              numprocs     => $n_procs,
                              template_job => $template_job );
ok($submit_fail, "Should not duplicate submission");

# kill job and verify it was killed
if ($job_found) {
	my $failed_to_kill;
    eval {
        my $status = killJob($job_found);
		# status is exit status of qdel, etc.
		# should be 0 if success, non 0 otherwise
        ok( !$status, "Kill job $job_found..." );
		($failed_to_kill) = findJob("$QCHASM/AaronTools/test/job_setup");
		# if job still found in the queue, FAIL
		# else, if $status != 0, FAIL
		# else, PASS
		$failed_to_kill ? 0 : 1 && !$status;
    } or do {
        fail(   "Cound not kill job submitted to the queue. "
              . "Please find the job and kill it manually. "
              . "Contact catalysttrends\@uga.edu for assistance."
        );
		if ( $failed_to_kill ){
			die "Could not kill $failed_to_kill\n";
		}
        die $@;
    };
} else {
	fail(   "Cound not find job submitted to the queue. "
			. "Please find the job and kill it manually. "
			. "Contact catalysttrends\@uga.edu for assistance."
	);
}

done_testing();

