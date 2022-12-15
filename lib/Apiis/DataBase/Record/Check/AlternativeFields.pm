##############################################################################
# $Id: AlternativeFields.pm,v 1.2 2008-01-17 19:18:58 duchev Exp $
##############################################################################
package Apiis::DataBase::Record::Check::AlternativeFields;
$VERSION = '$Revision: 1.2 $';
##############################################################################

=head1 NAME

AlternativeFields

=head1 SYNOPSIS

=head1 DESCRIPTION

The Rule B<AlternativeFields> expects a column name from the same table.
It then checks, if the both columns are empty or one of them is filled.

=head2 AlternativeFields()

Syntax: AlternativeFields column_name

Examples:AlternativeFields birth_year

Returnvalues:
   0 if comparison is OK, 1 if the both columns are filled
   errors are stored in $record->errors

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub AlternativeFields {
    my ( $self, $col_name, @args ) = @_;
    my $local_status = 0;
    my $data         = $self->column($col_name)->intdata;

    EXIT: {
        last EXIT
            if $local_status =
            $self->check_AlternativeFields( $col_name, @args );
        my $col_name2 = $args[0];
        my $stat;
        my $data2;
        $data2 = $self->column($col_name2)->intdata;
        last EXIT if ( ( not defined $data ) and ( not defined $data2 ) );
        if (    ( defined $data and $data ne '' )
            and ( defined $data2 and $data2 ne '' ) )
        {
            $local_status = 1;
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'AlternativeFields',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    data      => $data,
                    msg_short => __('Data error in CHECK rule'),
                    msg_long  => __(
                        "Only one of the alternative columns '[_1]' and '[_2]' can contain data ",
                        $col_name,
                        $col_name2
                    ),
                )
            );
            last EXIT;
        }
    }
    return $local_status || 0;
}

=head2 check_AlternativeFields()

B<check_AlternativeFields()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

Checks are:
           Number of parameters should be one
           The parameter should be column name from the same table.

=cut

sub check_AlternativeFields {
    my ( $self, $col_name, $col_name2 ) = @_;
    my $local_status;

    if ( not defined $col_name2 ) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'AlternativeFields',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'CHECK' ),
                msg_long => __('Parameter column_name is not defined'),
            )
        );
    }

    if ( not grep /^${col_name2}$/, $self->columns ) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'AlternativeFields',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'CHECK' ),
                msg_long =>
                    __( "Parameter '[_1]' is not a column name", $col_name2 ),
            )
        );
    }

    return $local_status || 0;
}

1;

=head1 BUGS

B<AlternativeFields> is not tested yet

=head1 AUTHORS

Zhivko Duchev duchev@tzv.fal.de

=cut

