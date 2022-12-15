##############################################################################
# $Id: Message.pm,v 1.2 2006/09/22 09:53:46 heli Exp $
# Handling Message widgets (displaying text)
##############################################################################
package Apiis::Form::Tk::Message;

use warnings;
use strict;
our $VERSION = '$Revision: 1.2 $';

use Data::Dumper;

sub _message {
    my ( $self, %args ) = @_;
    my $fieldname = $args{elementname};

    my $widget = $self->top->Message(
        -justify    => $self->GetValue( $fieldname, 'Justify' ),
        -anchor     => $self->GetValue( $fieldname, 'Anchor' ),
        -width      => $self->GetValue( $fieldname, 'Size' )       || 20,
        -background => $self->GetValue( $fieldname, 'BackGround' ) || 'grey',
        -foreground => $self->GetValue( $fieldname, 'ForeGround' ) || 'grey',
        -textvariable => $self->GetValue( $fieldname, '_data_ref' ),
    );
    return $widget;
}

1;
