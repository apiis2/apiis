##############################################################################
# $Id: printf_out.pm,v 1.1 2005-12-16 13:32:44 heli Exp $
# Print out some text to STDOUT according to printf formatting.
##############################################################################
package Apiis::Form::Event::printf_out;

use strict;
use warnings;
use base 'Apiis::Init';
use Data::Dumper;
use List::MoreUtils qw( any );

sub _printf_out {
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
                    from      => 'Apiis::Form::Event::_prinf_out',
                    backtrace => Carp::longmess('invoked'),
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

        # some keys can appear several times:
        my @array_values = qw{ elementname };

        # ok, process parameters now:
        for my $parameter (@$parameter_ref) {
            my $key = $self->GetValue( $parameter, 'Key' );
            my $val = $self->GetValue( $parameter, 'Value' );

            # do we have array value?
            if ( any { $_ eq $key } @array_values ) {
                push @{ $event_args{$key} }, $val;
            }
            else {
                $event_args{$key} = $val;
            }
        }
    }    # end label EXIT

    # finally print it out:
    my $format = $event_args{'text'} . "\n";
    printf STDOUT $format, @{ $event_args{'elementname'} };
    return;
}
##############################################################################

1;

__END__

=head2 _prinf_out

This is only an event for demonstrating invokation and parameter passing.

=cut

