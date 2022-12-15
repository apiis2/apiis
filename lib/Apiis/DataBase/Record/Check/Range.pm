##############################################################################
# $Id: Range.pm,v 1.13 2006/01/11 10:02:00 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::Range;
$VERSION = '$Revision: 1.13 $';
##############################################################################

=head1 NAME

Range

=head1 SYNOPSIS

=head1 DESCRIPTION

The Rule B<Range> is given a range of values in the model file. It then
checks, if the provided data is within this range.

=head2 Range()

Syntax: Range min_value max_value

Is the data within a range? min_value and max_value are predefined in the
model file.

Returnvalues:
   0 if data is within this range, 1 otherwise
   errors are stored in $record->errors

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub Range {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   my $data = $self->column($col_name)->intdata;
   if ( defined $data and $data ne '' ) {
      EXIT: {
         require Apiis::DataBase::Record::Check::IsANumber;
         last EXIT if $local_status = $self->check_Range( $col_name, @args );
         my ( $min, $max ) = @args;
         if ( Apiis::DataBase::Record::Check::IsANumber->_is_a_number($data) ) {
            $local_status = 1;
            my $err_id = $self->errors(
               Apiis::Errors->new(
                  type      => 'DATA',
                  severity  => 'ERR',
                  from      => 'Range',
                  db_table  => $self->tablename,
                  db_column => $col_name,
                  action    => $self->action || 'unknown',
                  record_id => $self->column($apiis->DataBase->rowid)->intdata,
                  data      => $data,
                  msg_short => __('Data error in CHECK rule'),
                  msg_long  => __( "Parameter '[_1]' is not a number", $data ),
               )
            );
            $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
               if $self->column($col_name)->ext_fields;
            last EXIT;
         }

         if ( $data > $max or $data < $min ) {
            $local_status = 1;
            my $err_id = $self->errors(
               Apiis::Errors->new(
                  type      => 'DATA',
                  severity  => 'ERR',
                  from      => 'Range',
                  db_table  => $self->tablename,
                  db_column => $col_name,
                  action    => $self->action || 'unknown',
                  record_id => $self->column($apiis->DataBase->rowid)->intdata,
                  data      => $data,
                  msg_short => __('Data error in CHECK rule'),
                  msg_long  => __("Data '[_1]' exceeds Range limits '[_2]'",
                     $data, "$min <=> $max" ),
               )
            );
            $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
               if $self->column($col_name)->ext_fields;
         }
      }
   }
   return $local_status || 0;
}

=head2 check_Range()

B<check_Range()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

Checks are:
   if min_value and max_value are defined
   if min_value and max_value are numbers

=cut

sub check_Range {
   my ( $self, $col_name, $min, $max ) = @_;
   my $local_status;

   if ( not defined $min or not defined $max ) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'Range',
            db_table  => $self->tablename,
            db_column => $col_name,
            action    => $self->action || 'unknown',
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __('Parameter min or max is not defined'),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }

   if ( Apiis::DataBase::Record::Check::IsANumber->_is_a_number($min)
        or Apiis::DataBase::Record::Check::IsANumber->_is_a_number($max) ) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'Range',
            db_table  => $self->tablename,
            db_column => $col_name,
            action    => $self->action || 'unknown',
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __("Parameter '[_1],[_2]' is not a number", $min, $max),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   return $local_status || 0;
}

1;

=head1 BUGS

B<Range> is intended to work only for numerical values.

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

