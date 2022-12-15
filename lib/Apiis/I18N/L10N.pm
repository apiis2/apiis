##############################################################################
# $Id: L10N.pm,v 1.12 2021/05/27 19:45:48 ulf Exp $
# Basic class for localization (l10n) in APIIS
##############################################################################
package Apiis::I18N::L10N;
$Apiis::I18N::L10N::VERSION = '$Revision: 1.12 $';

use strict;
use warnings;
use Apiis;
our $apiis;

use base 'Locale::Maketext';
use Locale::Maketext::Lexicon {
   en         => [ 'Gettext' => 'Apiis/I18N/L10N/en.mo', 'Auto' ],
   de         => [ 'Gettext' => 'Apiis/I18N/L10N/de.mo', 'Auto' ],
   no         => [ 'Gettext' => 'Apiis/I18N/L10N/no.mo', 'Auto' ],
   ru         => [ 'Gettext' => 'Apiis/I18N/L10N/ru.mo', 'Auto' ],
   _use_fuzzy => 1,
   _decode    => 1,
   _encode    => 'locale',
   en_test    => [ 'Gettext' => 'Apiis/I18N/L10N/en_test.mo', 'Auto' ],
   de_test    => [ 'Gettext' => 'Apiis/I18N/L10N/de_test.mo', 'Auto' ],
};

sub l10n_import {
    my ( $self, $argsref ) = @_;
    my $lang = $argsref->{'lang'};
    my $file = $argsref->{'file'};

    if ( $Locale::Maketext::Lexicon::VERSION <= '0.53' ) {
        # Clear cache with memoized lexicon. Patch sent to Audrey.
        Locale::Maketext->clear_isa_scan;
    }
    Locale::Maketext::Lexicon->import( { $lang => [ Gettext => $file ], } );
    if ($apiis) {
        $apiis->log( 'info',
            sprintf "Project specific l10n lexicon %s imported", $lang . 'mo' );
    }
    return;
}

##############################################################################
1;

__END__

=head1 NAME

Apiis::I18N::L18N -- Basic class for localization (l10n) in APIIS

=head1 SYNOPSIS

   use Apiis::I18N::L10N;

=head1 DESCRIPTION

This is the basic module for localization of APIIS during
runtime.  It is invoked automatically if you run the common
initialisation block and connect to a project.

=head1 METHODS

=head2 l10n_import (public)

B<l10n_import> imports/merges another lexicon file of a certain language into
the existing one.

Input parameter is a hash reference with the required keys 'lang' and 'file'.

Output: none

Usage:

   Apiis::I18N::L10N->l10n_import(
       { lang => $lang,
         file => $file,
       }
   );

=head1 VERSION

   $Revision: 1.12 $

=head1 BUGS

Before version 0.54 of Locale::Maketext::Lexicon, there was a bug in the Perl
module, that did not overwrite cached entries when you added a project
specific language file. For versions of 0.53 and below, a workaroung handles
this bug.

=head1 AUTHOR

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

