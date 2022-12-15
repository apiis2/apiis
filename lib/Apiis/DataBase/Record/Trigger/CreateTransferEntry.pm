##############################################################################
# $Id: CreateTransferEntry.pm,v 1.2 2007/08/09 09:39:02 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::CreateTransferEntry;

use strict;
use warnings;
our $VERSION = '$Revision: 1.2 $';

use Apiis;

sub CreateTransferEntry {
    my ($self) = @_;
    return if $self->tablename     ne 'animal';
    return if $self->action        ne 'insert';
    return if $self->triggeraction ne 'preinsert';
    return if $self->column('db_animal')->encoded;    # animal exists already

    EXIT: {
        my ( $ext_unit, $ext_id, $ext_animal ) =
            $self->column('db_animal')->extdata;
        last EXIT if !defined $ext_unit;
        last EXIT if !defined $ext_id;
        last EXIT if !defined $ext_animal;

        # get db_unit:
        my $unit = Apiis::DataBase::Record->new( tablename => 'unit', );
        $unit->column('ext_unit')->extdata($ext_unit);
        $unit->column('ext_id')->extdata($ext_id);
        my @q_units = $unit->fetch(
            expect_rows    => 'one',
            expect_columns => qw/ db_unit /,
        );
        my $q_unit  = shift @q_units;
        my $db_unit = $q_unit->column('db_unit')->intdata;
        last EXIT if !defined $db_unit;

        # now fill transfer record:
        my $transfer = Apiis::DataBase::Record->new( tablename => 'transfer', );
        $transfer->column('db_unit')->intdata($db_unit);
        $transfer->column('db_unit')->encoded(1);
        $transfer->column('ext_animal')->extdata($ext_animal);
        my $nextval = $apiis->DataBase->seq_next_val('seq_transfer__db_animal');
        $transfer->column('db_animal')->intdata($nextval);
        $transfer->column('db_animal')->encoded(1);
        my $now = $apiis->now;
        $transfer->column('opening_dt')->extdata($now);
        $transfer->column('entry_dt')->extdata($now);
        $transfer->insert;

        if ( $transfer->status ) {
            $self->status(1);
            $self->errors( scalar $transfer->errors );
            last EXIT;
        }
        # remove error status and errors of encode_record (db_animal):
        $self->status(0);
        $self->del_errors;
    }
    return;
}

##############################################################################

=head1 NAME

CreateTransferEntry

=head1 SYNOPSIS

Example entry in Model file:

   PREINSERT => ['CreateTransferEntry'],

=head2 CreateTransferEntry()

For a new entry in table animal, there must already exist a record in
transfer. When all data is provided with the animal Record object, the
new entry in transfer will be created automatically by B<CreateTransferEntry()>.

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

##############################################################################
1;
