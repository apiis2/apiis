##############################################################################
# $Id: ForeignKey.pm,v 1.21 2006/05/12 09:50:21 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::ForeignKey;
$VERSION = '$Revision: 1.21 $';
##############################################################################

=head1 NAME

ForeignKey

=head1 SYNOPSIS

Syntax in model file:

   ForeignKey fk_table fk_column [column=value]

=head1 DESCRIPTION

The internal data of the current table and column must have an according
entry in fk_table.fk_column.

Undefined data (NULL) does not violate the rule. It must be checked with
NotNull.

ForeignKey() returns 0 in case of success, otherwise it creates a
descriptive record error object and returns 1;

For internal en-/decoding, the ForeignKey rule is somehow violated with
additional parameters, which are not needed for the pure
FK-checking. If we have a FK-definition:

   ForeignKey codes db_code class=BREED

the FK-checking only looks in table codes, column db_code. The additional
'class=BREED' entry is used for the coding stuff.

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub ForeignKey {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;
    my $log_prefix = 'ForeignKey: ';
    my %error_args;
    my $running_check_integrity = $apiis->running_check_integrity;

    EXIT: {
        # check arguments of Model file:
        # $local_status = $self->check_ForeignKey( $col_name, @args );
        # last EXIT if $local_status;

        # do we have a valid ForeignKey rule?:
        my ( $fk_table, $fk_col ) = $self->column($col_name)->foreignkey;
        last EXIT if !defined $fk_table;

        # get the column data:
        my ( $extdata_ref, $extdata_string );
        if ( $running_check_integrity ) {
            # we only have internal data:
            $self->decode_column($col_name);
        }
        else {
            $self->encode_column($col_name);
            my $extdata_ref    = $self->column($col_name)->extdata;
            if ($extdata_ref) {
                # for error messages (to catch undef parts of extdata_ref:
                my @a;
                for my $a ( @{$extdata_ref} ) {
                    defined $a ? ( push @a, $a ) : push @a, 'undef';

                }
            }
            $extdata_string = 'undef' if !$extdata_string;
        }
        my $intdata        = $self->column($col_name)->intdata;

        if ( not defined $intdata or $intdata eq '' ) {
            last EXIT if $running_check_integrity;

            # This is intdata. If encode_column did not find a value via the
            # ForeignKey-rule, intdata will be empty/undef, but in this case
            # the FK-rule is violated. So we also have to check if extdata is
            # empty/undef.
            if (    $extdata_ref
                and defined $extdata_ref->[0]
                and $extdata_ref->[0] ne '' )
            {
                $local_status = 1;
                my %error_args = (
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'ForeignKey',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    data      => $extdata_string,
                    msg_short => __("ForeignKey violated"),
                    msg_long  => __(
                        "Data [_1] ([_2]) is not in [_3].[_4]",
                        $intdata, $extdata_string, $fk_table, $fk_col
                    ),
                );
                # add ext_fields to make forms happy:
                my $ext_fields_ref = $self->column($col_name)->ext_fields;
                if ($ext_fields_ref) {
                    $error_args{ext_fields} = $ext_fields_ref;
                }
                $self->errors( Apiis::Errors->new(%error_args) );
            }
            last EXIT;
        }

        $apiis->log( 'debug', sprintf "%s checking FK for %s.%s(%s) in %s.%s",
            $log_prefix, $self->name, $col_name, $intdata, $fk_table, $fk_col );

        my $fetch_record =
            Apiis::DataBase::Record->new( tablename => $fk_table, );
        $fetch_record->column($fk_col)->intdata($intdata);
        $fetch_record->column($fk_col)->encoded(1);

        my @fetched_records = $fetch_record->fetch(
            expect_columns => [$fk_col],
            user           => 'system',
        );
        last EXIT if scalar @fetched_records;    # success

        $local_status = 1;
        my %error_args = (
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'ForeignKey',
            db_table  => $self->tablename,
            db_column => $col_name,
            data      => $extdata_string,
            msg_short => __("Rule violated"),
            msg_long  => __(
                "Data [_1] ([_2]) is not in [_3].[_4]",
                $intdata, $extdata_string, $fk_table, $fk_col
            ),
        );

        my $ext_fields_ref = $self->column($col_name)->ext_fields;
        if ($ext_fields_ref) {
            $error_args{ext_fields} = $ext_fields_ref;
        }

        $self->errors( Apiis::Errors->new(%error_args) );
    }
    return $local_status || 0;
}

=head2 check_ForeignKey()

B<check_ForeignKey()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

=cut

sub check_ForeignKey {
   my ( $self, $col_name, @args ) = @_;
   my ( $fk_table, $fk_col, @rest ) = @args;
   my $local_status;
   unless ( $fk_table or $fk_col ) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'CONFIG',
            severity  => 'ERR',
            from      => 'ForeignKey',
            db_table  => $self->tablename,
            db_column => $col_name,
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __('FK-Table or TK-Column not defined'),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   foreach my $thisentry (@rest) {
      unless ( $thisentry =~ /[^\s]+=[^\s]+/ ) {
         $local_status = 1;
         my $err_id = $self->errors(
            Apiis::Errors->new(
               type      => 'CONFIG',
               severity  => 'ERR',
               from      => 'ForeignKey',
               db_table  => $self->tablename,
               db_column => $col_name,
               msg_short => __( 'Incorrect [_1] entry in model file', 'CHECK' ),
               msg_long  => __("Parameter after fk_table, fk_column incorrect, '=' missing"),
            )
         );
         $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
            if $self->column($col_name)->ext_fields;
      }
   }
   return $local_status;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

