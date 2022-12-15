##############################################################################
# $Id: CommaToDot.pm,v 1.3 2011-01-11 16:01:06 ulm Exp $
##############################################################################
package Apiis::DataBase::Record::Modify::CommaToDot;
$VERSION = '$Revision: 1.3 $';
##############################################################################

=head1 NAME

CommaToDot

=head1 SYNOPSIS

CommaToDot substitutes commas with dots.

=head1 DESCRIPTION

In some countries, e.g. Germany, often the comma is used as the decimal
separator of a number. The method CommaToDot simply changes the comma to
dot to satisfy the database.
CommaToDot() is usually used as a MODIFY-rule in the model file.

=cut

##############################################################################

use strict;
use warnings;

sub CommaToDot {

    #-- no action if empty 
    return if (!$_[0]->column( $_[1] )->extdata);

    my @data = map { tr/,/./; $_ } $_[0]->column( $_[1] )->extdata;
    $_[0]->column( $_[1] )->extdata(@data);
}

1;
