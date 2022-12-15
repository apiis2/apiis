##############################################################################
# $Id: Image.pm,v 1.7 2006/11/26 20:40:10 ulm Exp $
# Handling Image
##############################################################################
package Apiis::Form::HTML::Image;
$VERSION = '$Revision $';
use warnings;
use strict;
use Data::Dumper;

=head1 NAME

Apiis::Form::HTML::Image

=head1 DESCRIPTION

create a html image. The return value is valid html code.

=head1 METHODS

=head2 _image

=cut


sub _image {
   my ( $self, %args ) = @_;
   my $fieldname = $args{elementname};
   my $arg='';
   my $form_name=$self->{_form_list}->[0];
   
   #$arg.=' class="'. $self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1] .'"' if ($self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1]);
   #$arg.=' class="'. $form_name.'_'.$self->GetValue( $fieldname, 'Name') .'"' if (! $self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1]);
   
   $arg.=' id="'. $self->GetValue( $fieldname, 'Name') .'"' if ($self->GetValue( $fieldname, 'Name'));
   $arg.=' name="'. $self->GetValue( $fieldname, 'Name') .'"' if ($self->GetValue( $fieldname, 'Name'));
   $arg.=' alt="'. $self->GetValue( $fieldname, 'Alt') .'"' if ($self->GetValue( $fieldname, 'Alt'));
   $arg.=' src ="'. $self->GetValue( $fieldname, 'Src') .'"' if ($self->GetValue( $fieldname, 'Src')) ;
   $arg.=' width ="'. $self->GetValue( $fieldname, 'Width') .'"' if ($self->GetValue( $fieldname, 'Width')) ;
   return '<img '.$arg.'>';
}

1;
