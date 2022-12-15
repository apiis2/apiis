##############################################################################
# $Id: DotToColon.pm,v 1.2 2004/07/08 07:46:57 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Modify::DotToColon;
$VERSION = '$Revision: 1.2 $';
##############################################################################

=head1 NAME

DotToColon

=head1 SYNOPSIS

DotToColon substitutes dots with colons.

=head1 DESCRIPTION

B<DotToColon> is useful for fast typing of date/time values on numerical keyboards.

Example:
   16.34.00 ->  16:34:00

DotToColon() is usually used as a MODIFY-rule in the model file.

=cut

##############################################################################

use strict;
use warnings;

sub DotToColon {
   my @data = map { tr/./:/; $_ } $_[0]->column( $_[1] )->extdata;
   $_[0]->column( $_[1] )->extdata(@data);
}

1;
