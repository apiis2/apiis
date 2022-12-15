##############################################################################
# $Id: BrowseEntry.pm,v 1.17 2014/12/08 08:56:55 heli Exp $
# Handling BrowseEntry widgets
##############################################################################
package Apiis::Form::Tk::BrowseEntry;

use warnings;
use strict;
our $VERSION = '$Revision: 1.17 $';

require Tk::BrowseEntry;
use List::Util qw( first );

sub _browseentry {
    my ( $self, %args ) = @_;
    my $fieldname = $args{elementname};
    my $data_ref  = $self->GetValue( $fieldname, '_data_ref' );
    my $listwidth = $self->GetValue( $fieldname, 'ListWidth' );

    # collect arguments:
    my %browse_args = (
        -variable      => $data_ref,
        -width         => $self->GetValue( $fieldname, 'Size' ),
        -background    => $self->GetValue( $fieldname, 'BackGround' ) || 'grey',
        -autolimitheight => 1,
    );
    $browse_args{'-listwidth'} = $listwidth if $listwidth;

    # callback, when a selection is done (Event OnSelect):
    $browse_args{'-browsecmd'} = sub {
        # first store selected data: (why?)
        my ( $widget, $text ) = @_;
        my $data_ref = $self->GetValue( $fieldname, '_data_ref' );
        $$data_ref = $text;

        # run Events, if any:
        $self->RunEvent(
            {   elementname => $fieldname,
                eventtype   => 'OnSelect',
            }
        );
        $self->form_error( die => 0 ) if $self->status;
        return;
    };

    # initial loading of choices list and setting default:
    my $list_ref_initial = $self->GetValue( $fieldname, '_list_ref' );
    my $default = $self->GetValue( $fieldname, 'Default' );
    $browse_args{'-choices'} = $list_ref_initial;
    if ( defined $default ) {
        # does Default exist in choices?:
        if ( first { $_ eq $default } @$list_ref_initial ) {
            $$data_ref = $default;
        }
    }

    # callback to always get the newest choices list (e.g changed by Events):
    $browse_args{'-listcmd'} = sub {
        my $list_ref = $self->GetValue( $fieldname, '_list_ref' );

        # proceed only, if $list_ref has changed
        return if $list_ref eq $list_ref_initial;

        # set default to first entry in choices list:
        if ( defined $default ) {
            if ( first { $_ eq $default } @$list_ref ) {
                $$data_ref = $default;
            }
        }

        # reconfigure widget (maybe expensive!) to point to new $list_ref:
        $_[0]->configure( -choices => $list_ref );
        $self->form_error( die => 0 ) if $self->status;
        return;
    };

    # ok, now create the widget and return it:
    return $self->top->BrowseEntry(%browse_args);
}

##############################################################################
1;

