##############################################################################
# $Id: ScrollingList.pm,v 1.24 2009-08-21 07:37:47 ulm Exp $
# Handling Scrollinglists
##############################################################################
package Apiis::Form::HTML::ScrollingList;
$VERSION = '$Revision $';
use warnings;
use strict;
use Data::Dumper;
use Apiis;

=head1 NAME

Apiis::Form::HTML::SrollingList

=head1 DESCRIPTION

create a html srollinglist. The return value is valid html code.

=head1 METHODS

=head2 _scrollinglist

needs two values. First value is the connection to datarecord, second value is a label for them. 

=cut

sub _scrollinglist {
    my ( $self, %args ) = @_;
    my $fieldname = $args{ elementname };
    my $arg       = '';
    my $list_ref;
    my $data_ref;
    my %thash;
    my $form_name = $self->{ _form_list }->[ 0 ];
    my $vname = $self->GetValue( $fieldname, 'Name' );

    my $translate_hash_ref
        = $self->GetValue( $fieldname, '_datasource_translate' );
    while ( my ( $key, $value ) = each %{ $translate_hash_ref } ) {
        $thash{ $key } = $translate_hash_ref->{ $key }->[ 0 ];
    }
    my %rh = reverse %thash;

    $data_ref = $self->GetValue( $fieldname, '_data_ref' );
    $list_ref = $self->GetValue( $fieldname, '_list_ref' );

    #-- data_ref and list_ref have different content -> link to one
    #

    $arg .= ' id="' . $vname . '"'   if ( $vname );
    $arg .= ' name="' . $vname . '"' if ( $vname );
    $arg
        .= ' tabindex="'
        . ( $self->GetValue( $fieldname, 'FlowOrder' ) ) . '"'
        if ( $self->GetValue( $fieldname, 'FlowOrder' ) );
    $arg .= ' size="' . $self->GetValue( $fieldname, 'Size' ) . '"'
        if ( $self->GetValue( $fieldname, 'Size' ) );
    $arg .= ' multiple '
        if ( $self->GetValue( $fieldname, 'SelectMode' ) eq 'multiple' );
    $arg .= ' disabled'
        if ( $self->GetValue( $fieldname, 'Enabled' ) eq 'no' );
    my $element
        = 'xf.' . $self->GetValue( $fieldname, '_parent' ) . '.' . $vname;

    if ( ( $self->GetValue( $fieldname, 'OnlyListEntries' )
           and ( $self->GetValue( $fieldname, 'OnlyListEntries' ) eq 'no' ) )
        )
    {
        $arg .= ' onlylistentries="no" ';
    }
    #$arg.=' onBlur="'."ErrorHandling($element)".'"';
    $arg .= ' onFocus="' . "SetElement('$vname');javascript:void(0);" . '"';
    $arg .= ' onchange="' . "checkField('$vname');javascript:void(0);" . '"';

    if ( ( $self->GetValue( $fieldname, 'ReduceEntries' )
           and ( $self->GetValue( $fieldname, 'ReduceEntries' ) eq 'yes' ) )
        )
    {
        my $t = 'left';
        $t = $self->GetValue( $fieldname, 'StartCompareString' )
            if ( $self->GetValue( $fieldname, 'StartCompareString' ) );
        $arg
            .= ' onkeyup="'
            . "ReduceEntries(event.which,'$vname','$t');javascript:void(0);"
            . '"';
    }
    else {
        $arg .= ' onkeyup="'
            . "Navigation(event.which,'$vname') ;javascript:void(0);" . '"';
    }

#   my $ds=$self->GetValue('Block_0','_datasource_list');
#   if ( $self->GetValue($ds->[0],'Connect') eq 'yes') {
#     $arg.=' onClick="FilterOnSelectedItem(this.form.'. $vname .
#                                           ',js.'.$self->{_form_list}[0].'.'.
#				           $self->GetValue($ds->[0],'Name').')" ';
#   }

#-- Test, whether a default-function is defined and is they connected to apiisrc
#   if yes then get the name of the default value and restore the value via name from $apiis
    my $default;
    if ( $self->GetValue( $fieldname, 'DefaultFunction' )
         and ( $self->GetValue( $fieldname, 'DefaultFunction' ) eq 'apiisrc' )
        )
    {
        $default = $apiis->{ '_' . $self->GetValue( $fieldname, 'Default' ) };
        $default =~ s/\'//g;
    }
    elsif ( $self->GetValue( $fieldname, 'DefaultFunction' )
         and ( $self->GetValue( $fieldname, 'DefaultFunction' ) eq 'today' ) )
    {
        $default = $apiis->today;
    }
    elsif ( $self->GetValue( $fieldname, 'Default' ) ) {
        $default = $self->GetValue( $fieldname, 'Default' );
    }

    my $notnull;
    $notnull = 1
        if ( lc( $self->GetValue( $fieldname, 'Check' ) ) eq 'notnull' );

    $arg = '<SELECT ' . $arg . '>';
    if ( !$notnull ) {
        $arg .= '<OPTION value=""></OPTION>';
    }

#-- loop over list_ref, because in list_ref all values sorted in the original sql manner
#
    foreach my $value ( @$list_ref ) {

        my $key;
        if ( %$translate_hash_ref ) {
            $key = $rh{ $value };
        }
        else {
            $key = $value;
        }
        $key = '' if ( !$key );

        if ( $default and ( $value eq $default ) ) {
            $arg
                .= '<OPTION SELECTED value="' 
                . $key . '">' 
                . $value
                . '</OPTION>';
        }
        else {
            $arg .= '<OPTION value="' . $key . '">' . $value . '</OPTION>';
        }
    }

    $arg .= '</SELECT>';
}

1;
