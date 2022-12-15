##############################################################################
# $Id: IsANumber.pm,v 1.13 2005/03/01 12:32:19 soltys Exp $
##############################################################################
package Apiis::DataBase::Record::Check::IsANumber;
$VERSION = '$Revision: 1.13 $';
##############################################################################

=head1 NAME

IsANumber

=head1 SYNOPSIS

Checks, if the provided data is a number.

=head1 DESCRIPTION

=head2 IsANumber()

The value of the current column has to be a number.  Empty values are
allowed. The test is done by comparing firstly $value with $value+0 and, if
this fails, with a more complex regex.

Returnvalues:
   nothing in case of success
   local status with true value, errors are stored in $record->errors

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub IsANumber {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   EXIT: {
      last EXIT if $local_status = $self->check_IsANumber( $col_name, @args );
      my $data = $self->column($col_name)->intdata;
      last EXIT unless $self->_is_a_number( $data );

      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'IsANumber',
            data      => $data,
            db_column => $col_name,
            msg_short => __("Must be a number"),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   return $local_status || 0;
}

=head2 check_IsANumber()

B<check_IsANumber()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

Checks are:
   Existence of additional parameters

=cut

sub check_IsANumber {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   if (@args) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'IsANumber',
            db_column => $col_name,
            db_table  => $self->tablename,
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __('[_1] does not accept parameters ([_2])',
               'IsANumber',
               join ( ',', @args )
            ),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   return $local_status || 0;
}

=head2 _is_a_number() (internal)

B<_is_a_number()> is an internal routine which is not bind to the record
object. Some rules want to check the passed parameter (e.g. Range), if they
are numbers. B<_is_a_number()> gets as input the value, which it has to
check. B<IsANumber> uses B<_is_a_number()>, too.

In case of errors it returns a non-true returnvalue.

=cut

sub _is_a_number {
   my ( $self, $data ) = @_;

   EXIT: {
      no warnings qw(numeric);
      last EXIT if ( not defined $data );
      last EXIT if ( $data eq '' );
      last EXIT if ( $data + 0 eq $data );
      last EXIT if ( $data =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ );
      return 1;
   }
   return 0;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

__END__
##############################################################################


