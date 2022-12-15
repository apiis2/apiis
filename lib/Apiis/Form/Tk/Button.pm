##############################################################################
# $Id: Button.pm,v 1.16 2006/10/09 08:53:55 heli Exp $
# Handling Buttons
##############################################################################
package Apiis::Form::Tk::Button;

use warnings;
use strict;
our $VERSION = '$Revision: 1.16 $';

use Apiis;

# in the form.dtd used as FileField:
sub _filefield {&_button}

sub _button {
    my ( $self, %args ) = @_;
    my $fieldname = $args{elementname};

    # get command and its parameters:
    my $command = $self->GetValue( $fieldname, 'Command' );
    my ( %command_args, @parameters );
    my $parameter_ref = $self->GetValue( $fieldname, '_parameter_list' );
    @parameters = @$parameter_ref if $parameter_ref;
    for my $p_name (@parameters) {
        my $key = $self->GetValue( $p_name, 'Key' );
        my $val = $self->GetValue( $p_name, 'Value' );
        $command_args{$key} = $val;
    }

    # add blockname:
    $command_args{'elementname'} = $fieldname;

    my $background = $self->GetValue( $fieldname, 'BackGround' )
        || 'lightyellow';
    my $foreground = $self->GetValue( $fieldname, 'ForeGround' )
        || 'black';
    my $label = $self->GetValue( $fieldname, 'ButtonLabel' )
        || $self->GetValue( $fieldname, 'Label' )
        || 'no label';
    $label = __($label);    # I18N

    my $height    = $self->GetValue( $fieldname, 'Height' )      || undef;
    my $width     = $self->GetValue( $fieldname, 'Width' )       || undef;
    my $imagefile = $self->GetValue( $fieldname, 'ButtonImage' ) || undef;

    my $image;
    if ( defined $imagefile ) {
        # substitue APIIS_HOME and APIIS_LOCAL, if used:
        $apiis->substitute_env( \$imagefile );
        $image = $self->top->Photo( -file => $imagefile );
    }
    my $button = $self->top->Button(
        -text       => $label,
        -background => $background,
        -foreground => $foreground,
        -command    => sub { $self->$command( \%command_args ) },
    );
    $button->configure( -image  => $image, ) if defined $image;
    $button->configure( -height => $height ) if defined $height;
    $button->configure( -width  => $width )  if defined $width;

    return $button;
}

##############################################################################
1;
