##############################################################################
# $Id: TextBlock.pm,v 1.6 2006/10/09 07:08:45 heli Exp $
# Handling text blocks with more than one line.
##############################################################################
package Apiis::Form::Tk::TextBlock;

use warnings;
use strict;
our $VERSION = '$Revision: 1.6 $';

use Data::Dumper;
use Tie::Watch;

sub _textblock {
    my ( $self, %args ) = @_;
    my $fieldname = $args{elementname};

    my %widget_args;
    my $width  = $self->GetValue( $fieldname, 'Width' );
    my $height = $self->GetValue( $fieldname, 'Height' );
    my $bg     = $self->GetValue( $fieldname, 'BackGround' );
    my $fg     = $self->GetValue( $fieldname, 'ForeGround' );
    $widget_args{'-scrollbars'} = 'osoe';
    $widget_args{'-width'}      = $width if defined $width and $width ne '';
    $widget_args{'-height'}     = $height if defined $height and $height ne '';
    $widget_args{'-background'} = $bg if defined $bg and $bg ne '';
    $widget_args{'-foreground'} = $fg if defined $fg and $fg ne '';

    my $widget = $self->top->Scrolled( 'Text', %widget_args );
    my $data_ref = $self->GetValue( $fieldname, '_data_ref' );
    $widget->insert( 'end', $$data_ref );

    # store the widget reference in the form object:
    $self->PushValue( $fieldname, '_widget_refs', $widget );

    # tie $data_ref to watch changes of this variable:
    if ( $fieldname eq '__form_status_msg' ) {
        my $watch = Tie::Watch->new(
            -variable => $data_ref,
            -fetch    => [ \&fetch_textblock, $widget, 'textblock' ],
            -store => sub { $_[0]->Store( $_[1] ) },
        );
    }
    else {
        my $watch = Tie::Watch->new(
            -variable => $data_ref,
            -store    => [ \&store_textblock, $widget, 'textblock' ],
            -fetch => sub { $_[0]->Fetch },
        );
    }

    # bind events to store the text in $data_ref:
    my @store_events = qw{ <FocusOut> <Key> };
    for my $event (@store_events) {
        $widget->bind(
            $event => sub {
                $$data_ref = $widget->get( "1.0", "end - 1 chars" );
            }
        );
    }
    return $widget;
}

sub fetch_textblock {
    my ($self)   = @_;
    my $text     = $self->Fetch;
    my $args_ref = $self->Args( -fetch );
    my $thiswidget = $args_ref->[0] if $args_ref;    ## no critic
    WIDGET: {
        if ( defined $thiswidget ) {
            my $type = $args_ref->[1];
            if ( $type eq 'textblock' ) {
                $thiswidget->delete( '1.0', 'end' );
                $thiswidget->insert( 'end', $text );
                last WIDGET;
            }
        }
    }
    return $text;
}

sub store_textblock {
    my $self       = shift;
    my $text       = shift;
    my $args_ref   = $self->Args( -store );
    my $thiswidget = $args_ref->[0] if $args_ref;    ## no critic
    WIDGET: {
        if ( defined $thiswidget ) {
            my $type = $args_ref->[1];
            if ( $type eq 'textblock' ) {
                $thiswidget->delete( '1.0', 'end' );
                $thiswidget->insert( 'end', $text );
                $self->Store($text);
                last WIDGET;
            }
        }
    }
}
1;
