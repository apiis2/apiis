##############################################################################
# $Id: Misc.pm,v 1.2 2014/12/08 08:56:55 heli Exp $
# Provides some basic methods.
# See POD at the end of the file.
##############################################################################
package Apiis::Form::Init::Misc;

use strict;
use warnings;
use Carp qw( longmess );

sub _font_string_for {
}
1;

__END__
    my ( $self, $args_ref ) = @_;

    my $return_string;
    EXIT: {
        my $field = $args_ref->{fieldname};
        if ( not defined $field ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Init::_font_string_for',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'fieldname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

#         Font            (fixed|times|helvetica|courier|lucida) "times"
#         FontFamily      CDATA          ""
#         FontUnit        CDATA          "pt"
#         FontSize        CDATA          "12"
#         FontStyle       (normal|italic|oblique) "normal"
#         FontWeight      (normal|bold|bolder|lighter) "normal"
#         FontVariant     (normal|smallcaps) "normal"
#         WordSpacing     CDATA    "normal"
#         LetterSpacing   CDATA    "normal"
#         TextDecoration  (none|underline|overline|line-through|blink) "none"
#         VerticalAlign   (baseline|sub|super|top|text-top|text-bottom|bottom) "baseline"
#         TextTransform   (none|capitalize|uppercase|lowercase) "none"
#         TextAlign       (left|right|center|justify) "left"
#         TextIndent      CDATA    ""
#         LineHeight      CDATA    ""

        # get parameters for this field:
        my $foundry          = '*';
        my $family        = $self->GetValue( $field, 'FontFamily' );
        my $unit          = '*';
        my $size          = $self->GetValue( $field, 'FontSize' );
        my $style         = $self->GetValue( $field, 'FontStyle' );
        my $weight        = $self->GetValue( $field, 'FontWeight' );
        my $variant       = $self->GetValue( $field, 'FontVariant' );
        my $wordspacing   = $self->GetValue( $field, 'WordSpacing' );
        my $letterspacing = $self->GetValue( $field, 'LetterSpacing' );
        my $decor         = $self->GetValue( $field, 'TextDecoration' );
        my $vert_align    = $self->GetValue( $field, 'VerticalAlign' );
        my $transform     = $self->GetValue( $field, 'TextTransform' );
        my $text_align    = $self->GetValue( $field, 'TextAlign' );
        my $line_height   = $self->GetValue( $field, 'LineHeight' );

        # process parameters now:
        $return_string = sprintf '-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s',
            $foundry, $family, $weight, $slant, $width, $add_style, $pixelsize,
            $pointsize, $resx, $resy, $spacing, $avgwidth, $registry, $encoding;
    }    # end label EXIT
    return $return_string;
}
##############################################################################

1;

__END__

=head2 _get_event_par_ref

input: eventname as hash reference:

   { eventname => 'ThisEvent' }

output: hash reference with the XML-Keys as keys and an array reference with
the XML-Values as entries.

Example from the XML file:

    <Event Name="Notify_F443"
        Type="OnSelect" Module="HandleDS" Action="get_field_data">
        <Parameter Name="Parameter_F449_1" Key="fieldname" Value="F443" />
        <Parameter Name="Parameter_F449_2" Key="fieldname" Value="F444" />
    </Event>

This returns a reference to this data structure:

   $VAR1 = {
      'fieldname' => [
                        'F443',
                        'F444',
                     ]
   };


=cut

