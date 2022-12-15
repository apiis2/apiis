##############################################################################
# $Id: SetNode.pm,v 1.10 2007/08/09 09:43:05 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::SetNode;

use strict;
use warnings;
our $VERSION = '$Revision: 1.10 $';

use Apiis;

##############################################################################

=head1 NAME

SetNode

=head1 SYNOPSIS

Example entry in Model file:

   PREINSERT => ['SetNode owner'],

=head2 SetNode()

=cut

sub SetNode {
    my ( $self, $col_name, @args ) = @_;
    # Due to performance issues we should not check each rule at every
    # invokation, but this check should be kept for one-time checking of the
    # model file.
    # return 1 if $self->check_SetNode( $col_name, @args );

    my $marker = 'unknown';
    if ( lc $apiis->access_rights eq 'auth' ) {
        $marker = $apiis->User->user_node;    # old auth setup
    }
    elsif ( lc $apiis->access_rights eq 'ar' ) {
        $marker = $apiis->User->user_marker;    # new AR setup
    }
    $self->column($col_name)->intdata($marker);
}

=head2 check_SetNode()

B<check_SetNode()> checks the correctness of the input parameters.
In case of errors it returns a non-true returnvalue.

=cut

sub check_SetNode {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;
    unless ($col_name) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type      => 'CONFIG',
                severity  => 'ERR',
                from      => 'SetNode',
                db_table  => $self->tablename,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] needs a column name as parameter", 'SetNode'
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
                from      => 'SetNode',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] only needs a column name as parameter, not '[_2]'",
                    'SetNode', join( q{,}, @args ) ),
            )
        );
        my $ext_fields_ref = $self->column($col_name)->ext_fields;
        $self->error($err_id)->ext_fields($ext_fields_ref) if $ext_fields_ref;
    }
    return $local_status || 0;
}

1;

=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>
Helmut Lichtenberg <heli@tzv.fal.de>

=cut

