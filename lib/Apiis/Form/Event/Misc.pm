##############################################################################
# $Id: Misc.pm,v 1.2 2014/12/08 08:56:55 heli Exp $
# Provides some basic methods for Event handling.
# See POD at the end of the file.
##############################################################################
package Apiis::Form::Event::Misc;

use strict;
use warnings;
use Carp qw( longmess );

sub _get_event_par_ref {
    my ( $self, $args_ref ) = @_;

    my %event_args;
    EXIT: {
        my $event = $args_ref->{eventname};
        if ( not defined $event ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::_get_event_par_ref',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'eventname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # get parameters for this event:
        my $parameter_ref = $self->GetValue( $event, '_parameter_list' );
        last EXIT if !$parameter_ref;

        # process parameters now:
        for my $parameter (@$parameter_ref) {
            my $key = $self->GetValue( $parameter, 'Key' );
            my $val = $self->GetValue( $parameter, 'Value' );
            push @{ $event_args{$key} }, $val;
        }
    }    # end label EXIT
    return \%event_args;
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

