##############################################################################
# $Id: SetGuid.pm,v 1.7 2007/08/09 09:43:05 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::SetGuid;

use strict;
use warnings;
our $VERSION = '$Revision: 1.7 $';

use Apiis;

##############################################################################

=head1 NAME

SetGuid

=head1 SYNOPSIS

Example entry in Model file:

   PREINSERT => ['SetGuid guid'],

=head2 SetGuid()

=cut

sub SetGuid {
    my ( $self, $col_name, @args ) = @_;
    # return 1 if $self->check_SetGuid( $col_name, @args );

    if ( $self->action eq "insert" ) {
        if ( $self->triggeraction eq 'preinsert' ) {
            # this sequence is defined in table nodes
            # (maybe it is better to put it also in the configuration file):
            my $nextval = $apiis->DataBase->seq_next_val('seq_database__guid');
            $self->column($col_name)->intdata($nextval);
        }
    }
}

=head2 check_SetGuid()

B<check_SetGuid()> checks the correctness of the input parameters.
In case of errors it returns a non-true returnvalue.

=cut

sub check_SetGuid {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;

    unless ($col_name) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type     => 'CONFIG',
                severity => 'ERR',
                from     => 'SetGuid',
                db_table => $self->tablename,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] needs a column name as parameter", 'SetGuid'
                ),
            )
        );
    }
    if (@args) {
        $local_status = 1;
        my $err_id = $self->errors(
            Apiis::Errors->new(
                type      => 'CONFIG',
                severity  => 'WARNING',
                from      => 'SetGuid',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] only needs a column name as parameter, not '[_2]'",
                    'SetGuid',
                    join( ',', @args )
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

Zhivko Duchev <duchev@tzv.fal.de>
Helmut Lichtenberg <heli@tzv.fal.de>

=cut

