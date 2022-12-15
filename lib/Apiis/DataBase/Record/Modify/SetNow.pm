##############################################################################
# $Id: SetNow.pm,v 1.3 2004/07/08 07:46:57 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Modify::SetNow;
$VERSION = '$Revision: 1.3 $';
##############################################################################

=head1 NAME

SetNow

=head1 SYNOPSIS

SetNow() returns the current date and time.

=head1 DESCRIPTION

SetNow() returns the current date and time. It is usually used as a
MODIFY-rule in the model file. If you need the current time outside the
model file, better use $apiis->now().

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub SetNow {
   $_[0]->column( $_[1] )->extdata( $apiis->now );
   $_[0]->column( $_[1] )->updated( 1 );
}

1;
