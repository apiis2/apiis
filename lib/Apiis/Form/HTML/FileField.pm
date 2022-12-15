##############################################################################
# $Id: FileField.pm,v 1.1 2010-06-30 06:49:10 ulm Exp $
# Handling FileFields
##############################################################################
package Apiis::Form::HTML::FileField;
$VERSION = '$Revision $';
use warnings;
use strict;
use Data::Dumper;

=head1 NAME

Apiis::Form::HTML::FileField

=head1 DESCRIPTION

create a html filefield. The return value is valid html code.

=head1 METHODS

=head2 _filefield


=cut


sub _filefield {
   my ( $self, %args ) = @_;
   my $fieldname = $args{elementname};
   my $arg='';
   my $form_name=$self->{_form_list}->[0];
   my $vname=$self->GetValue( $fieldname, 'Name');
  
   my $d=$self->GetValue( $fieldname, 'Default') if ($self->GetValue( $fieldname, 'Default') and $self->GetValue( $fieldname, 'Default') ne '_lastrecord');
   if (${$self->GetValue( $fieldname, '_data_ref' )} ) {
     $d=${$self->GetValue( $fieldname, '_data_ref' )};
   } 
   $d='' if (! defined $d);
   my $label='';
   $arg.=' id="'. $vname .'"' if ($vname);
   $arg.=' name="'. $vname .'"' if ($vname);
   $arg.=' type="file"';
   #$arg.=' type="'. $self->GetValue( $fieldname, 'Type') .'"' if ($self->GetValue( $fieldname, 'Type'));
   $arg.=' size="'. $self->GetValue( $fieldname, 'Size') .'"' if ($self->GetValue( $fieldname, 'Size'));
   $arg.=' maxlength="'. $self->GetValue( $fieldname, 'MaxLength') .'"' if ($self->GetValue( $fieldname, 'MaxLength'));
   $arg.=' tabindex="'. ($self->GetValue( $fieldname, 'FlowOrder') ) .'"' if ($self->GetValue( $fieldname, 'FlowOrder'));
   $arg.=' override ="'. $self->GetValue( $fieldname, 'Override') .'"' if ($self->GetValue( $fieldname, 'Override'));
   $arg.=' value ="'. $d .'"';
   my $element=$self->GetValue( $fieldname, '_parent').'.'.$vname;
   if (! (($self->GetValue( $fieldname, 'Visibility') and ($self->GetValue( $fieldname, 'Visibility') eq 'hidden')) or 
          ($self->GetValue( $fieldname, 'Enabled')    and ($self->GetValue( $fieldname, 'Enabled')    eq 'no'    )))
      )  {
      $arg.=' onFocus="'."SetElement('$vname');javascript:void(0);".'"';
      $arg.=' onchange="'."checkField('$vname');javascript:void(0);".'"';
      $arg.=' onkeyup="'."Navigation(event.which,'$vname') ;javascript:void(0);".'"';
   }
   $label=$self->GetValue( $fieldname, 'Label') if ($self->GetValue( $fieldname, 'Label'));
   return "$label".'<Input '.$arg.'>';
}

1;
