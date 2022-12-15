##############################################################################
# $Id: NotSpaceOnly.pm,v 1.3 2008-01-18 12:29:30 duchev Exp $
##############################################################################
package Apiis::DataBase::Record::Check::NotSpaceOnly;
$VERSION = '$Revision: 1.3 $';
##############################################################################

=head1 NAME

NotSpaceOnly

=head1 SYNOPSIS

B<NotSpaceOnly> checks, if the data contains only space characters.

=head1 DESCRIPTION

B<NotSpaceOnly> checks if the passed data contains only spaces. NULL data (undefined or empty) will
pass successfully.

B<NotSpaceOnly> is usually used as a CHECK-rule in the model file.

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub NotSpaceOnly {
    my ( $self, $col_name ) = @_;

    my $local_status;
    EXIT: {
        last EXIT if $local_status = $self->check_NotSpaceOnly($col_name);
        my $data = $self->column($col_name)->intdata;

        last EXIT if not defined $data;
        last EXIT if $data eq '';

        if ( $data =~ /^\s*$/ ) {
            $local_status = 1;
            my $err_id = $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'NotSpaceOnly',
                    action    => $self->action || 'unknown',
                    db_column => $col_name,
                    db_table  => $self->tablename,
                    msg_short => __('Value must not contain only spaces'),
                    msg_long  => __( 'The passed value was: [_1]', $data ),
                )
            );
            my $ef_ref = $self->column($col_name)->ext_fields;
            if ($ef_ref) {
                $self->error($err_id)->ext_fields($ef_ref);
            }
        }
    }
    return $local_status || 0;
}

=head2 check_NotSpaceOnly

B<check_NotSpaceOnly> checks the correctness of the input parameters.
In case of errors it puts an error into $record->errors and returns a
non-true returnvalue.

Checks are:
   Existence of parameters

=cut

sub check_NotSpaceOnly {
    my ( $self, $col_name, @rest ) = @_;
    my $local_status;
    if (@rest) {
        $local_status = 1;
        my $err_id = $self->errors(
            Apiis::Errors->new(
                type      => 'DATA',
                severity  => 'ERR',
                from      => 'NotSpaceOnly',
                db_column => $col_name,
                db_table  => $self->tablename,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'CHECK' ),
                msg_long => __(
                    '[_1] does not accept parameters ([_2])',
                    'NotSpaceOnly',
                    join( ',', @rest )
                ),
            )
        );
        $self->error($err_id)
            ->ext_fields( $self->column($col_name)->ext_fields )
            if $self->column($col_name)->ext_fields;
    }
    return $local_status || 0;
}
1;

=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>

