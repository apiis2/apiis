##############################################################################
# $Id: LowerCase.pm,v 1.2 2004/07/08 07:46:57 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Modify::LowerCase;
$VERSION = '$Revision: 1.2 $';
##############################################################################

=head1 NAME

LowerCase

=head1 SYNOPSIS

B<LowerCase()> converts the data to lower case

=head1 DESCRIPTION
It is usually used as a MODIFY-rule in the model file.

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

##############################################################################

use strict;
use warnings;

sub LowerCase {
   my @data = map { tr/A-Z/a-z/; $_ } $_[0]->column( $_[1] )->extdata;
   $_[0]->column( $_[1] )->extdata(@data);
}

1;
