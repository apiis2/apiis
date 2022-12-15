##############################################################################
# $Id: SetNow.pm,v 1.1 2007/08/09 09:40:18 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::SetNow;

use strict;
use warnings;
our $VERSION = '$Revision: 1.1 $';

use Apiis;

sub SetNow {
   $_[0]->column( $_[1] )->extdata( $apiis->now );
   $_[0]->column( $_[1] )->updated( 1 );
}

##############################################################################

=head1 NAME

SetNow

=head1 SYNOPSIS

SetNow() returns the current date and time.

=head1 DESCRIPTION

SetNow() returns the current date and time. It is usually used as a
Trigger-rule in the model file. If you need the current time outside the
model file, better use $apiis->now().

=cut

##############################################################################
1;
