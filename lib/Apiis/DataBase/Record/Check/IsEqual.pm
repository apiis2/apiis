##############################################################################
# $Id: IsEqual.pm,v 1.15 2006/03/28 13:50:25 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::IsEqual;
$VERSION = '$Revision: 1.15 $';
# see POD at end of file
##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub IsEqual {
    my ( $self, $col_name, @args ) = @_;
    my ( $local_status, @errors );
    my $log_prefix = 'IsEqual:';

    EXIT: {
        last EXIT if $local_status = $self->check_IsEqual( $col_name, \@args );
        my ( $fk_table, $fk_col, $comp_col, $comp_val, $add_arg1 ) = @args;
        $apiis->log('debug', sprintf "%s starting IsEqual for %s",
            $log_prefix,
            "$fk_table.$fk_col->$comp_col = $comp_val"
        );

        my $intdata     = $self->column($col_name)->intdata;
        if ( !defined $intdata ) {
            $apiis->log( 'debug', sprintf "%s we have to encode column %s",
                $log_prefix, $col_name );
            $self->encode_column( { column => $col_name } );
            $intdata = $self->column($col_name)->intdata;
        }
        last EXIT unless defined $intdata;

        # create new record for query:
        my $rec = Apiis::DataBase::Record->new( tablename => $fk_table );
        $rec->column($fk_col)->intdata( $intdata );
        $rec->column($fk_col)->encoded(1);
        my @q_records = $rec->fetch(
            expect_rows    => 'one',
            expect_columns => [$comp_col],
            user           => 'system',
        );

        if ( !@q_records ) {
            if ( defined $add_arg1 and lc $add_arg1 eq 'nullok' ) {
                $local_status = 0;
                $apiis->log( 'debug', sprintf
                    "%s no record to compare, but passed due to parameter '%s'",
                    $log_prefix, 'nullok'
                );
            }
            else {
                $local_status = 1;
                $self->decode_column( { column => $col_name } );
                my $extdata_ref = $self->column($col_name)->extdata;
                push @errors, Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'IsEqual',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    data      => join( ',', @$extdata_ref ),
                    msg_short => __('Rule violated'),
                    msg_long  => __('no record found to compare with'),
                );
            }
            last EXIT;
        }
        else {
            # only take one (the first) record:
            my $record = $q_records[0];
            $record->decode_column( { column => $comp_col } );
            # could only be one scalar value:
            my ($db_comp_val) = $record->column($comp_col)->extdata;

            if ( !defined $db_comp_val ) {
                $local_status = 1;
                $self->decode_column( { column => $col_name } );
                my $extdata_ref = $self->column($col_name)->extdata;
                push @errors, Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'IsEqual',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    data      => join( ',', @$extdata_ref ),
                    msg_short => __('Rule violated'),
                    msg_short => __( 'passed value: [_1], compared value: [_2]',
                                    $comp_val, 'NULL' ),
                );
                last EXIT;
            }

            if ( $db_comp_val ne $comp_val ) {
                $local_status = 1;
                $self->decode_column( { column => $col_name } );
                my $extdata_ref = $self->column($col_name)->extdata;
                push @errors, Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'IsEqual',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    data      => join( ',', @$extdata_ref ),
                    msg_short => __('Rule violated'),
                    msg_short => __(
                        'passed value: [_1], compared value: [_2]', $comp_val,
                        $db_comp_val
                    ),
                );
                last EXIT;
            }
            $local_status = 0;
            $apiis->log( 'debug',
                sprintf "%s record found and comparison ok for %s",
                $log_prefix, $self->tablename . q{ } . $col_name );
        }
    }    # end label EXIT

    if ($local_status) {
        if ( my $ext_fields_ref = $self->column($col_name)->ext_fields ) {
            for my $err (@errors) {
                $err->ext_fields($ext_fields_ref);
            }
        }
        $self->errors( \@errors );
    }
    return $local_status || 0;
}

sub check_IsEqual {
    my ( $self, $col_name, $args_ref ) = @_;
    my ( $fk_table, $fk_col, $comp_col, $comp_val, $add_arg1 ) = @$args_ref;
    unless ( $fk_table or $fk_col or $comp_col or defined $comp_val ) {
        $self->errors(
            Apiis::Errors->new(
                type      => 'CONFIG',
                severity  => 'ERR',
                from      => 'IsEqual',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
                msg_long  => __("Parameters missing"),
            )
        );
        return 1;
    }
    if ( defined $add_arg1 and $add_arg1 ne 'nullok' ){
        $self->errors(
            Apiis::Errors->new(
                type      => 'CONFIG',
                severity  => 'ERR',
                from      => 'IsEqual',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
                msg_long  => __("Last parameter can only be 'nullok'"),
            )
        );
        return 1;
    }
    return;
}

1;

__END__

=head1 NAME

IsEqual

=head1 SYNOPSIS

Syntax: IsEqual $table $id_column $column compare_constant [nullok]

=head1 DESCRIPTION

B<IsEqual()> is usually used as a CHECK-rule in the model file.

It checks, if a record, identified by $table.$id_column has the value
'compare_constant' in column $column.

Example: IsEqual animal db_animal db_sex male

This CHECK-rule can be attached to a column like db_sire in
service and tests if the animal ID, given in the passed column, points indeed
to a male animal. The record from table animal, where db_animal is equal to
the data of the current column, must have an entry 'male' in column db_sex.
The the 'compare_constant' part is a fixed value and specified as external code
(codes.ext_code).

Returnvalues:

=over 4

=item 0

0 if the retrieved record from $table.$id_column has an entry of
'compare_constant' in column $column.

If the optional parameter 'nullok' is given, an undefined value for this
column (or no retrieved record) will also be accepted.

=item 1

All other cases indicate error and an error message exists.

=back


=head2 check_IsEqual()

B<check_IsEqual()> checks the correctness of the input parameters.

In case of errors it puts an error into $self->errors and additionally
returns a non-true returnvalue.

Checks are:

   Missing parameters
   Last parameter must be 'nullok' if it exists


=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=head1 VERSION

   $Revision: 1.15 $
