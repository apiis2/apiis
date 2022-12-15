##############################################################################
# $Id: SetColumn.pm,v 1.2 2007-08-09 09:43:05 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::SetColumn;

use strict;
use warnings;
our $VERSION = '$Revision: 1.2 $';

use Apiis;

##############################################################################

=head1 NAME

SetColumn

=head1 SYNOPSIS

Example entry in Model file:

   PREINSERT => ['SetColumn <column_name> <sequence_name>'],

=head2 SetColumn()

B<SetColumn()> sets the passed column to the next value of the passed
database sequence.

=cut

sub SetColumn {
    my ( $self, $col_name, $sequence ) = @_;
    # return 1 if $self->check_SetColumn( $col_name, $sequence );

    return if $self->action        ne "insert";
    return if $self->triggeraction ne 'preinsert';

    my $nextval = $apiis->DataBase->seq_next_val($sequence);
    $self->column($col_name)->intdata($nextval);
}

=head2 check_SetColumn()

B<check_SetColumn()> checks the correctness of the input parameters.
In case of errors it returns a non-true returnvalue.

=cut

sub check_SetColumn {
    my ( $self, $col_name, $sequence ) = @_;
    my $local_status;
    unless ($col_name) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type     => 'CONFIG',
                severity => 'ERR',
                from     => 'SetColumn',
                db_table => $self->tablename,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] needs a column name as first parameter",
                    'SetColumn'
                ),
            )
        );
    }
    if ( !$sequence ) {
        $local_status = 1;
        my $err_id = $self->errors(
            Apiis::Errors->new(
                type      => 'CONFIG',
                severity  => 'WARNING',
                from      => 'SetColumn',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] needs a sequence name as second parameter",
                    'SetColumn'
                ),
            )
        );
        if ( my $ef_ref = $self->column($col_name)->ext_fields ) {
            $self->error($err_id)->ext_fields($ef_ref);
        }
    }
    return $local_status || 0;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>
Zhivko Duchev <duchev@tzv.fal.de>

=cut
