#!/usr/bin/env perl

=head1

  standalone wrapper for the xml2model subroutine

=cut


BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use strict;
use warnings;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.20 $' );


use Getopt::Std;

use vars qw( $opt_h $opt_v); 

getopts('hv');
          # option -h  => Help
          #        -v  => Version

# Version:
die $apiis->programname . ': ' . $apiis->version . "\n" if $opt_v;

## help:
die __('xml2model.pl_USAGE_MESSAGE') if $opt_h or @ARGV < 1;

#parse XML and output model file, ARGV[0] is the project name

my $thisproject = $ARGV[0];
my $proj_apiis_local = $apiis->project($thisproject);
$apiis->APIIS_LOCAL($proj_apiis_local);
my $xml_file = $apiis->APIIS_LOCAL."/etc/".$thisproject.'.xml';
my $model_file = $apiis->APIIS_LOCAL."/etc/".$thisproject.'.model';

require XMLConversion;

xml2model($xml_file,$model_file);

#end
