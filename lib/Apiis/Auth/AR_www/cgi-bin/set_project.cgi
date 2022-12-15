#!/usr/bin/env perl
##############################################################################
# $Id: set_project.cgi,v 1.2 2006/07/21 07:43:31 marek Exp $
##############################################################################

=head1 NAME

set_project.cgi

=head1 DESCRIPTION

  Script set the project choosen from the 
  drop-down lists on interface
	
=cut

##############################################################################
use warnings;
use CGI;
use Apache::Session::File;
##############################################################################

my %session;
my $sid;

my $set_project = new CGI;
if ( defined $set_project->param('sid') ) {
    $sid = $set_project->param('sid');
}
tie %session, 'Apache::Session::File', $sid,
    { Directory => '/tmp/apiis_arm_sessiondata', };
open DBG_FILE, ">>", "/tmp/arm_debug";

$session{'projects'}      = $set_project->param("projects");
$session{'projects_loop'} = update_session_project('projects');

my $where_redirect;
if ( $session{'action'} ne "index.cgi" ) {
    print $set_project->redirect(
        "ApiisWeb.cgi?sid=" . $sid . "," . $session{'action'} );
}
elsif ( $session{'action'} eq "index.cgi" ) {
    print $set_project->redirect( "index.cgi?sid=" . $sid . "" );
}

untie %session;

sub update_session_project {
    my $which_loop = shift;
    my @new_project_loop;

    foreach ( @{ $session{ $which_loop . "_loop" } } ) {
        my %tmp_hash = %{$_};
        my $found    = "";
        while ( my ( $key, $value ) = each %tmp_hash ) {
            if ( $key eq "project_name" and $value eq $session{$which_loop} ) {
                $found = $session{$which_loop};
                $session{'selected_project'} = $session{$which_loop};
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

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl> 

=cut

