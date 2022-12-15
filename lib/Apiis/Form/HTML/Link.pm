##############################################################################
# $Id: Link.pm,v 1.10 2006/11/26 20:40:10 ulm Exp $
# Handling Link
##############################################################################
package Apiis::Form::HTML::Link;
$VERSION = '$Revision $';
use warnings;
use strict;
use Data::Dumper;

=head1 NAME

Apiis::Form::HTML::Link

=head1 DESCRIPTION

create a html link. The return value is valid html code.

=head1 METHODS

=head2 _link

collect parameter from browser to create a utilize link.

=cut

sub _link {
   my ( $self, %args ) = @_;
   my $fieldname = $args{elementname};
   my $arg='';
   my $form_name=$self->{_form_list}->[0];

   my $query=$self->{_query};
   my $opt_o=$query->param('o');
   my $opt_m=$query->param('m');
   my $opt_p=$query->param('sid');
   my $opt_u=$query->param('user');
   my $u;
   if ($self->GetValue( $fieldname, 'URL')=~/\.frm/) {
     $u="/cgi-bin/GUI?sid=$opt_p&formtype=apiisajaxg=".$self->GetValue( $fieldname, 'URL');
   } else {
     $u="/cgi-bin/GUI?sid=$opt_p&g=". $self->GetValue( $fieldname, 'URL');
   }
   my $d;
   if (${$self->GetValue( $fieldname, '_data_ref' )} ) {
     $d=${$self->GetValue( $fieldname, '_data_ref' )};
   } else {  
     $d=$self->GetValue( $fieldname, 'Default');
   } 
   $d='' if (! $d);
   my $label='';
   #$arg.=' class="'. $self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1] .'"' if ($self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1]);
   #$arg.=' class="'. $form_name.'_'.$self->GetValue( $fieldname, 'Name') .'"' if (! $self->{_style}->{$form_name.'_'.$self->GetValue( $fieldname, 'Name')}->[1]);
   $arg.=' id="'. $self->GetValue( $fieldname, 'Name') .'"' if ($self->GetValue( $fieldname, 'Name'));
   $arg.=' name="'. $self->GetValue( $fieldname, 'Name') .'"' if ($self->GetValue( $fieldname, 'Name'));
   $arg.=' href ="'. $u .'"';
   $arg.=' disabled' if ($self->GetValue( $fieldname, 'Enabled') eq 'no');
   $arg.=' target="_blank"';
   $label=$self->GetValue( $fieldname, 'LinkLabel') if ($self->GetValue( $fieldname, 'LinkLabel'));
   return '<a '.$arg. '>'.$label.'</a>';
}

1;
