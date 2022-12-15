##############################################################################
# $Id: $
##############################################################################
package Apiis::DataBase::Record::Trigger::SetExitTransfer;
$VERSION = '$Revision: 1.1 $';

use strict;
use warnings;
use Apiis::Init;

##############################################################################

=head1 NAME


=head1 SYNOPSIS


=head2 SetExitTransfer()


=cut

sub SetExitTransfer {
   my ( $self ) = @_;
   EXIT: {
      last EXIT if $self->action ne 'update';
      last EXIT if $self->triggeraction ne 'postupdate';
      last EXIT if !$self->column('culling_dt')->updated;
      my $cull_dt = $self->column('culling_dt')->extdata->[0]
      last EXIT if !$cull_dt;
      my $db_culling = $self->column('db_culling')->extdata->[0];
      last EXIT if !defined $db_culling or $db_culling eq '';
      my $et_record = Apiis::DataBase::Record->new( tablename => 'entry_transfer' );
      $et_record->column('db_animal')->intdata( $self->column('db_animal')->intdata );
      $et_record->column('db_animal')->encoded(1);
      my @q_records = $et_record->fetch(
         expect_columns => qw/ guid /,
      );
      for my $rec ( @q_records ){
          $rec->column('guid')->encoded(1);
          $rec->column('exit_dt')->extdata( $cull_dt );
          $rec->column('db_exit_action')->extdata( 'cull' ) if $db_culling == 2;
	  $rec->update;
      }
   }
   return;
}

1;

=head1 AUTHORS


=cut
