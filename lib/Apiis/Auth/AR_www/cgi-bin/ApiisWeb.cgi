#!/usr/bin/env perl
##############################################################################
# $Id: ApiisWeb.cgi,v 1.10 2019/09/24 17:16:02 ulf Exp $
##############################################################################

=head1 NAME

ApiisWeb.cgi

=head1 GENERAL DESCRIPTION

Basic web interface layout is created as a table with three main parts.
  1.: Web page HEAD - header information 
  2.: Web page MENU - available actions to do
  3.: Web page Content - place for reports, forms etc.
  +-------------------+
  |       HEAD        |
  +---+---------------+
  | M |               |
  | E |   CONTENT     |
  | N |               |
  | U |               |
  +---+---------------+


=cut

=head1 SECTIONS   

=cut

BEGIN {
    use Env qw( APIIS_HOME SCRIPT_NAME );
    die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
    push @INC, "$APIIS_HOME/lib";
}

##############################################################################
use Apiis;
use warnings;
use strict;
use Data::Dumper;
use CGI qw ( -no_xhtml :standard :html3  :all escape escapeHTML);
use CGI::Carp qw(fatalsToBrowser);    #just for debuging

use Apache::Session::File;
use HTML::Template;

use Apiis::Init;
use Apiis::DataBase::Init;
use Apiis::DataBase::User;
use Apiis::Errors;
use Apiis::DataBase::Record;
use Apiis::Auth::AR_Common;

use Encode;
use open ':utf8';

push @INC, "$APIIS_HOME/lib/Apiis/Auth/AR_www/lib";
require ARMGeneral;
require WebMenu;
require ARMMain;
require ARMGeneral;
require ARMLabels;
require HandleAJAX;
require apiis_alib;
##############################################################################

=head2 Init section

 Initial section of the script. In this section session is created, 
 APIIS object and the global values are initialized.

=cut 

my $q       = new CGI;    #creating new CGI object
my $no_menu = 0;          #global value which switch off the menu
my $ajax;                 #global value responsible for calling AJAX action
my $cmenu;                #current menu position

# variable with script name for menu etc.
# when APIIS object is available can be read with $apiis->programname();
my $script_name = "ApiisWeb.cgi";

# paths to templates for various sections
my ( $tmpl_dir, $forms_tmpl_dir );
my ( @menu,     @sub_menu );         # array for main menu and sub menus
my $template          = undef;       # main template variable
my $login             = undef;       # login template (login information)
my $session_lang_tmpl = undef;       # session language template

# path to templates if APIIS_LOCAL is not available
$tmpl_dir = "../templates/";

##############################################################################
#UTF8 FORM PARAM
##############################################################################
# section for correct unicode handling when reading data
# from HTML form
my @par_names  = $q->param;
my $form_input = {};

foreach my $name (@par_names) {
    my @val = $q->param($name);
    foreach (@val) {
        $_ = Encode::decode_utf8($_);
    }
    $name = Encode::decode_utf8($name);

    if ( scalar @val == 1 ) {
        $form_input->{$name} = $val[0];
    }
    else {
        $form_input->{$name} = \@val;    # save value as an array ref
    }
}
### UTF8 FORM PARAM END

##############################################################################
#DEBUG
##############################################################################
my $debug = 7;    #debug information will be printed into debug file

=cut


 For debug messages special DBG_FILE is open. In web environmet sending of 
 debug messages to STDOUT is not very useful. Most of error/warning/info 
 messages are sent into APIIS log file in case when APIIS object is not 
 available (i.e.: in case of error during APIIS object creation) messages 
 are written to STDERR or DBG_FILE. 
=cut

if ($debug) { open DBG_FILE, ">>", "/tmp/arm_debug"; }
if ($debug) {
    print DBG_FILE
        "\n------------------------ start of request ------------------------";
}
use POSIX qw(strftime);
if ($debug) {
    print DBG_FILE "\n" . strftime "%a %b %e %H:%M:%S %Y", localtime;
}

# default temp directory
my $tmpdir = "/tmp/";

### DEBUG END

##############################################################################
# CREATING A SESSION
##############################################################################

my %session;    # hash to store session data
my @id;         # deprecated - do not use
my $action='';     # action to execute
if ( defined $form_input->{'sid'} and $form_input->{'sid'} ne "" ) {
    @id = split( '\,', $form_input->{'sid'} );
    $action = $id[1] || "";
}
# when action was sent as form parameter then action from $sid
# will be overwritten by action from form

if ( defined $form_input->{'action'} ) {
    $action = $form_input->{'action'};
}

my $sid;        # session identifier
my $login_to_db = 1; #give the rights to login to the db
my $anonymous_session = 0;    # to make possibility create anonymous link, 
                              # access via google without session
if ( defined $id[0] and $id[0] ne "" and ( $id[0] ne -1 ) ) {
    $sid = $id[0];
}
else {
    $sid = undef;
    $anonymous_session = 1 if ( $id[0] and $id[0] == -1 );
}

# directory where efabis sessions data are stored
my $session_dir = "/tmp/apiis_arm_sessiondata";

# check if session directory is available
if ( !-e $session_dir ) {
    # if not create it -> can not run without it
    eval system("mkdir $session_dir");
    if ($debug) {
        if ($@) {
            print STDERR "\nProblems with session directory: $@";
            $action = "logout";
        }
        else { print STDERR "\nNew session directory created"; }
    }
}

# create our session
if ( $anonymous_session != 1 ) {
    eval {
        tie %session, 'Apache::Session::File', $id[0],
            { Directory => $session_dir, };
    };

    if ($@) {
        print STDERR "\nSession data are not accessible: $@";
        $action = "logout";
    }
    else {
        $sid = $session{_session_id};    # reading session id into variable
    }
}
else {
    eval {
        tie %session, 'Apache::Session::File', undef,
            { Directory => $session_dir, };
    };

    if ($@) {
        print STDERR "\nSession data are not accessible: $@";
        $action = "logout";
    }
    else {
        $sid = $session{_session_id};    # reading session id into variable
    }
}

if ( $anonymous_session != 1 ) {
    # check if login name and password are defined and not empty
    if ( $form_input->{'lg_name'} ) {
        $session{lg_name} = $form_input->{'lg_name'}
            if ( $form_input->{'lg_name'} ne "" );
    }
    if ( $form_input->{'lg_pass'} ) {
        $session{lg_pass} = $form_input->{'lg_pass'}
            if ( $form_input->{'lg_pass'} ne "" );
    }

    # if lg_name nad lg_pass are available check interface ant content language
    if ( $form_input->{'lg_name'} and $form_input->{'lg_pass'} ) {
        if ( $form_input->{'gui_lang'} ) {
            $session{gui_lang} = $form_input->{'gui_lang'}
                if ( $form_input->{'gui_lang'} ne "" );
        }
        if ( $form_input->{'selected_project'} ) {
            $session{'selected_project'} = $form_input->{'selected_project'}
                if ( $form_input->{'selected_project'} ne "" );
        }
    }

    if (    $session{'lg_name'} eq "" 
        and $session{'lg_pass'} eq ""
        and $session{'selected_project'} eq "") {
      $login_to_db = 0;
    }
}
else {
    # special parameter for anonymous acces
    if ( $form_input->{'lang'} ) {
        $session{gui_lang} = $form_input->{'lang'}
            if ( $form_input->{'lang'} ne "" );
    }
}

# CREATING A SESSION END

##############################################################################
# APIIS initialization
##############################################################################

Apiis->initialize( VERSION => '$Revision: 1.10 $' );

my $user_obj;
if ($login_to_db) {

  # creating new APIIS user object
  $user_obj = Apiis::DataBase::User->new(
     id              => $session{'lg_name'},
     user_session_id => $sid
  );

  $user_obj->password( $session{'lg_pass'} );
  $apiis->join_model( $session{'selected_project'}, userobj => $user_obj );
  $login_to_db = 0 unless ($user_obj->authenticated);

  #checking if the user can login to the system
  unless ( $apiis->status ) {
      if ( $apiis->Auth->user_disabled ) {
          $apiis->status(1);
          $apiis->errors(
              Apiis::Errors->new(
                  type      => 'AUTH',
                  severity  => 'CRIT',
                  from      => 'Apiis::Auth::AR_Auth::user_disabled',
                  msg_short => __(
                      "This user account is disabled. Please contact administrator."
                  ),
              )
          );
      }
  }
  

}

# setting loops for interface and language
require ARMGeneral;
# get list of our interface languages
if ( not defined $session{'gui_lang_loop'} ) {
    $session{'gui_lang_loop'} = ARM::ARMGeneral::session_lang();
}

##############################################################################
# LOGIN FINISHED WITH ERROR
##############################################################################
if ( $apiis->status ) {

    #APIIS_LOCAL is not available here!!

    # open main template and template to enter login information
    $template = HTML::Template->new( filename => $tmpl_dir . 'index.tmpl' );
    $login    = HTML::Template->new( filename => $tmpl_dir . "login.tmpl" );

    # action script name into login template
    $login->param( 'action' => "/cgi-bin/" . $script_name );
    $login->param(
        'l_user_name' => __("User name"),
        'l_password'  => __("Password"),
    );

    # open templates with languages
    $session_lang_tmpl =
        HTML::Template->new( filename => $tmpl_dir . "session_lang.tmpl" );
    # fill template with languages
    $session_lang_tmpl->param( 'gui_lang_loop' => $session{'gui_lang_loop'} )
        if ( defined $session{'gui_lang_loop'} );
    $session_lang_tmpl->param(
        'action'        => "/cgi-bin/set_lang.cgi",
        'session_id'    => $sid,
        'l_language_of' => __("Language"),
        'l_set_lang'    => __("Set language"),
    );

    # fill template with project names
    my @projects;
    foreach ( $apiis->projects ) {
        my %tmp_hash;
        $tmp_hash{'project_name'} = $_;
        push @projects, \%tmp_hash;
    }
    $login->param( 'projects_loop' => \@projects );

    my $menu = HTML::Template->new( filename => $tmpl_dir . "menu.tmpl" );

    require WebMenu;
    # actions probably will be not read properly from database
    # in case of error -> default set
    @menu = qw (help documentation);
    $menu->param( 'menu_list' =>
            ARM::WebMenu::print_menu( \@menu, $script_name, $cmenu, $sid ) );

    # fill place-holder for our menu
    $template->param( 'MENU' => $menu->output
            . $session_lang_tmpl->output
            . $login->output );
    # show pop-up window with error message
    $template->param( 'on_load_script' => "onload=\"window.alert(\'"
            . escapeHTML( ${ $apiis->errors }[0]->msg_short )
            . "\'); return true\"" );

    my $news_tmpl = HTML::Template->new( filename => $tmpl_dir . "main.tmpl" );

    # set default language (English) when language was not set
    $session{gui_lang} = "en" unless ( $session{gui_lang} );
    $session{'lg_name'}  = undef;
    $session{'lg_pass'}  = undef;
    $session{'selected_project'}  = undef;

    # set initial template parameters:
    # my_style, print_style, java_script, mid_header, l_page_keywords,
    # l_page_description, l_page_author
    $template->param( %{ ARM::ARMGeneral::initTMPL( $session{'gui_lang'} ) } );
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
    # EFABIS news END

    #print our web page in case of APIIS error
    print "Content-Type: text/html; charset=utf-8\n\n", $template->output;
}
# LOGIN FINISHED WITH ERROR END

##############################################################################
# WHEN LOG-IN WAS SUCCESFULY FINISHED
##############################################################################
else {

  if ($login_to_db) {
     $user_obj->language( $session{gui_lang} ) if ( defined $session{gui_lang} );
     $apiis->language( $session{gui_lang} );
  }


=head2  
 
Require of local libraries HAVE TO BE after join_model and also HAVE TO BE 
after setting of gui_lang in other case original language from table 
users is used instead of gui_lang comming from interface

=cut

    # directories with templates files
    $tmpl_dir       = $apiis->APIIS_HOME . "/lib/Apiis/Auth/AR_www/templates/";
    $forms_tmpl_dir = $apiis->APIIS_HOME . "/lib/Apiis/Auth/AR_www/forms/";

    #return this menu actions which user is allowed to see
    if ($login_to_db) {
      @menu = $apiis->Auth->check_system_tasks('www');
    }
    else {
      @menu = qw (help documentation);
    }
    
    $template = HTML::Template->new( filename => $tmpl_dir . 'index.tmpl' );

    $SCRIPT_NAME =~ s/.*\/(.*\.cgi)$/$1/;    #get script name from ENV variable
                                             #status information
    my %status_info;          # information about current status
    my %basic_tmpl_params;    # basic parameters for each template
    my @status_info;

    # create hash with parameters for basic information
    %basic_tmpl_params = (
        'my_style'    => ARM::ARMGeneral::style( $session{'gui_lang'} ),
        'print_style' => ARM::ARMGeneral::print_style( $session{'gui_lang'} ),
        'java_script' => ARM::ARMGeneral::js_functions(),
        'l_page_keywords'    => ARM::ARMLabels::get_arm_labels("index.cgi"),
        'l_page_description' => ARM::ARMLabels::get_arm_labels("index.cgi"),
        'l_page_author'      => "TZV FAL Germany vel. Mariensee TEAM",
    );
    if ( $login_to_db) {
        %status_info = (
            login_string   => __("You are login as"),
            webmaster      => __("Webmaster"),
            copyright_info => __("APIIS application<br />2004-2006"),
            login          => $session{'lg_name'},
            node           => "(" . $session{'selected_project'} . ")<br />",
            e_mail         => __("e-mail"),
            e_mail_address => "imialekm&#64;o2.pl",    #contact e-mail address
        );
        push @status_info, \%status_info;
        $basic_tmpl_params{'status_info'} = \@status_info;
    }
    else {
        #if user is anonymous than login form is printed
        $login = HTML::Template->new( filename => $tmpl_dir . "login.tmpl" );
        $login->param( 'action' => "/cgi-bin/" . $script_name );
        $login->param(
            'l_user_name' => __("User name"),
            'l_password'  => __("Password"),
        );
        $session_lang_tmpl =
            HTML::Template->new( filename => $tmpl_dir . "session_lang.tmpl" );
        $session_lang_tmpl->param( 'action' => "/cgi-bin/set_lang.cgi" );
        $session_lang_tmpl->param(
            'gui_lang_loop' => $session{'gui_lang_loop'} )
            if ( defined $session{'gui_lang_loop'} );
        $session_lang_tmpl->param(
            'session_id'    => $sid,
            'l_language_of' => __("Language"),
            'l_set_lang'    => __("Set language"),
        );

        my @projects;
        foreach ( $apiis->projects ) {
            my %tmp_hash;
            $tmp_hash{'project_name'} = $_;
            push @projects, \%tmp_hash;
        }
        $login->param( 'projects_loop' => \@projects );
    }
    # Init section END

        # store form_status into session
        $session{'form_status'} = $form_input->{'form_status'}
            if ( defined $form_input->{'form_status'} );

        if ( not defined $action ) {
            $session{'form_status'} = undef;
            $apiis->log( 'info', "Action NOT defined. Form status: undef" );
        }
        $apiis->log( 'info', "Action: " . $action );
        if ( defined $session{'form_status'} ) {
            $apiis->log( 'info',
                " Form status (in session): " . $session{'form_status'} );
        }
        else {
            $apiis->log( 'info', " Form status MISSING in session" );
            # set status to new because was not defined yet
            $session{'form_status'} = "new";
            $apiis->log( 'info',
                " Setting form status to: " . $session{'form_status'} );
        }

##############################################################################
        # CALLING DIFFERENT ACTIONS
##############################################################################

=head2 Default action section

   When action was not speciefied opening default main page  .

=cut

        if ( !$action ) {
            $cmenu = "";
            my $arm_form = "users";
            my ( $arm_tmpl, $form_header, $session_data, $menu );

            if ($login_to_db) {
              ( $arm_tmpl, $form_header, $session_data, $menu ) =
                 ARM::ARMMain::arm_main( $arm_form, \%$form_input,
                 $session{'content_lang'} );
              $session{'form_name'} = $session_data->{'form_name'};
            }
            #$session{'errors'}             = $session_data->{'errors'};
            if ( defined $template ) {
                $template->param( 'menuform'   => $menu );
                $template->param( 'MID_HEADER' => $form_header );
                $template->param( 'JS_HEAD' => ARM::ARMGeneral::js_header() );
                if ( $apiis->status or $login_to_db == 0) {
                    $template->param(
                        'FORM' =>
                            "<div align=\"center\"><img align=\"center\" border=\"0\" src=\"../images/img1.png\"></div>
                     <div id=\"home_big\">Apiis <br> Access Control System</div><br>
                     <div id=\"home\">developed by</div>
                     <div id=\"home\"><a href=\"mailto:imialekm&#64;o2.pl\">Marek Imialek</a>, 
                                      <a href=\"mailto:eg&#64;tzv.fal.de\">Eildert Groeneveld</a>
                     </div><br>
                     <div id=\"home_small\">FAL Mariensee, Germany</div>
                    "
                    );
                }
                else {
                    $template->param( 'FORM' => $arm_tmpl );
                }
            }
        }
        # default action section END

=head2 Access rights management actions
  
  All actions whicha are realted to the users, roles, policies.
  
=cut

        elsif ( $action =~ /^arm(.*)/ ) {
            my $arm_form = $1;
            $cmenu    = "arm";
            $arm_form = "users" if ( $arm_form eq "" and $action eq "arm" );
            $no_menu  = 1
                if ( $arm_form eq "choose_table"
                or $arm_form eq "choose_descriptor"
                or $arm_form eq "descriptors_define_sql" );

            my ( $arm_tmpl, $form_header, $session_data, $menu ) =
                ARM::ARMMain::arm_main( $arm_form, \%$form_input,
                $session{'gui_lang'}, $session{'role_policies_ids'} );
            $session{'form_name'} = $session_data->{'form_name'};
            $session{'errors'}    = $session_data->{'errors'};

            if ( $arm_form eq "role" ) {
                $session{'role_policies_ids'} =
                    $session_data->{'role_policies'};
            }
            else {
                $session{'role_policies_ids'} = undef;
            }

            if ( defined $template ) {
                $template->param( 'menuform' => $menu ) unless ($no_menu);
                $template->param( 'MID_HEADER' => $form_header );
                $template->param(
                    'JS_HEAD' => ARM::ARMGeneral::js_header($arm_form) );
                $template->param( 'FORM' => $arm_tmpl );
            }
        }

=head2 AJAX actions section

  This action is called in case if the values are returned 
  without reloading whole page (AJAX solution).

=cut

        elsif ( $action =~ /^ajax(.*)/ ) {
            $ajax = ARM::HandleAJAX::main( $action, \%$form_input );
        }

=head2 

  calling help and faq form 

=cut

        elsif ( $action eq 'help' ) {
            $cmenu = "help";
            my ( $tmpl_output, $mid_header ) =
                ARM::ARMGeneral::listFAQ( $tmpl_dir, $session{'gui_lang'} );
            $template->param(
                'MAIN'       => $tmpl_output,
                'MID_HEADER' => $mid_header
            );
        }

=head2 

  calling documentation form  

=cut

        elsif ( $action eq 'documentation' ) {
            $cmenu = "documentation";
            my ( $tmpl_output, $mid_header ) =
                ARM::ARMGeneral::show_documentation();
            $template->param(
                'MAIN'       => $tmpl_output,
                'MID_HEADER' => $mid_header
            );
        }

=head2 

  calling logout

=cut

        elsif ( $action eq 'logout' ) {
            if ( defined $session{_session_id} ) { tied(%session)->delete }
            undef $user_obj if ( defined $user_obj );

            print $q->redirect("index.cgi");
        }

        # CALLING DIFFERENT ACTIONS END

##############################################################################
        # FINALL SECTION
##############################################################################

=head2 Final section

 Code in this section is responsible for showing all web pages 
 and also pop-up windows with errors. Some default error messages
 are replaced here or modified to display them correctly 
 in Java Script: window.alert().

=cut

        # if there are some errors pop-up window will be shown
        if ( defined $session{'errors'} ) {
            $apiis->log( "debug", "Preparing JS alert" );
            # some characters HAVE TO be changed for window.alert
            $session{'errors'} =~ tr/'/"/;    # single quots to double
            my $my_quot = "&quot;";
            $session{'errors'} =~ s/"/$my_quot/g;
            my $white_char = "";
            $session{'errors'}
                =~ s/[\x0A]/$white_char/g;    # unix EOL with white character
                # change postgreSQL message to something more meaningfull
            if ( $session{'errors'} =~ /duplicate key violates/ ) {
                $session{'errors'} =
                    __(
                    "Duplicate key violation. Record already exists in database"
                    );
            }
            my $tmp_string =
                "onload=\"window.alert(\'" . $session{'errors'} . "\');\"";
            $template->param( 'on_load_script' => $tmp_string )
                if ( defined $template );
            $apiis->log( "debug", "Alert: " . $tmp_string );
            $session{'errors'} = undef;
        }

        if ($debug) {
            print DBG_FILE "\n" . strftime "%a %b %e %H:%M:%S %Y", localtime;
            print DBG_FILE
                "\n------------------------ end of request ------------------------\n";
        }

=cut


	Fill main menu (left side)
	Parameters for getMenu subroutine:
	@menu - main menu positions (list of actions)
	$SCRIPT_NAME - name of script which is executed
	$cmenu - current menu position
	$sid - session identifier
	$tmpl_dir - directory where is menu template
	@sub_menu - submenu for current (cmenu) position (list of actions) 

=cut

        my $tmp_menu = ARM::WebMenu::getMenu( 
            \@menu, $SCRIPT_NAME, $cmenu, $sid, $tmpl_dir, \@sub_menu );
        $tmp_menu .= $session_lang_tmpl->output
            if ( defined $session_lang_tmpl );
        $tmp_menu .= $login->output        if ( defined $login );
        $template->param( 'menu', $tmp_menu ) unless ($no_menu);

        # add some other general content
        $template->param(%basic_tmpl_params) if ( defined $template );

        # print our web page
        # add your action here if you want some exception(
        if (    $action ne 'logout'
            and $action ne 'output_sent'
            and !( $action =~ /^ajax(.*)/ ) )
        {
            print "Content-Type: text/html; charset=utf-8\n\n",
                $template->output
                if ( defined $template );
        }

        # print only results in to the web page in case of AJAX
        if ( $action =~ /^ajax(.*)/ ) {
            print "Content-Type: text/html; charset=utf-8\n\n", $ajax;
        }

        $session{'action'} =
            $action;       # write our action into session for next step
        untie %session;    # unlock session file for next request
    # final section
}
# WHEN LOG-IN WAS SUCCESFULY FINISHED END

##############################################################################

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

