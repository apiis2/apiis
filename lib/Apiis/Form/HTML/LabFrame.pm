##############################################################################
# $Id: LabFrame.pm,v 1.7 2006/09/22 09:53:46 heli Exp $
# Frames with embedded label.
##############################################################################
package Apiis::Form::HTML::LabFrame;
use warnings;
use strict;
our $VERSION = '$Revision: 1.7 $';

use autouse 'Data::Dumper' => qw( Dumper );

sub _labframe {
    my ( $self, %args ) = @_;
    my $framename = $args{'elementname'};

#-- noch umsetzen
    return 1;

    my $border = $self->GetValue( $framename, 'BorderWidth' );
    $border = 2 if not defined $border or $border eq '';

    # create Label-Frame and configure:
#    my $frame_ref = $self->top->LabFrame(
#        -label     => $self->GetValue( $framename, 'Label' )     || '',
#        -labelside => $self->GetValue( $framename, 'LabelSide' ) || 'acrosstop',
#        -foreground  => $self->GetValue( $framename, 'LabelForeground' ) || '',
#        -borderwidth => $border,
#    );
    my $bg = $self->GetValue( $framename, 'BackGround' );
#    $frame_ref->configure( -background => $bg ) if $bg and $bg ne '';

    # handle of fields within this frame:
    my $field_ref = $self->GetValue( $framename, '_field_list' );
    my $misc_list_ref =
        $self->GetValue( $framename, '_misc_blockelement_list' );
    my %_done;
    foreach my $fieldname ( @$field_ref, @$misc_list_ref ) {
        my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
        my $tk_fieldtype = $self->fieldtype($fieldtype);
        next unless $tk_fieldtype;

        # require the widget module:
        my $module = 'Apiis::Form::HTML::' . $tk_fieldtype;
        if ( not exists $_done{$module} and not $self->can($module) ) {
            # load modules only once
            eval "require $module"; ## no critic
            if ($@) {
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'CRIT',
                        from      => 'Apiis::Form::Tk::run',
                        msg_long  => scalar $@,
                        msg_short =>
                            sprintf( "Error loading module '%s'", $module ),
                    )
                );
            }
        }
        $_done{$module}++;

        # the commands are named after the Fieldtype, e.g _textfield for
        # type TextField or _label for type Label:
        my $command = $module . '::_' . $fieldtype;
        my $widget = $self->$command( elementname => $fieldname );
        if ( not defined $widget ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'CODE',
                    severity  => 'CRIT',
                    from      => 'Apiis::Form::HTML::run',
                    msg_short =>
                        &main::__( "Error loading module '[_1]'", $module ),
                    msg_long  => &main::__(
                        "Method '[_1]' returned no valid widget", $command ),
                )
            );
            $self->form_error( die => 0 );
        }
        $self->PushValue( $fieldname, '_widget_refs', $widget );

        # place widgets inside the frame:
#        $widget->grid(
#            -in         => $frame_ref,
#            -row        => $self->GetValue( $fieldname, 'Row' ),
#            -column     => $self->GetValue( $fieldname, 'Column' ),
#            -columnspan => $self->GetValue( $fieldname, 'Columnspan' ),
#            -pady       => $self->GetValue( $fieldname, 'PaddingTop' ) || 0,
#            -padx       => $self->GetValue( $fieldname, 'PaddingRight' ) || 0,
#            -ipady      => $self->GetValue( $fieldname, 'IPaddingTop' ) || 0,
#            -ipadx      => $self->GetValue( $fieldname, 'IPaddingRight' ) || 0,
#            -sticky => $self->GetValue( $fieldname, 'Sticky' ),
#        );
        my $visible = $self->GetValue( $fieldname, 'Visibility' );
#        $widget->gridForget if $visible and $visible eq 'hidden';
    }
#    return $frame_ref;
}

1;

# vim:tw=80:cindent:aw:expandtab
