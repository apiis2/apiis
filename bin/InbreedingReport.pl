#!/usr/bin/env perl
##############################################################################
# $Id: InbreedingReport.pl,v 1.31 2013/08/06 07:35:46 heli Exp $
# This is only a wrapper around those separate programs:
#     agr-extract_files
#     agr-shorten-infiles
#     agr-run_parallel
#     inbreeding_report
##############################################################################

BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use strict;
use warnings;

# just to test, if they exist, to get early errors:
use Apiis;
use Parallel::ForkManager;
use Data::Dumper;

# Command line parameters:
use vars qw(
    $opt_h $opt_u $opt_p $opt_P $opt_b $opt_I $opt_m $opt_t $opt_n $opt_e $opt_L
);
use Getopt::Std;
getopts('hu:p:P:b:I:m:n:e:tL:');

usage() if $opt_h;

# required parameters:
usage() if ! $opt_p;
usage() if ! $opt_u;
usage() if ! $opt_P;
usage() if ! $opt_b;

my $loginname = $opt_u;
my $passwd    = $opt_P;
my $breed     = $opt_b;

##############################################################################
my @programs = (qw/ agr-extract_files agr-shorten-infiles agr-run_parallel inbreeding_report /);

for my $prog (@programs) {
    my ( @params, %opts, @del_opts );

    # all optional parameters:
    $opts{'-p'} = $opt_p;
    $opts{'-u'} = $opt_u;
    $opts{'-P'} = $opt_P;
    $opts{'-b'} = $opt_b;
    $opts{'-n'} = $opt_n if $opt_n;
    $opts{'-m'} = $opt_m if $opt_m;
    $opts{'-I'} = $opt_I if $opt_I;
    $opts{'-e'} = $opt_e if $opt_e;
    $opts{'-t'} = undef if $opt_t;
    $opts{'-L'} = $opt_L if $opt_L;

    $prog eq 'agr-extract_files'   && ( @del_opts = (qw/ -n /) );
    $prog eq 'agr-shorten-infiles' && ( @del_opts = (qw/ -p -u -P -n -m -I -e -t -L /) );
    $prog eq 'agr-run_parallel'    && ( @del_opts = (qw/ -p -u -P -m -I -e /) );
    $prog eq 'inbreeding_report'   && ( @del_opts = (qw/ -t -n /) );
    delete $opts{$_} for @del_opts;
    push @params, $prog;
    for my $key ( keys %opts ){
        push @params, $key;
        push @params, $opts{$key} if defined $opts{$key};
    }

    printf "***** Starting program %s ...\n", $prog;
    sleep 1;
    system(@params) == 0 or die "Executing of program $prog failed: $?\n";
    printf "***** Program %s done.\n", $prog;
}

##############################################################################
sub usage {
    print "usage:\n"
      . "    -h    help, this message \n\n"
      . "    required:\n"
      . "    -p <project_name>\n"
      . "    -u <> database user\n"
      . "    -P <> database password\n"
      . "    -b <> breed\n\n"
      . "    optional:\n"
      . "    -n <> no of animals (agr-run_parallel)\n"
      . "    -m <> your table codes short_name for male, default is male\n"
      . "          (agr-extract_files)\n"
      . "    -e <> name of class for breed, default is BREED\n"
      . "    -I <> generation interval if you want a fixed generation, else\n"
      . "          the generation will be picked up from Population report\n"
      . "          (agr-extract_files)\n"
      . "    -L <> listfile for program output\n"
      . "    -t    creates a tar archive of all relevant files \n"
      . "          (agr-extract_files and agr-run_parallel)\n";
    die "\n";
}
