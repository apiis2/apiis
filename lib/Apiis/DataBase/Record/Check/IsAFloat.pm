##############################################################################
# $Id: IsAFloat.pm,v 1.8 2008-01-11 12:24:13 duchev Exp $
##############################################################################
package Apiis::DataBase::Record::Check::IsAFloat;
$VERSION = '$Revision: 1.8 $';
##############################################################################

=head1 NAME

IsAFloat

=head1 SYNOPSIS

The passed data must be a floating point number

=head1 DESCRIPTION

=head2 IsAFloat()

The value of the current column has to be a floating point number.  Empty
values are allowed.

Returnvalues:
   nothing in case of success
   local status with true value, errors are stored in $record->errors


=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub IsAFloat {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   EXIT: {
      last EXIT if $local_status = $self->check_IsAFloat( $col_name, @args );
      my $data = $self->column($col_name)->intdata;
      last EXIT
        if ( not defined $data )
        or ( $data eq '' )
        or $data =~ /^[+-]*(\d+\.?\d*|\.\d+)$/;    # match e.g. 47.5 or +.44
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'IsAFloat',
            db_column => $col_name,
            data      => $data,
            msg_short => __("Must be a float"),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;

   }
   return $local_status || 0;
}

=head2 check_IsAFloat()

B<check_IsAFloat()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

Checks are:
   Existence of additional parameters

=cut

sub check_IsAFloat {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   if (@args) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'IsAFloat',
            db_column => $col_name,
            db_table  => $self->tablename,
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __('[_1] does not accept parameters ([_2])',
               'IsAFloat',
               join ( ',', @args )
            ),
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

__END__

=head2 IsAFloat

The passed value $data is checked to be a float. The , is not substituted to
decimal point as this subroutine only return 0 or 1, not the (substituted)
value. This is a job for the Modify rule CommaToDot.

Returnvalues: 0 if $data is a legal float, 1 if $data contains illegal chars

=cut

