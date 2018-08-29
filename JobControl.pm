package AaronTools::JobControl;

use strict; use warnings;
use lib $ENV{'QCHASM'};

use AaronTools::Constants qw(TEMPLATE_JOB);

use Exporter qw(import);
use Cwd qw(getcwd);

our @EXPORT = qw(findJob killJob submit_job count_time get_job_template);

my $QCHASM = $ENV{'QCHASM'};
$QCHASM =~ s|/\z||;	#Strip trailing / from $QCHASM if it exists

my $queue_type = $ENV{'QUEUE_TYPE'};

#Returns jobIDs of all jobs (queued or running) in current directory, returns 0 if no jobs in queue match current directory
#This could be improved by searching for $Path more carefully!
#Works for PBS, LSF, Slurm and soon SGE
sub findJob {
	my $Path = $_[0];
	chomp($Path);

	#Strip leading directories off of $Path, to deal with different ways $HOME is treated
	$Path =~ s/^\S+$ENV{USER}//;

	my @jobIDs;

	if($queue_type =~ /LSF/i) {				#LSF queue
		my $bjobs=`bjobs -l 2> /dev/null`;
		#Combine into one line with no whitespace
		$bjobs =~ s/\s+//g;
		$bjobs =~ s/\r|\n//g;

		#First grab all jobs
		my @jobs = ($bjobs =~ m/(Job<\d+>.*RUNLIMIT)/g);

		#parse each job looking for $Path
		foreach my $job (@jobs) {
			if ($job =~ /Job<(\d+)>\S+CWD<.+$Path>/) {
				push(@jobIDs,$1);
			}
		}
	}elsif ($queue_type =~ /PBS/i) {				#PBS
		my $qstat;

		# Catch queue server errors
		# Try later if communication issues
		while (1){
			$qstat = `qstat -fx 2>&1`;
			if ($qstat =~ /Unable to communicate/
			      || $qstat =~ /[Cc]annot connect/
			      || $qstat =~ /Connection refused/){
				print {*STDERR} "Queue error: ", $qstat;
				print {*STDERR} "Sleeping for 5 minutes...\n";
				sleep 300;
			} else {
				last;
			}
		}

		#First grab all jobs
		my @jobs = ($qstat =~ m/<Job>(.+?)<\/Job>/g);

		#Grab jobIDs for all jobs matching $Path
		foreach my $job (@jobs) {
			if ($job =~ m/<Job_Id>(\d+)\S+<job_state>[QR]\S+PBS_O_WORKDIR=\S+$Path</) {
				push(@jobIDs, $1);
			}
		}
	}elsif ($queue_type =~ /Slurm/i) {
		my @alljobs=`squeue -o %i_%Z -u $ENV{USER}`;
		foreach my $job (@alljobs) {
			if($job =~ /$Path/) {
				my @array = split(/_/, $job);
				push(@jobIDs,$array[0]);
			}
		}
	}elsif ($queue_type =~ /SGE/i) {
		my $qstat1 = `qstat -s pr -u $ENV{USER}`; #get qstat output for this user's jobs that are running/pending
		my @jobs = ($qstat1 =~ m/^\s*?(\w+)/gm); #get the first column of qstat data, which contains job IDs
		shift(@jobs); #the first line's first column is the header 'job-ID', so remove that
		my $jlist = join(',', @jobs); #join these on commas so we can ask qstat for more info about them

		my $qstat2 = `qstat -j $jlist`; #call qstat again, but this time get more info
		my @lines = split(/\n/, $qstat2); #split each line into an array
		my $job;

		foreach my $i (0..$#lines) {
			#it looks like job_number is always before the corresponding sge_o_workdir
			if( $lines[$i] =~ m/job_number:\s+(\d+)/ ) {
				$job = $1;
			}
			if( $lines[$i] =~ m/sge_o_workdir:\s+[\S]+$Path$/ ) {
				#this will return all your jobs if you run it in your home directory because $Path is ''
				push(@jobIDs, $job);
			}
		}
	}


	if(@jobIDs) {
		return @jobIDs;
	}
	return;
}


sub killJob {
    my ($job) = @_;

	my $rv;
    if ($queue_type =~ /LSF/i) {
        $rv = system("bkill $job");
    }elsif ($queue_type =~ /PBS/i) {
        $rv = system("qdel $job");
    }elsif ($queue_type =~ /Slurm/i) {
        $rv = system("scancel $job");
    }elsif ($queue_type =~ /SGE/i) {
        $rv = system("qdel $job >&/dev/null");
   }
   sleep(3);
   return $rv;
}


#Works for LSF, PBS, Slurm, and soon SGE
sub submit_job {
    my %params = @_;

    my ($dir, $com_file, $walltime,
        $numprocs, $template_job, $node) = ( $params{directory},
                                             $params{com_file},
                                             $params{walltime},
                                             $params{numprocs},
                                             $params{template_job},
                                             $params{node} );

    chomp(my $jobname=`basename $com_file .com`);
    my $jobfile = $dir ? "$dir/$jobname.job" : "$jobname.job";

    $dir //= getcwd();

    #if template_job were provide, use template_job to build job file
    if ($template_job->{job}) {

        my $job_file = $template_job->{job};

        my $job_found;

        my $template_pattern = TEMPLATE_JOB;

        open JOB_TEM, "<$job_file" or die "Cannot open $job_file:$!\n";
        my $job_content = do {local $/; <JOB_TEM>};
        close (JOB_TEM);

        $job_content =~ s/\Q$template_pattern->{JOB_NAME}/$jobname/g && do {$job_found = 1;};
        $job_content =~ s/\Q$template_pattern->{WALL_TIME}/$walltime/g;
        $job_content =~ s/\Q$template_pattern->{N_PROCS}/$numprocs/g;
        $job_content =~ s/\Q$template_pattern->{NODE_TYPE}/$node/g;
        #remove the formula part
        $job_content =~ s/&formula&\n(.*\n)*&formula&\n//g;

        for my $var (sort keys %{ $template_job->{formula} }) {
            my $var_value = eval($template_job->{formula}->{$var});
            $job_content =~ s/\Q$var/$var_value/g;
        }


        if ($job_found) {
            print "  Submitting $jobfile\n";
            open JOB, ">$jobfile" or die "cannot open $jobfile\n";
            print JOB $job_content;
            close (JOB);
        }
    }

    my $failed = 1;
    #Alert user if qsub (or bsub) returns error
    #FIXME

    if (-e $jobfile) {
        my $current = getcwd();
        $failed = 0;

        chdir($dir);
        if($queue_type =~ /LSF/i) {
            if(system("bsub < $jobname.job >& /dev/null")) {
                print {*STDERR} "Submission denied for $jobname.job!\n";
                $failed = 1;
            }
#Note: sbatch does not seem to return error codes for failed submissions
        } elsif($queue_type =~ /Slurm/i) {
            my $output = `sbatch < $jobname.job 2>&1`;
            if($output =~ /error/i) {
		print {*STDERR} "Submission denied for $jobname.job!\n";
                $failed = 1;
            }
        } elsif($queue_type =~ /PBS/i) {
            if(system("qsub $jobname.job >& /dev/null")) {
		print {*STDERR} "Submission denied for $jobname.job!\n";
                $failed = 1;
            }
        } elsif($queue_type =~ /SGE/i) {
            if(system("qsub $jobname.job >& /dev/null")) {
		print {*STDERR} "Submission denied for $jobname.job!\n";
                $failed = 1;
        	}
        }
        chdir($current);
    }
    return $failed;
} #end sub submit


sub count_time {
    my ($sleep_time) = @_;

    my $time = localtime;

    my $sleep_hour = int($sleep_time/60);
    my $sleep_minute = $sleep_time%60;

    if ($time =~ /\s(\d+)\:(\d+)/) {
        my $hour = $1 + $sleep_hour;
        my $minute = $2 + $sleep_minute;

        if ($minute > 60) {
            $hour += 1;
            $minute += $minute%60;
        }

        $time =~ s/\s\d+\:\d+/ $hour:$minute/;
    }

    return $time;
}


sub call_g09 {
    my %params = @_;

    my ($com_file, $walltime,
        $numprocs, $template_job,
        $node) = ($params{com_file}, $params{walltime}, $params{numprocs},
                  $params{template_job}, $params{node});

    chomp(my $jobname = `basename $com_file .com`);
    my $jobfile = "$jobname.job";

    my $shellfile = "$jobname.sh";

    unless (-e $shellfile) {

        open SHELL, ">$shellfile";

        my $template_pattern = TEMPLATE_JOB;

        my @job_command = @{$template_job->{command}};

        for my $command (@job_command) {
            $command =~ s/\Q$template_pattern->{JOB_NAME}/$jobname/g;
            $command =~ s/\Q$template_pattern->{WALL_TIME}/$walltime/g;
            $command =~ s/\Q$template_pattern->{N_PROCS}/$numprocs/g;
            $command =~ s/\Q$template_pattern->{NODE_TYPE}/$node/g;
            #remove the formula part
            $command =~ s/&formula&\n(.*\n)*&formula&\n//g;

            for my $var (sort keys %{ $template_job->{formula} }) {
                my $var_value = eval($template_job->{formula}->{$var});
                $command =~ s/\Q$var/$var_value/g;
            }

            next if ($command =~ /^exit/);
            print SHELL "$command\n";
        }
        close SHELL;

        chmod (0755, $shellfile);
    }

    my $walltime_sec = $walltime * 3600;
    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT\n" };
        alarm $walltime_sec;
        eval {
            system("timeout $walltime_sec sh $shellfile");
        };
        alarm 0;
    };
    alarm 0;

    if ($@) {
        die unless $@ eq "TIMEOUT\n";
    }
}


sub get_job_template {
    my $template_job = {};
    if ( -e "$QCHASM/AaronTools/template.job") {
        my $job_invalid;
        my $template_pattern = TEMPLATE_JOB;

        $template_job->{job} = "$QCHASM/AaronTools/template.job";
        $template_job->{formula} = {};
        $template_job->{env} = '';
        $template_job->{command} = [];

        open JOB, "<$QCHASM/AaronTools/template.job";
        #get formulas
        JOB:
        while (<JOB>) {
            /^\s*\#/ && do {$template_job->{env} .= $_; next;};

            /&formula&/ && do {
                while (<JOB>) {
                    /&formula&/ && last JOB;
                    /^(\S+)=(\S+)$/ && do {
                        my $formula = $2;
                        my @pattern = grep {$formula =~
                               /\Q$_\E/} values %$template_pattern;

                        unless (@pattern) {
                           print {*STDERR} "template.job in $QCHASM/AaronTools is invalid. " .
                                 "Formula expression is wrong. " .
                                 "Please see manual.\n";
                           $job_invalid = 1;
                           last;
                        }
                        $template_job->{formula}->{$1} = $2;
                    };
                }
                last if $job_invalid;
            };
            chomp( my $command = $_ );
            push (@{$template_job->{command}}, $command) unless ($command =~ /^$/);
        }
        chomp($template_job->{env});
        chomp($template_job->{command});
    }else {
        die "Cannot find template.job in $QCHASM/AaronTools folder.\n";
    }

    return $template_job;
}








1;
