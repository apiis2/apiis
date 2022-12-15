##############################################################################
# $Id: DateEntry.pm,v 1.6 2014/12/08 08:56:55 heli Exp $
# Date widget
##############################################################################
package Apiis::Form::Tk::DateEntry;

use warnings;
use strict;
our $VERSION = '$Revision: 1.6 $';

use Tk::DateEntry;

use Apiis;
our $apiis;

# in the form.dtd used as Falendar:
sub _calendar {
    &_dateentry(@_);
}

sub _dateentry {
    my ( $self, %args ) = @_;
    my $field = $args{'elementname'};

    my %widget_args;
    $widget_args{'-textvariable'} = $self->GetValue( $field, '_data_ref' );

    my $xpm_file = $apiis->APIIS_HOME . '/lib/images/calendar.xpm';
    $widget_args{'-arrowimage'} = $self->top->Pixmap( -file => $xpm_file );

    my $bg = $self->GetValue( $field, 'BackGround' );
    $widget_args{'-background'}      = $bg if defined $bg and $bg ne '';
    $widget_args{'-todaybackground'} = 'green';

    $widget_args{'-parsecmd'} = sub {
        if ( $_[0] ) {
            return $apiis->extdate2iso( $_[0] );
        }
        return;
    };

    $widget_args{'-formatcmd'} = sub {
        return
            scalar $apiis->iso2extdate( sprintf "%04d-%02d-%02d", $_[0], $_[1],
            $_[2] );
    };
    return $self->top->DateEntry(%widget_args);
}

1;

