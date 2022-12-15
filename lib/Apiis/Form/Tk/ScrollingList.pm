##############################################################################
# $Id: ScrollingList.pm,v 1.9 2007/08/08 07:05:17 heli Exp $
# Handling Listboxes in a scrolling environment.
##############################################################################
package Apiis::Form::Tk::ScrollingList;

use warnings;
use strict;
our $VERSION = '$Revision: 1.9 $';

use Data::Dumper;

sub _scrollinglist {
    my ( $self, %args ) = @_;
    my $fieldname  = $args{elementname};
    my $data_ref   = $self->GetValue( $fieldname, '_data_ref' );
    my $list_ref   = $self->GetValue( $fieldname, '_list_ref' );
    my $width = $self->GetValue( $fieldname, 'Size' );
    my $label = $self->GetValue( $fieldname, 'Label' );
    my $selectmode = lc $self->GetValue( $fieldname, 'SelectMode' );
    $selectmode = 'extended' if $selectmode eq 'multiple'; # better

    # collect arguments:
    my %scroll_args = (
        -listvariable => $list_ref,
        -scrollbars   => "osoe",
    );
    $scroll_args{'-width'} = $width if defined $width;
    $scroll_args{'-label'} = $label if defined $label;
    $scroll_args{'-selectmode'} = $selectmode || 'single';

    my $listbox = $self->top->Scrolled( "Listbox", %scroll_args );

    # push the selections into $data_ref as arrayref:
    $listbox->bind(
        '<Button-1>' => sub {
            my @selected_idx = $listbox->curselection;
            my @selected = map { $listbox->get($_) } @selected_idx;
            $selectmode eq 'single'
                ? ( $$data_ref = $selected[0] )
                : ( $$data_ref = \@selected );
        }
    );
    return $listbox;
}
##############################################################################
1;
