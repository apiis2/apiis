#!/usr/bin/env perl
##############################################################################
# $Id: index.cgi,v 1.6 2006/08/08 14:35:15 marek Exp $
##############################################################################

BEGIN {
    use Env qw( APIIS_HOME SCRIPT_NAME );
    die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
    push @INC, "$APIIS_HOME/lib";
}

=head1 NAME

index.cgi

=head1 DESCRIPTION

Script to show starting web page of arm.

=cut

##############################################################################
use Apiis;
use warnings;
use strict;
use CGI qw ( -no_xhtml :standard :html3);
use HTML::Template;
use Apache::Session::File; #for session to keep some data between different cals

use Apiis::Init;
use Apiis::DataBase::Init;
use Apiis::DataBase::User;
use Apiis::Errors;

use Apiis::DataBase::Record;
use Apiis::Auth::AR_Common;
use open ':utf8';
use open ':std';

push @INC, "$APIIS_HOME/lib/Apiis/Auth/AR_www/lib";
require ARMGeneral;
##############################################################################

##############################################################################
# initializing global value
##############################################################################
my %session;
my $q           = new CGI;
my $sid         = undef;
my $tmpl_dir    = "../templates/"; # path to templates
my $script_name = "ApiisWeb.cgi";  # variable with script name for menu and rest

################################################################################
# CREATING A SESSION
################################################################################
my $session_dir = "/tmp/apiis_arm_sessiondata";   #directory for efabis sessions

if ( !-e $session_dir ) {
    eval system("mkdir $session_dir");
    if ($@) { print STDERR "Problems with session directory: $@"; }
}
if ( defined $q->param('sid') ) {
    $sid = $q->param('sid');
}

eval {
    tie %session, 'Apache::Session::File', $sid, { Directory => $session_dir, };
};
if ($@) { print STDERR "Session data are not accessible: $@"; }

$sid = $session{_session_id};    #reading session id for current session
$session{'action'} = "index.cgi";

################################################################################
# Initializing APIIS object
################################################################################
Apiis->initialize( VERSION => '$Revision: 1.6 $' );

# open login template
my $login = HTML::Template->new( filename => $tmpl_dir . "login.tmpl" );
# action script name
$login->param( 'action' => "/cgi-bin/" . $script_name );
$login->param(
    'l_user_name' => __("User name"),
    'l_password'  => __("Password"),
    'l_log_in'    => __("Log-in"),
);

require ARMGeneral;

#initializing language tepmlate
my $session_lang_tmpl =
    HTML::Template->new( filename => $tmpl_dir . "session_lang.tmpl" );
$session_lang_tmpl->param( 'action' => "/cgi-bin/set_lang.cgi" );
$session{'gui_lang_loop'} = ARM::ARMGeneral::session_lang()
    if ( not defined $session{'gui_lang_loop'} );
$session_lang_tmpl->param( 'gui_lang_loop' => $session{'gui_lang_loop'} );
$session_lang_tmpl->param(
    'session_id'    => $sid,
    'l_language_of' => __("Language"),
    'l_set_lang'    => __("Choose language"),
);


my @projects;
foreach ( $apiis->projects ) {
  my %tmp_hash;
  $tmp_hash{'project_name'} = $_;
  push @projects, \%tmp_hash;
}
$login->param( 'projects_loop' => \@projects );

# actions for anonymous
my @menu = qw (help documentation);
# open main template file
my $template = HTML::Template->new( filename => $tmpl_dir . "index.tmpl" );

# set initial template parameters:
# my_style, my_style, java_script, mid_header, l_page_keywords,
# l_page_description, l_page_author

$template->param( %{ ARM::ARMGeneral::initTMPL( $session{'gui_lang'} ) } );

require WebMenu;
my $cmenu = "";

# placeholder for our menu
my $main_menu =
    ARM::WebMenu::getMenu( \@menu, $script_name, $cmenu, $sid, $tmpl_dir );

$template->param( 'MENU' => $main_menu
        . $session_lang_tmpl->output
        . $login->output );

$template->param(
    'main' => "
    <div align=\"center\"><img align=\"center\" border=\"0\" src=\"../images/img1.png\"></div>
    <div id=\"home_big\">Apiis <br> Access Control System</div><br>
    <div id=\"home\">developed by</div>
    <div id=\"home\"><a href=\"mailto:imialekm&#64;o2.pl\">Marek Imialek</a>, 
                     <a href=\"mailto:eg&#64;tzv.fal.de\">Eildert Groeneveld</a>
    </div><br>
    <div id=\"home_small\">FAL Mariensee, Germany</div>
   "
);

$template->param(
    'footer' => "<div align=\"center\">APIIS application 2005 - 2006</div>" );

#send our template to the standard output
print "Content-Type: text/html; charset=utf-8\n\n", $template->output;

##############################################################################

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de>

=cut

