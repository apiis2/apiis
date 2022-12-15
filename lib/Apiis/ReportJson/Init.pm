#############################################################################
# $Id: Init.pm,v 1.10 2004/11/26 13:56:35 ulm Exp $
##############################################################################
# This Init package provides common methods for either Tk or Web:
#
# method    invocation              description
# fullname  $apiis->Report->fullname   gives back the full name of the reports file
# basename  $apiis->Report->basename   gives back the base name of the reports file
# path      $apiis->Report->path       gives back the path of the reports file
# ext       $apiis->Report->ext        gives back the extension of the reports file
# uncomplete list, have a look into test.Report
##############################################################################

package Apiis::ReportJson::Init;
$VERSION = '$Revision $';

use strict;
use Carp;
use warnings;
use Apiis::Errors;
use Data::Dumper;

#@Apiis::Report::Init::ISA = qw( Apiis::Init );
#our $apiis;

sub new {
   my ( $invocant, %args ) = @_;
   
   my $class = ref($invocant) || $invocant;
   my $self  = bless {}, $class;

   #-- predefine functions 
   $self->_init(%args);
   
   return $self;
}

##############################################################################
sub _init {
   my ( $self, %args ) = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++;    # Conway p. 243

   #-- dummy functions
   foreach my $thiskey (qw/ PrintReport/) {
      no strict "refs";
      *{$thiskey} = sub { return undef };
   }

}
1;
