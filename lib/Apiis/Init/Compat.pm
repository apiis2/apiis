##############################################################################
# $Id: Compat.pm,v 1.2 2014/12/08 08:56:55 heli Exp $
##############################################################################

package Apiis::Init::Compat;

use strict;
use warnings;
use Apiis::Init;
use List::Util qw( first );

# our $apiis;
##############################################################################

=head1 NAME

Apiis::Init::Compat handling compatibility issues

=head1 DESCRIPTION

Apiis::Init::Compat contains some internal routines for handling compatibility
issues

=head1 METHODS

=cut

##############################################################################
sub new {
   my ( $invocant, %args ) = @_;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init(%args);
   return $self;
}
##############################################################################
sub _init {
    my ( $self, %args ) = @_;

    # do we have ID set handling in transfer (introduced July 2006):
    my @columns = $apiis->Model->table('transfer')->cols;
    ( first { $_ eq 'id_set' } @columns ) ? ( $self->{id_set} = 1 )
                                          : ( $self->{id_set} = 0 );
}

##############################################################################
# $apiis->Compat->get( 'namespace', $key );
sub get { return $_[0]->{$_[1]}; }
# $apiis->Compat->set( 'namespace', $key, $value );
sub set { $_[0]->{$_[1]} = $_[2]; }
##############################################################################

1;
