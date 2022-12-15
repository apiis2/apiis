##############################################################################
# $Id: Label.pm,v 1.10 2007-09-20 14:20:27 heli Exp $
# Handling Labels
##############################################################################
package Apiis::Form::Tk::Label;
use warnings;
use strict;
our $VERSION = '$Revision: 1.10 $';

use Apiis::Init;

sub _label {
    my ( $self, %args ) = @_;
    my $labelname   = $args{'elementname'};

    my $label_text  = $self->GetValue( $labelname, 'Content' ) || '';
    my $label_width = $self->GetValue( $labelname, 'Width' );
    if ( !$label_width ) {
        $label_width = ( length($label_text) + 3 ) || 20;
    }

    my %label_args = (
        -text    => __( $label_text ),
        -width   => $label_width,
        -relief  => $self->GetValue( $labelname, 'Relief' ),
        -justify => $self->GetValue( $labelname, 'Justify' ),
        -anchor  => $self->GetValue( $labelname, 'Anchor' ),
    );
    my $bg = $self->GetValue( $labelname, 'BackGround' );
    $label_args{'-background'} = $bg if defined $bg and $bg ne '';
    # my $font = $self->font_string_for( $labelname );
    # $label_args{'-font'} = $font if $font;

    return $self->top->Label(%label_args);
}

1;
