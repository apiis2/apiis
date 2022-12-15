##############################################################################
# $Id: CondNotNull.pm,v 1.4 2006/05/26 09:58:34 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::CondNotNull;
$VERSION = '$Revision: 1.4 $';
##############################################################################

=head1 NAME

CondNotNull

=head1 SYNOPSIS

B<CondNotNull> checks, if one of two fields the data has a defined value

=head1 DESCRIPTION

The Rule B<CondNotNull> checkes the passed values of two columns from the same table in the model file if one of the two is defined or not empty. 

=head2 CondNotNull()

Syntax: CondNotNull column_name

Returnvalues:
   0 if one value is defined and nor empty, 1 otherwise
   errors are stored in $record->errors

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub CondNotNull {
    my ( $self, $col_name, $col_name2, @args ) = @_;
    my $local_status;
    my $data  = $self->column($col_name)->intdata;
    my $data2 = $self->column($col_name2)->intdata;
    EXIT: {
        last EXIT if $local_status =
            $self->check_CondNotNull( $col_name, $col_name2 );

        my $empty;
        if ( not defined $data and not defined $data2 ) {
            $empty = __('first undefined, second undefined');
        }
        elsif ( $data eq '' and $data2 eq '' ) {
            $empty = __('first empty, second empty');
        }
        elsif ( not defined $data and $data2 eq '' ) {
            $empty = __('first undefined, second empty');
        }
        elsif ( $data eq '' and not defined $data2 ) {
            $empty = __('first empty, second undefined');
        }

        if ($empty) {
            $local_status = 1;
            my $err_id = $self->errors(
                Apiis::Errors->new(
                    type       => 'DATA',
                    severity   => 'ERR',
                    from       => 'CondNotNull',
                    db_table   => $self->tablename,
                    db_column  => $col_name,
                    msg_long   => __( 'Passed values: [_1]', $empty ),
                    msg_short  => __(
                        '[_1] OR [_2] must not be NULL', $col_name,
                        $col_name2
                    ),
                )
            );
            my $ext_fields_ref = $self->column($col_name)->ext_fields;
            if ($ext_fields_ref) {
                $self->error($err_id)->ext_fields($ext_fields_ref);
            }
        }
    }
    return $local_status || 0;
}


=head2 check_CondNotNull()

B<check_CondNotNull()> checks if column_name exist

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

=cut

sub check_CondNotNull {
    my ( $self, $col_name, $col_name2 ) = @_;
    my $local_status;
    if ( not defined $self->column($col_name2) ) {
        $local_status = 1;
        my $err_id = $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'CondNotNull',
                db_table  => $self->tablename,
                db_column => "$col_name | $col_name2",
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'CHECK' ),
                msg_long  =>
                    __( 'Parameter [_1] is not a column name', $col_name2 ),
            )
        );
    }
    return $local_status || 0;
}

1;

=head1 AUTHORS

Hartmut Boerner <haboe@tzv.fal.de>

=cut
