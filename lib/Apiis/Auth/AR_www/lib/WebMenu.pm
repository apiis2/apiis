package ARM::WebMenu;
##############################################################################
# $Id: WebMenu.pm,v 1.4 2006/08/08 14:35:15 marek Exp $
##############################################################################
use Apiis::Init;
use Apiis::DataBase::Record;

=head1 NAME

WebMenu.pm

=head1 DESCRIPTION
 
 Subroutines for web interface menu creation

=cut

=head2 getMenu
	
	Subroutine to prepare main menu with submenus if defined 
	input:
		1)	menu - action list for main menu
		2)	script_name - name of the script
		3) cmenu - current menu item (if submenu is defined will be assigned 
			to this menu position)
		4)	sid - session ID (if APIIS is not created in case of error method:
			 $apiis->user_session not available)
		5)	tmpl_dir - path to template directory
		6)	submenu - list of actions for submenu (optional)
	output:

=cut

sub getMenu {
    my ( $menu, $script_name, $cmenu, $sid, $tmpl_dir,
        $submenu )
        = @_;
    my $sub_menu_tmpl = undef;
    my $main_menu = HTML::Template->new( filename => $tmpl_dir . "menu.tmpl" );
    if ( $main_menu->query( name => 'submenu' ) ) {
        $sub_menu_tmpl =
            HTML::Template->new( filename => $tmpl_dir . "submenu.tmpl" );
    }
    # if sid is not defined try to get one from apiis
    if ( not defined $sid and $apiis->check_status ) {
        $sid = $apiis->User->user_session_id;
    }

    my @left_menu;
    my @sub_menu;
    my $action;

    if ( not defined $sid ) {
        $sid = $apiis->User->user_session_id;
    }

    # add default action to the main menu
    my %tmp_hash = (
        ACTION           => "",
        DESC             => getMenuField("home"),
        DESC_TITLE       => getMenuFieldTitle("home"),
        SESSION          => $sid,
        script_name      => $script_name,
    );
    if ( $cmenu eq "" ) {
        $tmp_hash{'cmenu'} = "cmenu";
    }
    push @left_menu, \%tmp_hash;
    # add default action to the main menu END

    foreach ( sort { menu_order( $a, $b ) } @{$menu} ) {
        $action = $_;
        my %tmp_hash;

        %tmp_hash = (
            ACTION           => $action,
            DESC             => getMenuField($_),
            DESC_TITLE       => getMenuFieldTitle($_),
            SESSION          => $sid,
            script_name      => $script_name,
        );
        if ( ( $cmenu eq $action ) or ( $cmenu eq "" and $action eq "" ) ) {
            # higlight it
            $tmp_hash{'cmenu'} = "cmenu";
            # and add sub menu if its defined
            if ( defined $submenu ) {
                foreach ( @{$submenu} ) {
                    my $action1 = $_;
                    my %tmp_hash1;
                    if ( $cmenu eq $action1 ) {
                        $tmp_hash1{'cmenu'} = "cmenu";
                    }
                    %tmp_hash1 = (
                        ACTION => $action1,
                        DESC   => getSubMenuField($action1),
                        SESSION     => $sid,
                        script_name => $script_name,
                    );
                    push @sub_menu, \%tmp_hash1;
                    $sub_menu_tmpl->param( menu_list, \@sub_menu );
                    if ( $main_menu->query( name => 'submenu' ) ) {
                        $tmp_hash{'submenu'} = $sub_menu_tmpl->output;
                    }
                }
            }
        }
        push @left_menu, \%tmp_hash;
    }
    $main_menu->param( menu_list, \@left_menu );
    return $main_menu->output;
}

=head2 getMenuField
	
	Subrutines contains hash with definitions of all main menu actions
	and labels

	input: action
	output: label for action or reference to hash with all actions

=cut

sub getMenuField {
    my $field = shift;

    #labels for main menu links
    my %main_menu = (
        "home"          => __("Home Page"),
        "documentation" => __("Documentation"),
        "help"          => __("Help/FAQ"),
        "arm"           => __("Users"),
        "logout"        => __("Logout"),
    );

    return $main_menu{$field} if ( defined $field );
    return \%main_menu        if ( not defined $field );
}

=head2 getMenuFieldTitle

	Subrutines contains hash with definitions of all main menu action
	titles

	input: action
	output: action title or reference to hash with all titles

=cut

sub getMenuFieldTitle {
    my $field = shift;

    # titles for main menu links
    my %main_menu_title = (
        "home"          => __("About Access Rights Manager"),
        "documentation" => __("Access Rights Documenation"),
        "help"          => __("Help and Frequently Asked Questions"),
        "arm"           => __("Users"),
        "logout"        => __("Logout from ARM"),
    );

    return $main_menu_title{$field} if ( defined $field );
    return \%main_menu_title        if ( not defined $field );
}

=head2 getSubMenuField

	Subrutines contains hash with definitions of all sub menu actions
	used to create sub menu for current menu field (cmenu)

	input: action
	output: label for action or reference to hash with all actions

=cut

sub getSubMenuField {
    my $field = shift;

    # list of available actions with proper labels
    # for sub menu
    my %sub_menu = (
        "formsusers" => __("Users"),
        "formsroles" => __("Roles"),
    );

    return $sub_menu{$field} if ( defined $field );
    return \%sub_menu        if ( not defined $field );
}

=head2 print_menu

	Deprecated - do not use

	input:
		1) $menu - list of actions to show in menu
		2) $script_name - name of callers script
		3) $cmenu - current menu position
		4) $sid - session identifier
	output:
		Reference to array of hashes ready for template

=cut

sub print_menu {
    my ( $menu, $script_name, $cmenu, $sid ) = @_;
    my @left_menu;
    my $action;

    if ( not defined $sid ) {    # and $apiis->check_status
        $sid = $apiis->User->user_session_id;
    }

    #put default action
    my %tmp_hash = (
        ACTION      => "",
        DESC        => getMenuField("home"),
        DESC_TITLE  => getMenuFieldTitle("home"),
        SESSION     => $sid,
        script_name => $script_name,
    );
    if ( $cmenu eq "" ) {
        $tmp_hash{'cmenu'} = "cmenu";
    }
    push @left_menu, \%tmp_hash;

    foreach ( sort { menu_order( $a, $b ) } @{$menu} ) {
        $action = $_;
        my %tmp_hash;

        %tmp_hash = (
            ACTION      => $action,
            DESC        => getMenuField($_),
            DESC_TITLE  => getMenuFieldTitle($_),
            SESSION     => $sid,
            script_name => $script_name,
        );
        if ( $cmenu eq $action ) {
            $tmp_hash{'cmenu'} = "cmenu";
        }
        push @left_menu, \%tmp_hash;
    }

    return \@left_menu;
}

=head2

	Subroutine to order main menu fields

=cut

sub menu_order {
    my $a     = shift;
    my $b     = shift;
    my %order = (
        "home"          => 1,
        "arm"           => 2,
        "documentation" => 3,
        "help"          => 4,
        "logout"        => 5,
    );
    return $order{$a} <=> $order{$b};
}

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de>

Lucjan Soltys <soltys@tzv.fal.de>

=cut

1;
