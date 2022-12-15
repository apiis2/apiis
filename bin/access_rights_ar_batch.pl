#!/usr/bin/env perl
##############################################################################
# $Id: access_rights_ar_batch.pl,v 1.3 2006/10/05 19:41:29 duchev Exp $
##############################################################################.

BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}
##############################################################################
use Data::Dumper;
use strict;
use warnings;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.3 $' );
use Apiis::Auth::AR_Init;
use Apiis::DataBase::User;
##############################################################################
my ($project_name) = parameters();
my $dummy = Apiis::DataBase::User->new(
				       id       => ($apiis->os_user || 'nobody'),
				       password => 'nopassword',
				      );
$apiis->join_model($project_name, userobj => $dummy, database =>0);

access_rights_ar_batch();
##############################################################################

=head2 parameters

  This subroutine takes parameters for the script

=cut

sub parameters{
   use vars qw( $opt_p $opt_h );
   use Getopt::Std;

   getopts('p:h'); # option -h  => Help
   my $project;

   if ($opt_h) 
   {
     print "\nNAME";
     print "\n              create_roles_conf.pl  - creates Roles.conf file.";
     print "\nSYNOPIS";
     print "\n              create_roles_conf.pl  [OPTIONS]";
     print "\nDESCRIPTION";
     print "\n            ";
     print "\nOPTIONS";
     print "\n              -p [project name]    - sets project name"; 
     print "\n              -h                - prints this help\n";
     print "\n";
     die();
   }
   elsif ($opt_p) 
   {
     $project = $opt_p;
   }
   else 
   { 
     print "\n!!!! Missing parameter !!!!"; 
     print "\nTry help with -h option\n"; 
     die();
   }

   return $project;
}
#########################################################################   

