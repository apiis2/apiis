##############################################################################
# $Id: ReservedStrings.pm,v 1.7 2005/01/24 13:19:25 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::ReservedStrings;
$VERSION = '$Revision: 1.7 $';
##############################################################################

=head1 NAME

ReservedStrings

=head1 SYNOPSIS

B<ReservedStrings> checks, if the data contains strings, that are not
allowed as they are used e.g. as concatenation symbol.

=head1 DESCRIPTION

B<ReservedStrings> checks if the passed data contains one of the reserved
strings which are defined in apiisrc. NULL data (undefined or empty) will
pass successfully.

B<ReservedStrings> is usually used as a CHECK-rule in the model file.

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub ReservedStrings {
   my ( $self, $col_name ) = @_;

   my $local_status;
   EXIT: {
      last EXIT if $local_status = $self->check_ReservedStrings( $col_name );
      my $data = $self->column($col_name)->intdata;

      last EXIT if not defined $data;
      last EXIT if $data eq '';

      my @r_strings =
        map { ${ $apiis->reserved_strings }{$_} }
        keys %{ $apiis->reserved_strings };

      foreach my $thiskey (@r_strings) {
         if ( grep /$thiskey/, $data ) {
            $local_status = 1;
            my $err_id = $self->errors(
               Apiis::Errors->new(
                  type      => 'DATA',
                  severity  => 'ERR',
                  from      => 'ReservedStrings',
                  db_column => $col_name,
                  db_table  => $self->tablename,
                  data      => $data,
                  msg_short => __( 'reserved string [_1] used in data', $thiskey ),
               )
            );
            $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
               if $self->column($col_name)->ext_fields;
         }
      }
   }
   return $local_status;
}

=head2 check_ReservedStrings

B<check_ReservedStrings> checks the correctness of the input parameters.
In case of errors it puts an error into $record->errors and returns a
non-true returnvalue.

Checks are:
   Existence of parameters

=cut


sub check_ReservedStrings {
   my ( $self, $col_name, @rest ) = @_;
   my $local_status;
   if (@rest) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            from      => 'ReservedStrings',
            db_column => $col_name,
            db_table  => $self->tablename,
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __('[_1] does not accept parameters ([_2])',
               'ReservedStrings', join ( ',', @rest )
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

