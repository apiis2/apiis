#!/usr/bin/env perl
##############################################################################
# $Id: set_lang.cgi,v 1.2 2006/07/21 07:43:32 marek Exp $
##############################################################################

=head1 NAME

set_lang.cgi

=head1 DESCRIPTION

	Script set the language of interface choosen from the 
	drop-down lists on interface

=cut

##############################################################################
use warnings;
use CGI;
use Apache::Session::File;

my %session;
my $sid;

my $set_lang = new CGI;
if ( defined $set_lang->param('sid') ) {
    $sid = $set_lang->param('sid');
}
tie %session, 'Apache::Session::File', $sid,
    { Directory => '/tmp/apiis_arm_sessiondata', };
$session{'gui_lang'} = $set_lang->param("gui_lang");

$session{'gui_lang_loop'} = update_session_lang('gui_lang');

my $where_redirect;
if ( $session{'action'} ne "index.cgi" ) {
    print $set_lang->redirect(
        "ApiisWeb.cgi?sid=" . $sid . "," . $session{'action'} );
}
elsif ( $session{'action'} eq "index.cgi" ) {
    print $set_lang->redirect( "index.cgi?sid=" . $sid . "" );
}

untie %session;

# subroutine to update selected flag for drop-down lists of languages

sub update_session_lang {
    my $which_loop = shift;
    my @new_lang_loop;
    foreach ( @{ $session{ $which_loop . "_loop" } } ) {
        my %tmp_hash = %{$_};
        my $found    = "";
        while ( my ( $key, $value ) = each %tmp_hash ) {
            if ( $key eq "lang_iso" and $value eq $session{$which_loop} ) {
                $found = $session{$which_loop};
            }
        }
        if ( $found ne "" ) {
            $tmp_hash{'selected'} = "selected";
        }
        else {
            $tmp_hash{'selected'} = "";
        }
        push( @new_lang_loop, \%tmp_hash );
    }
    return \@new_lang_loop;
}

##############################################################################

=head1 AUTHOR

Lucjan Soltys <soltys@tzv.fal.de>

=cut

