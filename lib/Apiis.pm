##############################################################################
# $Id: Apiis.pm,v 1.4 2007/08/09 06:21:27 heli Exp $
# Basic initialization for Apiis
##############################################################################
package Apiis;
$VERSION = '$Revision: 1.4 $';

BEGIN {
   use Env qw/ APIIS_HOME /;
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
}

use strict;
use warnings;
use 5.8.0;   # use at least a 5.8 version of Perl
use lib "$APIIS_HOME/lib";

our ( $apiis, $APIIS_HOME );
require Exporter;
@Apiis::EXPORT    = qw( $apiis __ ); # symbols to export by default
@Apiis::EXPORT_OK = qw( loc translate ); # symbols to export by request
@Apiis::ISA = qw( Exporter );
use Apiis::Init;
use Apiis::Errors;

##############################################################################
sub initialize {
    my ( $self, %args ) = @_;
    my $programname = $0;
    $programname =~ s|.*/||;    # basename

    my $version = $args{VERSION}
        || $args{version}
        || "Version not set in $programname";
    $args{version}     = $version;
    $args{programname} = $programname;
    our $apiis = Apiis::Init->new( %args );

    $apiis->log( 'info', sprintf "%s started at %s by %s.",
        $programname, $apiis->now, $apiis->os_user ) if $apiis;
}

1;
##############################################################################

=head1 NAME

Apiis.pm

=head1 SYNOPSIS

   use Apiis;
   Apiis->initialize( VERSION => '$Revision: 1.4 $' );

=head1 DESCRIPTION

B<initialize> is the primary method for executables to load the Apiis
system. It does basic checking, creates, and exports the $apiis object into
the main namespace.

To avoid numerous nasty error messages you are strongly advised to start
your program with this BEGIN block:

   BEGIN {
      use Env qw( APIIS_HOME );
      die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
      push @INC, "$APIIS_HOME/lib";
   }

This catches errors due to an unset APIIS_HOME environment variable and
adds $APIIS_HOME/lib to your library path to find the Apiis modules.

=cut

=head1 SUBROUTINES

=head2 initialize

B<initialize> loads Apiis::Init, creates a new Apiis::Init object and
assigns it to the global variable $apiis, which is exported by default.
Also exported is the global subroutine __() for nationalisation of the
code.

B<initialize> currently takes one (hash) argument:

   Apiis->initialize( VERSION => '$Revision: 1.4 $' );

It propagetes the cvs version as the program version and can be retrieved
with $apiis->version.

=cut

=head1 Author

Helmut Lichtenberg <heli@tzv.fal.de>

