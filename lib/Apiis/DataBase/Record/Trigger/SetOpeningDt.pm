##############################################################################
# $Id: SetVersion.pm,v 1.9 2005/01/24 13:19:25 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::SetOpeningDt;
$VERSION = '$Revision: 1.9 $';

use strict;
use warnings;
use Apiis::Init;

##############################################################################

=head1 NAME

SetVersion

=head1 SYNOPSIS

Example entry in Model file:

   PREINSERT => ['SetOpeningDt'],

=head2 SetVersion()

=cut

sub SetOpeningDt {
   my ( $self, $col_name, @args ) = @_;
   return 1 if $self->check_SetOpeningDt( $col_name, @args );
   my $dat=$apiis->today();
   if ( $self->action eq "insert" ) {
      $self->column($col_name)->intdata($dat);
   }
}

=head2 check_SetOpeningDt()

B<check_SetVersion()> checks the correctness of the input parameters.
In case of errors it returns a non-true returnvalue.

=cut

sub check_SetOpeningDt {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   unless ( $col_name ){
      $local_status = 1;
      $self->errors(
         Apiis::Errors->new(
            type      => 'CONFIG',
            severity  => 'ERR',
            from      => 'SetVersion',
            db_table  => $self->tablename,
            msg_short => __('Incorrect [_1] entry in model file', 'TRIGGER'),
            msg_long  => __("Trigger [_1] needs a column name as parameter", 'SetOpeningDt'),
         )
      );
   }
   if ( @args ) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'CONFIG',
            severity  => 'WARNING',
            from      => 'SetVersion',
            db_table  => $self->tablename,
            db_column => $col_name,
            msg_short => __('Incorrect [_1] entry in model file', 'TRIGGER'),
            msg_long  => __("Trigger [_1] only needs a column name as parameter, not '[_2]'",
                         'SetVersion', join(',', @args) ),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   return $local_status || 0;
}

1;

=head1 AUTHORS

Ulf Müller <ulm@tzv.fal.de>
Helmut Lichtenberg <heli@tzv.fal.de>

=cut

