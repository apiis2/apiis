#!/usr/bin/env perl

BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use strict;
use warnings;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.11 $' );

my $programname = $apiis->programname;

use vars qw( $opt_h $opt_v);

my ( @tables, $table, $col, $con, $subcon, $expr, @expr ); 

# allowed parameters:
use Getopt::Std;
getopts('hv');
                 # option -h  => Help
                 #        -v  => Version


## help:
die __('model2xml.pl_USAGE_MESSAGE') if($opt_h or @ARGV < 1 and !$opt_v);

# Version:
 die "$programname: ",$apiis->version,"\n" if $opt_v;

#ouput and writer objects - code agruments
 my $thisproject = $ARGV[0];
 my $proj_apiis_local = $apiis->project($thisproject);
 $apiis->APIIS_LOCAL($proj_apiis_local);
 my $xml_file = $apiis->APIIS_LOCAL."/etc/".$thisproject.'.xml';
 my $model_file = $apiis->APIIS_LOCAL."/etc/".$thisproject.'.model';
 my $model_short_name=$thisproject.'.model';
 $apiis->join_model($thisproject,database=>0);

 require XMLConversion;
 
 model2xml($model_file,$xml_file,$model_short_name);


