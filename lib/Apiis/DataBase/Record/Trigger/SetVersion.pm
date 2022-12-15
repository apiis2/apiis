##############################################################################
# $Id: SetVersion.pm,v 1.10 2007/08/09 09:43:05 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::SetVersion;

use strict;
use warnings;
our $VERSION = '$Revision: 1.10 $';

use Apiis;

##############################################################################

=head1 NAME

SetVersion

=head1 SYNOPSIS

Example entry in Model file:

   PREINSERT => ['SetVersion version'],

=head2 SetVersion()

=cut

sub SetVersion {
    my ( $self, $col_name, @args ) = @_;
    # return 1 if $self->check_SetVersion( $col_name, @args );

    if ( $self->action eq "insert" ) {
        $self->column($col_name)->intdata(1);
    }
    elsif ( $self->action eq "update" ) {
        my $sqltext = sprintf "SELECT %s FROM %s WHERE %s = %s",
            $col_name,
            $self->tablename,
            $apiis->DataBase->rowid,
            $apiis->DataBase->dbh->quote(
                $self->column( $apiis->DataBase->rowid )->intdata
            );
        my $sql_ref    = $apiis->DataBase->sys_sql($sqltext);
        my $status     = $sql_ref->status;
        my $arr_ref    = $sql_ref->handle->fetch;
        my $oldversion = $arr_ref->[0];
        $self->column($col_name)->intdata( ++$oldversion );
        $self->column($col_name)->updated(1);
    }
}

=head2 check_SetVersion()

B<check_SetVersion()> checks the correctness of the input parameters.
In case of errors it returns a non-true returnvalue.

=cut

sub check_SetVersion {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;
    unless ($col_name) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type     => 'CONFIG',
                severity => 'ERR',
                from     => 'SetVersion',
                db_table => $self->tablename,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] needs a column name as parameter",
                    'SetVersion'
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
                from      => 'SetVersion',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] only needs a column name as parameter, not '[_2]'",
                    'SetVersion',
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

