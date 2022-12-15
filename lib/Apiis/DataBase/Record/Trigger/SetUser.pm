##############################################################################
# $Id: SetUser.pm,v 1.1 2007/08/09 09:40:18 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::SetUser;

use strict;
use warnings;
our $VERSION = '$Revision: 1.1 $';

use Apiis;

sub SetUser {
   $_[0]->column( $_[1] )->extdata( $apiis->User->id );
   $_[0]->column( $_[1] )->updated( 1 );
}

##############################################################################

=head1 NAME

SetUser

=head1 SYNOPSIS

SetUser() returns the current user name.

=head1 DESCRIPTION

SetUser() sets the passed column extdata to the current user name. It is
usually used as a Modify-rule or Trigger in the model file.

=cut

##############################################################################
1;
