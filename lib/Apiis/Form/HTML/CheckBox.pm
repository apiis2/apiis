##############################################################################
# $Id: CheckBox.pm,v 1.11 2007/05/29 13:48:42 ulm Exp $
# Handling TextFields
##############################################################################
package Apiis::Form::HTML::CheckBox;
$VERSION = '$Revision $';
use warnings;
use strict;
use Data::Dumper;

=head1 NAME

Apiis::Form::HTML::CheckBox 

=head1 DESCRIPTION

create a html checkbox. The return value is valid html code.

=head1 METHODS

=head2 _checkbox

=cut
  

sub _checkbox {
   my ( $self, %args ) = @_;
   my $fieldname = $args{elementname};
   my $arg='';
   my $form_name=$self->{_form_list}->[0];
   my $vname=$self->GetValue( $fieldname, 'Name');
   
   my $d;
   if (${$self->GetValue( $fieldname, '_data_ref' )} ) {
     $d='ON';
   } else {  
     $d='ON' if ($self->GetValue( $fieldname, 'Checked') eq 'yes');
   } 
   $d='OFF' if (! $d);
   #$arg.=' class="'. $self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1] .'"' if ($self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1]);
   #$arg.=' class="'. $form_name.'_'.$self->GetValue( $fieldname, 'Name') .'"' if (! $self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1]);
   $arg.=' name="'. $self->GetValue( $fieldname, 'Name') .'"' if ($self->GetValue( $fieldname, 'Name'));
   $arg.=' id="'. $self->GetValue( $fieldname, 'Name') .'"' if ($self->GetValue( $fieldname, 'Name'));
   $arg.=' type="'. $self->GetValue( $fieldname, 'Type') .'"' if ($self->GetValue( $fieldname, 'Type'));
   $arg.=' value ="'. $d .'"';
   $arg.=' disabled' if ($self->GetValue( $fieldname, 'Enabled') eq 'no');
   $arg.=' checked ' if ($self->GetValue( $fieldname, 'Checked') eq 'yes');
   $arg.=' onFocus="'."SetElement('$vname');javascript:void(0);".'"';
   $arg.=' onkeyup="'."Navigation(event.which,'$vname') ;javascript:void(0);".'"';
   return '<Input '.$arg.'>';
}

1;
