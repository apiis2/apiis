##############################################################################
# $Id: NoNumber.pm,v 1.8 2005/05/03 11:00:10 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::NoNumber;
$VERSION = '$Revision: 1.8 $';
##############################################################################

=head1 NAME

NoNumber

=head1 SYNOPSIS


=head1 DESCRIPTION

Checks, if the provided data is not a number.

=head2 NoNumber()

The value of the current column must not be a number.  Empty values are
allowed.

Returnvalues:
   * nothing in case of success
   * local status with true value in case of failure, errors are stored in
     $record->errors

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub NoNumber {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   EXIT: {
      last EXIT if $local_status = $self->check_NoNumber( $col_name, @args );
      my ($data) = $self->column($col_name)->intdata;
      last EXIT if not defined $data;
      last EXIT if $data eq '';
      require Apiis::DataBase::Record::Check::IsANumber;
      last EXIT if Apiis::DataBase::Record::Check::IsANumber->_is_a_number( $data );

      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'NoNumber',
            data      => $data,
            db_column => $col_name,
            msg_short => __("Must not be a number"),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   return $local_status || 0;
}

=head2 check_NoNumber()

B<check_NoNumber()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

Checks are:
   Existence of additional parameters

=cut

sub check_NoNumber {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   if (@args) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'NoNumber',
            db_column => $col_name,
            db_table  => $self->tablename,
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __('[_1] does not accept parameters ([_2])',
               'NoNumber', join ( ',', @args ) ),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   return $local_status || 0;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

