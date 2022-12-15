##############################################################################
# $Id: TextField.pm,v 1.18 2013/03/06 20:18:46 ulm Exp $
# Handling TextFields
##############################################################################
package Apiis::Form::HTML::TextField;
$VERSION = '$Revision $';
use warnings;
use strict;
use Data::Dumper;
use Apiis;

=head1 NAME

Apiis::Form::HTML::TextField

=head1 DESCRIPTION

create a html textfield. The return value is valid html code.

=head1 METHODS

=head2 _textfield


=cut

sub _textfield {
    my ( $self, %args ) = @_;
    my $fieldname = $args{elementname};
    my $arg       = '';
    my $form_name = $self->{_form_list}->[0];
    my $vname     = $self->GetValue( $fieldname, 'Name' );

    if ( $vname eq '__nav_r' ) {
        return '<input id="__nav_r" name="__nav_r" onChange="MoveRec()" type="textfield" maxlength="6" size="9">';
    }
    my $default = $self->GetValue( $fieldname, 'Default' )
        if ( $self->GetValue( $fieldname, 'Default' ) and $self->GetValue( $fieldname, 'Default' ) ne '_lastrecord' );

    if ( $self->GetValue( $fieldname, 'DefaultFunction' ) and ( $self->GetValue( $fieldname, 'DefaultFunction' ) eq 'today' ) )
    {
#        $default = $apiis->today;
    }

    if ( ${ $self->GetValue( $fieldname, '_data_ref' ) } ) {
        $default = ${ $self->GetValue( $fieldname, '_data_ref' ) };
    }
    $default = '' if ( !defined $default );
    my $label = '';
    $arg .= ' id="' . $vname . '"'   if ($vname);
    $arg .= ' name="' . $vname . '"' if ($vname);
    if ( $self->GetValue( $fieldname, 'Password' ) eq 'yes' ) {
        $arg .= ' type="password"';
    }
    else {
        $arg .= ' type="' . $self->GetValue( $fieldname, 'Type' ) . '"' if ( $self->GetValue( $fieldname, 'Type' ) );
    }

    $arg .= ' size="' . $self->GetValue( $fieldname, 'Size' ) . '"' if ( $self->GetValue( $fieldname, 'Size' ) );
    $arg .= ' maxlength="' . $self->GetValue( $fieldname, 'MaxLength' ) . '"'
        if ( $self->GetValue( $fieldname, 'MaxLength' ) );
    $arg .= ' tabindex="' . ( $self->GetValue( $fieldname, 'FlowOrder' ) ) . '"'
        if ( $self->GetValue( $fieldname, 'FlowOrder' ) );
    $arg .= ' override ="' . $self->GetValue( $fieldname, 'Override' ) . '"'
        if ( $self->GetValue( $fieldname, 'Override' ) );
    $arg .= ' readonly' if ( $self->GetValue( $fieldname, 'Enabled' ) eq 'no' );
    $arg .= ' value ="' . $default . '"';
    my $element = $self->GetValue( $fieldname, '_parent' ) . '.' . $vname;

    if (!(  (   $self->GetValue( $fieldname, 'Visibility' )
                and ( $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden' )
            )
            or ( $self->GetValue( $fieldname, 'Enabled' ) and ( $self->GetValue( $fieldname, 'Enabled' ) eq 'no' ) )
        )
        )
    {
        $arg .= ' onFocus="' . "SetElement('$vname');javascript:void(0);" . '"';
        $arg .= ' onchange="' . "checkField('$vname');javascript:void(0);" . '"';
        $arg .= ' onkeyup="' . "Navigation(event.which,'$vname') ;javascript:void(0);" . '"';
    }
    $label = $self->GetValue( $fieldname, 'Label' ) if ( $self->GetValue( $fieldname, 'Label' ) );
    return "$label" . '<Input ' . $arg . '>';
}

1;
