package ARM::ARMMain;
##############################################################################
# $Id: ARMMain.pm,v 1.28 2006/08/08 14:35:15 marek Exp $
##############################################################################
use Apiis::Init;
use ARMFormMenu;
use ARMLabels;
use ARMReadDB;
use ARMModifyDB;
use Data::Dumper;

use Env qw( APIIS_HOME );
 push @INC, "$APIIS_HOME/lib/Apiis/Auth";
 require AR_User;
 require AR_Common;
 require AR_View;
 require AR_Component;

=head1 NAME

ARMMain.pm

=head1 DESCRIPTION

  This is the main module which handel all actions in access rights manager

=cut

##############################################################################

sub arm_main {
    my ( $arm_form, $form_input, $content_lang, $defined_policies ) = @_;
    my ( $arm_tmpl, $form_menu_tmpl, $header );
    my %mysession;
    my %hash;
    my $SCRIPT_NAME    = $apiis->programname();
    my $sid            = $apiis->User->user_session_id;
    my $forms_tmpl_dir = $apiis->APIIS_HOME . "/lib/Apiis/Auth/AR_www/forms/";
    my $tmpl_dir = $apiis->APIIS_HOME . "/lib/Apiis/Auth/AR_www/templates/";

    my $status =
        $apiis->Auth->check_system_tasks( 'form',
        'access_rights_manager tool' );
    if ($status) {
        #FORM MENU#
        my ( $menu_form_level1, $menu_form_level2 ) = ARM::ARMFormMenu::get();

        if ( defined $menu_form_level1 ) {
            my ( $tab_menu1, $tab_menu2 ) =
                ARM::ARMFormMenu::tab_menu( $menu_form_level1,
                $menu_form_level2, $arm_form );
            $form_menu_tmpl =
                HTML::Template->new( filename => $tmpl_dir . 'form_menu.tmpl' );
            $form_menu_tmpl->param( 'menu_level1' => $tab_menu1 );
            $form_menu_tmpl->param( 'menu_level2' => $tab_menu2 )
                if ( $arm_form ne 'users' );
        }
        #TEMPLATE#
        $arm_tmpl = HTML::Template->new(
            filename          => $forms_tmpl_dir . $arm_form . ".tmpl",
            die_on_bad_params => 0
        );
        #LABELS#
        my %arm_labels = %{ ARM::ARMLabels::get_arm_labels($arm_form) };
        #MID HEADER#
        $header = $arm_labels{ "l_form_" . $arm_form };
        #SID#
        $arm_tmpl->param( 'session_id' => $sid );
        #Action in form#
        $arm_labels{form_action} = $SCRIPT_NAME;
        #Setting form name in the session#
        $mysession{'form_name'} = $arm_form;

        #FORMS#
        if ( $arm_form eq 'user' ) {

            if (   $form_input->{'form_status'} eq "update"
                or $form_input->{'form_status'} eq "insert" )
            {
                ( $mysession{'errors'}, $new_user_id ) =
                    ARM::ARMModifyDB::modify_user( \%$form_input );
            }
            my $myuser_id;
            $myuser_id = $form_input->{'show_apply'}
                if ( defined $form_input->{'show_apply'} );
            $myuser_id = $new_user_id
                if ( $form_input->{'form_status'} eq "insert" );

            if ( defined $myuser_id and $myuser_id ne '' ) {
                $arm_labels{'form_status'} = "edit";
                $arm_labels{'readonly'}    = "readonly";
                %hash = %{
                    ARM::ARMReadDB::select_user( $myuser_id,
                        $content_lang )
                    };
            }
            else {
                $arm_labels{'form_status'} = "new";
                %hash =
                    %{ ARM::ARMReadDB::get_loops_for_user($content_lang) };
            }
        }

        elsif ( $arm_form eq 'user_roles' ) {
            my $myuser_id = $form_input->{'show_apply'};

            #CHANGE USER ROLES#
            if ( $form_input->{'form_status'} eq "insert" ) {
                my $st_roles  = $form_input->{'st_roles'};
                my $dbt_roles = $form_input->{'dbt_roles'};
                $st_roles  = join( ',', @$st_roles )  if (@$st_roles);
                $dbt_roles = join( ',', @$dbt_roles ) if (@$dbt_roles);

                my @new_roles;
                if ( $dbt_roles eq '' ) {
                    @new_roles = split( ',', $st_roles );
                }
                else {
                    @new_roles = split( ',', "$dbt_roles,$st_roles" );
                }
                my $myuser        = $form_input->{'user_login'};
                my $current_roles = $form_input->{'current_roles'};
                $mysession{'errors'} =
                    ARM::ARMModifyDB::update_user_roles( $myuser,
                    $current_roles, \@new_roles );
                $mysession{'errors'} = undef if ( $mysession{'errors'} eq '' );
            }

            #SELECT USER ROLES#
            %hash =
                %{ ARM::ARMReadDB::select_user_roles($myuser_id) };
            $arm_labels{'form_status'} = "edit";
            $arm_labels{'show_apply'}  = $myuser_id;

            if ( defined $form_input->{'user_name'} ) {
                $arm_labels{'user_name'}  = $form_input->{'user_name'};
                $arm_labels{'user_login'} = $form_input->{'user_login'};
            }
            else {
                $arm_labels{'user_name'} =
                      $form_input->{'ar_users__user_first_name'} . " "
                    . $form_input->{'ar_users__user_second_name'};
                $arm_labels{'user_login'} =
                    $form_input->{'ar_users__user_login'};
            }
        }

        elsif ( $arm_form eq 'role' ) {
            #Changing policies for the role
            if ( $form_input->{'change_my_policies'} ) {
                my @policy_id;
                if ( @{ $form_input->{'policy_id'} } ) {
                    @policy_id = @{ $form_input->{'policy_id'} };
                }
                else {
                    push @policy_id, $form_input->{'policy_id'};
                }
                $mysession{'errors'} = ARM::ARMModifyDB::update_role_policies(
                    \@policy_id,
                    \@$defined_policies,
                    $form_input->{'show_role_name'},
                    $form_input->{'show_apply'},
                    $form_input->{'show_role_type'}
                );
            }

            my $new_role_id;
            if ( $form_input->{'form_status'} eq "update" ) {
                $mysession{'errors'} = ARM::ARMModifyDB::update_role( \%$form_input );
            }
            if ( $form_input->{'form_status'} eq "insert" ) {
                ( $mysession{'errors'}, $new_role_id ) =
                    ARM::ARMModifyDB::insert_role( \%$form_input );
            }

            my $myrole_id;
            $myrole_id = $form_input->{'show_apply'}
                if ( defined $form_input->{'show_apply'} );
            $myrole_id = $new_role_id
                if ( $form_input->{'form_status'} eq "insert" );

            my ( $role_hash, $policies_into_session );
            if ( defined $myrole_id and $myrole_id ne '' ) {
                ( $role_hash, $policies_into_session ) =
                    ARM::ARMReadDB::select_role($myrole_id);
                $arm_labels{'form_status'} = "edit";
                $arm_labels{'readonly'}    = "readonly";
            }
            else {
                $arm_labels{'form_status'} = "new";
                $arm_labels{'role_type'}   = $form_input->{'type'};
                $role_hash                 =
                    ARM::ARMReadDB::select_subroles_for_insert_role(
                    $form_input->{'type'} );
            }
            
            %hash = %$role_hash;
            $mysession{'role_policies'} = \@$policies_into_session;
        }

        elsif ( $arm_form eq 'arm_user_update' ) {
            my $user_id = $form_input->{'user_id'};
            $arm_tmpl->param( 'SESSION_ID' => $sid );
            $arm_tmpl->param( 'USER_ID'    => $user_id );
        }

        elsif ( $arm_form eq 'st_policies' ) {
            my ( $policies, $ids );

            ### EDIT POLICIES ####
            if ( defined $form_input->{'show_apply'}
                and $form_input->{'show_apply'} ne '' )
            {
                my %tmp_hash = ();
                $tmp_hash{'policy_id'}   = $form_input->{'show_apply'};
                $tmp_hash{'policy_name'} =
                    $form_input->{ 'stpolicy_name_' . $tmp_hash{'policy_id'} };
                $tmp_hash{'policy_type'} =
                    $form_input->{ 'action_type_' . $tmp_hash{'policy_id'} };
                $tmp_hash{'policy_desc'} =
                    $form_input->{ 'stpolicy_descr_' . $tmp_hash{'policy_id'} };

                if ( $form_input->{'show_apply'} eq 'new' ) {
                    $mysession{'errors'} =
                        ARM::ARMModifyDB::insert_stpolicy( \%tmp_hash );
                }
                else {
                    $mysession{'errors'} =
                        ARM::ARMModifyDB::update_stpolicy( \%tmp_hash );
                }

            }
            ### DELETE POLICIES ####
            if ( defined $form_input->{'remove'}
                and $form_input->{'remove'} ne '' )
            {
                $mysession{'errors'} = ARM::ARMModifyDB::delete_stpolicy( $form_input->{'remove'} );
            }

            ### SELECT POLICIES ####
            ( $policies, $ids ) = ARM::ARMReadDB::select_stpolicies();
            $hash{'policies_loop'} = \@$policies;
        }

        elsif ( $arm_form eq 'choose_table' ) {
            my $tables_loop =
                ARM::ARMReadDB::choose_tables( $form_input->{'table_id'},
                $form_input->{'choosen_policy_id'} );

            $hash{'tables_loop'} = \@$tables_loop;
        }

        elsif ( $arm_form eq 'choose_descriptor' ) {
            my $desc_loop = ARM::ARMReadDB::choose_descriptors(
                $sid,
                $SCRIPT_NAME,
                $form_input->{'descriptor_id'},
                $form_input->{'choosen_policy_id'},
                $form_input->{'choosen_table_name'}
            );

            $hash{'descriptor_loop'} = \@$desc_loop;
        }

        elsif ( $arm_form eq 'descriptors_define_sql' ) {
            $hash{'descriptor_tables'} =
                ARM::ARMReadDB::select_tables_which_have_this_column(
                $form_input->{'descriptor_name'},
                );

            $hash{'descriptor_name'} = $form_input->{'descriptor_name'};
            $hash{'descriptor_id'}   = $form_input->{'descriptor_id'};
        }

        elsif ( $arm_form eq 'dbt_policies' ) {
            my ( $policies, $ids );

            ### EDIT POLICIES ####
            if ( defined $form_input->{'show_apply'}
                and $form_input->{'show_apply'} ne '' )
            {
                my %tmp_hash = ();
                $tmp_hash{'policy_id'} = $form_input->{'show_apply'};
                $tmp_hash{'action_id'} =
                    $form_input->{ 'dbtpolicy_action_'
                        . $tmp_hash{'policy_id'} };
                $tmp_hash{'table_id'} =
                    $form_input->{ 'table_id_' . $tmp_hash{'policy_id'} };
                $tmp_hash{'descriptor_id'} =
                    $form_input->{ 'descriptor_id_' . $tmp_hash{'policy_id'} };

                if ( $form_input->{'show_apply'} eq 'new' ) {
                    $mysession{'errors'} =
                        ARM::ARMModifyDB::insert_dbtpolicy( \%tmp_hash );
                }
                else {
                    $mysession{'errors'} =
                        ARM::ARMModifyDB::update_dbtpolicy( \%tmp_hash );
                }

            }
            ### DELETE POLICIES ####
            if ( defined $form_input->{'remove'}
                and $form_input->{'remove'} ne '' )
            {
                $mysession{'errors'} = ARM::ARMModifyDB::delete_dbtpolicy(
                    $form_input->{'remove'} );
            }

            ### SELECT POLICIES ####
            ( $policies, $ids ) =
                ARM::ARMReadDB::select_dbtpolicies( $sid, $SCRIPT_NAME );
            $hash{'policies_loop'} = \@$policies;
        }

        elsif ( $arm_form eq 'tables' ) {

            if ( defined $form_input->{'show_apply'}
                and $form_input->{'show_apply'} ne '' )
            {
                my %tmp_hash = ();
                $tmp_hash{'table_id'}   = $form_input->{'show_apply'};
                $tmp_hash{'table_name'} =
                    $form_input->{ 'table_name_' . $tmp_hash{'table_id'} };
                $tmp_hash{'table_columns'} =
                    $form_input->{ 'table_columns_' . $tmp_hash{'table_id'} };
                $tmp_hash{'table_desc'} =
                    $form_input->{ 'table_desc_' . $tmp_hash{'table_id'} };

                if ( $form_input->{'show_apply'} eq 'new' ) {
                    $mysession{'errors'} =
                        ARM::ARMModifyDB::insert_table( \%tmp_hash );
                }
                else {
                    $mysession{'errors'} =
                        ARM::ARMModifyDB::update_table( \%tmp_hash );
                }
            }

            ### DELETE ####
            if ( defined $form_input->{'remove'}
                and $form_input->{'remove'} ne '' )
            {
                $mysession{'errors'} =
                    ARM::ARMModifyDB::delete_table(
                    $form_input->{'remove'} );
            }

            my $tables_loop = ARM::ARMReadDB::choose_tables();

            $hash{'tables_loop'} = \@$tables_loop;
        }

        elsif ( $arm_form eq 'descriptors' ) {

            if ( defined $form_input->{'show_apply'}
                and $form_input->{'show_apply'} ne '' )
            {
                my %tmp_hash = ();
                $tmp_hash{'descriptor_id'}   = $form_input->{'show_apply'};
                $tmp_hash{'descriptor_name'} =
                    $form_input->{ 'descriptor_name_'
                        . $tmp_hash{'descriptor_id'} };
                $tmp_hash{'descriptor_value'} =
                    $form_input->{ 'descriptor_value_'
                        . $tmp_hash{'descriptor_id'} };
                $tmp_hash{'descriptor_desc'} =
                    $form_input->{ 'descriptor_desc_'
                        . $tmp_hash{'descriptor_id'} };

                if ( $form_input->{'show_apply'} eq 'new' ) {
                    $mysession{'errors'} =
                        ARM::ARMModifyDB::insert_descriptor( \%tmp_hash );
                }
                else {
                    $mysession{'errors'} =
                        ARM::ARMModifyDB::update_descriptor( \%tmp_hash );
                }
            }

            ### DELETE POLICIES ####
            if ( defined $form_input->{'remove'}
                and $form_input->{'remove'} ne '' )
            {
                $mysession{'errors'} =
                    ARM::ARMModifyDB::delete_descriptor(
                    $form_input->{'remove'} );
            }

            my $desc_loop =
                ARM::ARMReadDB::choose_descriptors( $sid, $SCRIPT_NAME );

            $hash{'descriptor_loop'} = \@$desc_loop;
        }

        #DELETING USERS#
        if (    $arm_form eq 'users'
            and defined $form_input->{'remove'}
            and $form_input->{'remove'} ne '' )
        {
            my $myuser_login = $form_input->{'remove'};
            $mysession{'errors'} =
                ARM::ARMModifyDB::call_delete_user($myuser_login);
        }

        #DELETING ROLES#
        if ( ( $arm_form eq 'st_roles' or $arm_form eq 'dbt_roles' )
            and $form_input->{'remove'} ne '' )
        {
            my $myrole_name = $form_input->{'remove'};
            $mysession{'errors'} =
                ARM::ARMModifyDB::call_delete_role($myrole_name);
        }

        #merging hashes
        %arm_labels =
          %{ ARM::ARMReadDB::merging_hashes( \%arm_labels, \%hash )}; 

        ### error fields
        #     if(defined $session{'errors_fields'}){
        #   	foreach(@{$session{'errors_fields'}}){
        # 		$apiis->log('debug', "ERROR field: ".$_);
        # 		$arm_labels{"class_".$_}="err";
        #   	}
        # 	$session{'errors_fields'}=undef;
        #     }
        #### fill in with labels ####
        foreach ( $arm_tmpl->param ) {
            if (/^[l|L]\_(.*)/) {
                if ( $arm_labels{$_} ) {
                    $arm_tmpl->param( $_ => $arm_labels{$_} );
                }
            }
            elsif (/(.*)\_[l|L][o|O][o|O][p|P]$/) {
                if ( $arm_labels{$_} ) {
                    $arm_tmpl->param( $_ => \@{ $arm_labels{$_} } );
                }
            }
            elsif (/(.*)\_[s|S][u|U][b|B][l|L][o|O][o|O][p|P]$/) {
                if ( $arm_labels{$_} ) {
                    $arm_tmpl->param( $_ => &{ $arm_labels{$_} } );
                }
            }
            elsif (/^[c|C][l|L][a|A][s|S][s|S]\_(.*)/) {
                if ( defined $arm_labels{$_} ) {
                    $arm_tmpl->param( $_ => "err" );
                }
                else {
                    $arm_tmpl->param( $_ => "ok" );
                }
            }
            else {
                if ( $arm_labels{$_} ) {
                    $arm_tmpl->param( $_ => $arm_labels{$_} );
                }
            }
        }    # foreach template parameter
    }
    else {    ##Staus of access rights
        $arm_tmpl =
            HTML::Template->new(
            filename => $forms_tmpl_dir . "no_access.tmpl" );

        #LOGOUT BOTTON#
        my $logout_button =
              "<a href=\""
            . $SCRIPT_NAME . "?sid="
            . $sid
            . ",logout\">"
            . __("Logout") . "</a>";
        $arm_tmpl->param( 'LOGOUT' => $logout_button );
        #ERROR#
        $apiis->status(1);
        $session{'errors'}
            .= " !!! " . @{ $apiis->Auth->errors }[0]->msg_short . " !!! -";
        $session{'errors'} .= " " . @{ $apiis->Auth->errors }[0]->msg_long;
        $arm_tmpl->param( 'ERROR' => $session{'errors'} );
        #SID#
        $arm_tmpl->param( 'session_id' => $sid );
        #Action in form#
        $arm_labels{form_action} = $SCRIPT_NAME;
    }

    return $arm_tmpl->output, $header, \%mysession unless ($status);
    return $arm_tmpl->output, $header, \%mysession, $form_menu_tmpl->output
        if ($status);
}
##############################################################################

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

1;
