##############################################################################
# $Id: NoCheck.pm,v 1.5 2005/01/24 13:19:25 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::NoCheck;
$VERSION = '$Revision: 1.5 $';
##############################################################################

=head1 NAME

NoCheck

=head1 SYNOPSIS

The Rule B<NoCheck> is checks nothing. It is intended to be a noop rule to
overwrite existing ones on a lower CHECK-level.

=head1 DESCRIPTION

=head2 NoCheck()

Syntax: NoCheck


Returnvalues:
   0 if data is within this range, 1 otherwise
   errors are stored in $record->errors

A non-true return value can only happen if the rule B<NoCheck> is defined
incorrectly in the model file, i.e. an additional parameter is provided.

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub NoCheck {
   my ( $self, $col_name, @args ) = @_;
   my $local_status = check_NoCheck( $col_name, @args );
   return $local_status || 0;
}

=head2 check_NoCheck()

B<check_NoCheck()> checks the correctness of the input parameters.

In case of errors it returns a non-true returnvalue.

Checks are:
   existence of additional parameters

=cut

sub check_NoCheck {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;

   if (@args) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'NoCheck',
            db_table  => $self->tablename,
            db_column => $col_name,
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __('[_1] does not accept parameters ([_2])',
                  'NoCheck', join ( ',', @args ) ),
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

