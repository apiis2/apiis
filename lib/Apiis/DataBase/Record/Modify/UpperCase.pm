##############################################################################
# $Id: UpperCase.pm,v 1.5 2006/01/19 14:11:14 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Modify::UpperCase;
$VERSION = '$Revision: 1.5 $';
##############################################################################

=head1 NAME

UpperCase

=head1 SYNOPSIS

B<UpperCase()> converts the data to upper case

=head1 DESCRIPTION
It is usually used as a MODIFY-rule in the model file.

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

##############################################################################

use strict;
use warnings;

sub UpperCase {
    my ( $self, $column ) = @_;
    my $extdata_ref = $self->column($column)->extdata;
    return if !$extdata_ref;
    for (@$extdata_ref) {
        next if !defined $_;
        tr/a-z/A-Z/;
    }
    return;
}

1;

