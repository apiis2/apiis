##############################################################################
# $Id: TextField.pm,v 1.15 2006/09/22 09:53:46 heli Exp $
# Handling TextFields
##############################################################################
package Apiis::Form::Tk::TextField;

use warnings;
use strict;
our $VERSION = '$Revision: 1.15 $';

use Data::Dumper;
use Apiis::Misc qw( is_true );

sub _textfield {
    my ( $self, %args ) = @_;
    my $fieldname = $args{elementname};

    my %widget_args;
    my $enabled = $self->GetValue( $fieldname, 'Enabled' );
    my $state = 'normal';
    $state = 'disabled' if $enabled and $enabled eq 'no';
    my $disabled_bg = $self->GetValue( $fieldname, 'DisabledBackGround' );
    my $disabled_fg = $self->GetValue( $fieldname, 'DisabledForeGround' );
    my $password    = $self->GetValue( $fieldname, 'Password' );

    my $size = $self->GetValue( $fieldname, 'Size' );
    my $bg   = $self->GetValue( $fieldname, 'BackGround' );
    my $fg   = $self->GetValue( $fieldname, 'ForeGround' );

    $widget_args{-disabledbackground} = $disabled_bg
        if defined $disabled_bg and $disabled_bg ne '';
    $widget_args{-disabledforeground} = $disabled_fg
        if defined $disabled_fg and $disabled_fg ne '';
    $widget_args{-width}        = $size if defined $size and $size ne '';
    $widget_args{-background}   = $bg   if defined $bg   and $bg  ne '';
    $widget_args{-foreground}   = $fg   if defined $fg   and $fg  ne '';
    $widget_args{-textvariable} = $self->GetValue( $fieldname, '_data_ref' );
    $widget_args{-state}        = $state if $state;
    $widget_args{-show}         = '*' if is_true($password);

    return $self->top->Entry(%widget_args);
}

1;
