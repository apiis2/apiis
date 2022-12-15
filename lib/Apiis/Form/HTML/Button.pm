
##############################################################################
# $Id: Button.pm,v 1.16 2010/10/24 13:15:25 ulm Exp $
# Handling Buttons
##############################################################################
package Apiis::Form::HTML::Button;
$VERSION = '$Revision $';

use warnings;
use strict;
use Data::Dumper;
#use base 'Apiis::Form::HTML::Button';

=head1 NAME

Apiis::Form::HTML::Button -- Common subroutines for Button commands

=head1 DESCRIPTION

create a html button. The return value is valid html code.

=head1 METHODS 

=head2 _button

 do_clear -> reset button
 do_exit  -> submit button

=cut

sub _button  {
   my ( $self, %args ) = @_;
   my $fieldname = $args{elementname};
   my $query=$self->{_query};
   my $arg='';

   my $vfieldname=$self->GetValue( $fieldname, 'Name');
   my $vcommand=$self->GetValue( $fieldname, 'Command');
   my $url=$self->GetValue( $fieldname, 'URL');
   $url=$self->{_query}->param('g') if (! $url);
   $url=$self->xmlfile if (! $url);
   my $id=$self->GetValue( $fieldname,'Name');
   my $form_name=$self->{_form_list}->[0];
   my $form_counter=$self->{_formcounter};

   if ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_first_block')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doFirstRecord();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_prev_block')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doPrevRecord();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_next_block')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doNextRecord();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_last_block')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doLastRecord();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_query_block')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doQuery();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_clear_form')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doClearForm();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_reset')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doResetForm();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_delete')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doDeleteRecord();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_save')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doSaveForm();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_new_block')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doNewRecord();"></a>'; 
   } elsif ($self->GetValue( $fieldname, 'ButtonImage') and ($vcommand eq 'do_open_form')) {
     return '<a id="'.$id.'" href="javascript:void(0)" onclick="doFirstRecord();"></a>'; 
   }

   $arg.=' class="'. $self->{_style}->{$form_name.'_'.$vfieldname}->[1] .'"' if ($self->{_style}->{$form_name.'_'.$vfieldname}->[1]);
   $arg.=' class="'. $form_name.'_'.$vfieldname .'"' if (! $self->{_style}->{$form_name.'_'.$vfieldname}->[1]);

   $arg.=' tabindex="'. ($self->GetValue( $fieldname, 'FlowOrder') ) .'"' if ($self->GetValue( $fieldname, 'FlowOrder'));
   $arg.=' name="'. $vfieldname .'"' if ($vfieldname);
   $arg.=' id="'. $vfieldname .'"' if ($vfieldname);
   $arg.=' target="_blank"';
   if (($vcommand eq 'do_save') ) {
     $arg.=' type="button" onClick="Submit('."'".$vfieldname."'".')" ';
     $arg.=' alt="'.$url.'" ' if ($url);
   } elsif ($vcommand eq 'do_runevents') {
     $arg.=' type="button" onClick="doRunEvents('."'".$vfieldname."'".')" ';
   } elsif ($vcommand eq 'do_open_report') {
     $arg.=' type="button" onClick="OpenReport('."'".$vfieldname."'".",'F".$form_counter."'".')" ';
     $arg.=' alt="'.$url.'" ' if ($url);
   } elsif ($vcommand eq 'do_open_form') {
     $arg.=' type="button" onClick="OpenForm('."'".$vfieldname."'".",'F".$form_counter."'".')" ';
     $arg.=' alt="'.$url.'" ' if ($url);
   } elsif ($vcommand eq 'do_query_block') {
     $arg.=' type="button" onClick="Query('."'".$vfieldname."'".')" ';
     $arg.=' alt="'.$url.'" ' if ($url);
   } elsif ($vcommand eq 'do_exit')  {
     $arg.=' type="submit" ';
     $self->{_query}->param('g'=>$url);
   } elsif ($vcommand eq 'do_clear') { 
     $arg.=' type="reset"';
   }  

    if ($self->GetValue( $fieldname, 'ButtonLabel')) {
        my $label=$self->GetValue( $fieldname, 'ButtonLabel');

        #-- if translation
        if ($label=~/^__\('(.*)'\)/) {
    
            #-- translate
            $label=main::__($1);
        }

        $arg.=' value="'. $label .'"';
    }

   return '<Input '.$arg.'>';
}				

##############################################################################
1;
