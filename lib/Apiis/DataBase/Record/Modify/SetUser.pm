##############################################################################
# $Id: SetUser.pm,v 1.4 2004/09/24 10:01:57 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Modify::SetUser;
$VERSION = '$Revision: 1.4 $';
##############################################################################

=head1 NAME

SetUser

=head1 SYNOPSIS

SetUser() returns the current user name.

=head1 DESCRIPTION

SetUser() sets the passed column extdata to the current user name. It is
usually used as a MODIFY-rule in the model file.

=cut

##############################################################################

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Apiis::Init;

sub SetUser {
   $_[0]->column( $_[1] )->extdata( $apiis->User->id );
   $_[0]->column( $_[1] )->updated( 1 );
}

1;
