##############################################################################
# $Id: Submit.pm,v 1.8 2006/11/26 20:40:10 ulm Exp $
# Handling Buttons
##############################################################################
package Apiis::Form::HTML::Submit;
$VERSION = '$Revision $';

use warnings;
use strict;
use Data::Dumper;
use base 'Apiis::Form::HTML::Submit';

sub _submit {
   my ( $self, %args ) = @_;
   my $fieldname = $args{elementname};
   my $query=$self->{_query};
   my $arg='';
   my $form_name=$self->{_form_list}->[0];

   $query->delete('g');
   #print $query->hidden(-name=>'g',-default=>$self->GUIobj->$object->Src);
   #$arg.=' class="'. $self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1] .'"' if ($self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1]);
   #$arg.=' class="'. $form_name.'_'.$self->GetValue( $fieldname, 'Name') .'"' if (! $self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1]);
   $arg.=' id="'. $self->GetValue( $fieldname, 'Name') .'"' if ($self->GetValue( $fieldname, 'Name'));
   $arg.=' name="'. $self->GetValue( $fieldname, 'Name') .'"' if ($self->GetValue( $fieldname, 'Name'));
   $arg.=' disabled' if ($self->GetValue( $fieldname, 'Enabled') eq 'no');
   if ($self->GetValue( $fieldname, 'Command') eq 'do_exit') {
     $arg.=' type="submit"';
   } elsif ($self->GetValue( $fieldname, 'Command') eq 'do_clear') { 
     $arg.=' type="reset"';
   }   
   $arg.=' value="'. $self->GetValue( $fieldname, 'ButtonLabel') .'"' if ($self->GetValue( $fieldname, 'ButtonLabel'));
   return '<Input '.$arg.'>';
}				

##############################################################################
1;
