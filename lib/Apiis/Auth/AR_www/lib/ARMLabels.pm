package ARM::ARMLabels;
##############################################################################
# $Id: ARMLabels.pm,v 1.21 2006/08/21 11:30:06 marek Exp $
##############################################################################
use Apiis::Init;

=head1 NAME

ARMLabels.pm

=head1 DESCRIPTION
 
 Hash with ARM web interface elements, like labels, predefined drop-down lists etc.

=cut

sub get_arm_labels {
    my $used_form = shift;
    my %forms_desc;

    if ( $used_form eq "index.cgi" ) {
        %forms_desc = (
            l_page_keywords => __(
                "access, apiis, access rights, security, database security, access manager, open source, postgresql security "
            ),
            l_page_description => __( "Access Rights Control System" ),
        );
    }

    if ( $used_form eq "users" ) {
        %forms_desc = (
            l_arm_showusers_login    => __("LOGIN"),
            l_arm_showusers_user     => __("USER"),
            l_arm_showusers_lang     => __("LANGUAGE"),
            l_arm_showusers_roles    => __("ROLES"),
            l_arm_showusers_marker   => __("MARKER"),
            l_arm_showusers_disabled => __("STATUS"),
            l_arm_showusers_modify   => __("Modify user"),
            l_arm_add_new_user       => __("Add New User"),
            l_form_users             => __("Access Rights Manager - U S E R S"),
            users_list_subloop       => sub {
                my $data_lang = shift;
                my $param     = shift @_;
                return ARM::ARMReadDB::select_user_or_roles( "users",
                    $param );
            },
        );
    }

    if ( $used_form eq "st_roles" or $used_form eq "dbt_roles" ) {
        %forms_desc = (
            l_arm_showroles_name   => __("ROLE"),
            l_arm_showroles_type   => __("TYPE"),
            l_arm_showroles_subset => __("ROLE SUBSET"),
            l_arm_showroles_descr  => __("DESCRIPTION"),
            l_form_st_roles  => __("Access Rights Manager - System Roles"),
            l_form_dbt_roles => __("Access Rights Manager - Database Roles"),
            l_arm_showroles_dbtr_header => __("DATABASE ROLES"),
            l_arm_showroles_str_header  => __("SYSTEM ROLES"),
            l_arm_add_new_role          => __("Add New Role"),
            stroles_list_subloop        => sub {
                my $data_lang = shift;
                my $param     = shift @_;
                return ARM::ARMReadDB::select_user_or_roles( "roles", "ST",
                    $param );
            },
            dbtroles_list_subloop => sub {
                my $data_lang = shift;
                my $param     = shift @_;
                return ARM::ARMReadDB::select_user_or_roles( "roles",
                    "DBT", $param );
            },
        );
    }
    if ( $used_form eq "user" ) {
        %forms_desc = (
            l_form_user            => __("Access Rights Manger - User profile"),
            l_arm_user_login       => __("Login"),
            l_arm_user_marker      => __("Marker"),
            l_arm_user_status      => __("Status"),
            l_arm_user_locked      => __("LOCKED"),
            l_arm_user_unlocked    => __("UNLOCKED"),
            l_arm_user_fname       => __("First Name"),
            l_arm_user_sname       => __("Second Name"),
            l_arm_user_email       => __("E-mail"),
            l_arm_user_language    => __("Language"),
            l_arm_user_institution => __("Institution"),
            l_arm_user_street      => __("Street"),
            l_arm_user_town        => __("Town"),
            l_arm_user_zip         => __("Zip"),
            l_arm_user_country     => __("Country"),
            l_arm_user_remarks     => __("Remarks"),
            l_arm_user_pass1       => __("New Password"),
            l_arm_user_pass2       => __("Retype Password"),
            l_arm_user_req_fields  => __("required fields"),
            js_submit_user         => " onsubmit=\"return check_password();\""
        );
    }

    if ( $used_form eq "role" ) {
        %forms_desc = (
            l_arm_role_name                   => __("ROLE NAME"),
            l_arm_role_lname                  => __("LONG NAME"),
            l_arm_role_type                   => __("ROLE TYPE"),
            l_arm_role_subset                 => __("ROLE SUBSET"),
            l_arm_role_descr                  => __("DESCRIPTION"),
            l_arm_role_policies               => __("POLICIES"),
            l_arm_role_stpolicy_name          => __("Action name"),
            l_arm_role_stpolicy_type          => __("Action type"),
            l_arm_role_stpolicy_descr         => __("Description"),
            l_arm_role_dbtpolicy_action       => __("SQL action"),
            l_arm_role_dbtpolicy_table        => __("Table name"),
            l_arm_role_dbtpolicy_columns      => __("Column names"),
            l_arm_role_dbtpolicy_descriptor_n => __("Descriptor name"),
            l_arm_role_dbtpolicy_descriptor_v => __("Descriptor value"),
            l_arm_submit_marked_policies      => __("Update"),
            l_arm_submit_role => __("Submit the initial role information"),
            l_form_role       => __("Access Rights Manager - R O L E"),
            js_submit_role    => " onsubmit=\"return check_role_name();\""
        );
    }

    if ( $used_form eq "user_roles" ) {
        %forms_desc = (
            l_arm_user        => __("User"),
            l_arm_st_roles    => __("System Task Roles"),
            l_arm_dbt_roles   => __("Database Task Roles"),
            l_form_user_roles => __("Access Rights Manager - user roles"),
        );
    }

    if ( $used_form eq "st_policies" or $used_form eq "dbt_policies" ) {
        %forms_desc = (
            l_form_st_policies                  => __("System Task Policies"),
            l_form_dbt_policies                 => __("Database Task Policies"),
            l_arm_policy_stpolicy_name          => __("ACTION NAME"),
            l_arm_policy_stpolicy_type          => __("ACTION TYPE"),
            l_arm_policy_stpolicy_descr         => __("DESCRIPTION"),
            l_arm_policy_dbtpolicy_action       => __("SQL ACTION"),
            l_arm_policy_dbtpolicy_table        => __("TABLE NAME"),
            l_arm_policy_dbtpolicy_columns      => __("COLUMN NAMES"),
            l_arm_policy_dbtpolicy_descriptor_n => __("DESCRIPTOR NAME"),
            l_arm_policy_dbtpolicy_descriptor_v => __("DESCRIPTOR VALUE"),
            l_arm_submit_marked_policies        => __("Update"),
            l_arm_add_new_policy                => __("Add New Policy"),
            l_arm_add_new_table                 => __("Add/Edit Table"),
            l_arm_add_new_descriptor            => __("Add/Edit Descriptor"),
        );
    }

    if ( $used_form eq "tables" ) {
        %forms_desc = (
            l_form_tables           => __("Table Definitions"),
            l_arm_table_name        => __("TABLE NAME"),
            l_arm_table_col_current =>
                __("ALL COLUMNS FOR SELECTED TABLE (readonly)"),
            l_arm_table_col_update => __("DEFINED TABLE COLUMNS (update here)"),
            l_arm_table_desc       => __("DESCRIPTION"),
            l_arm_add_new_table    => __("Add New Table"),
            l_arm_back_button      => __("Back to the policy definitions"),
        );
    }

    if ( $used_form eq "choose_table" ) {
        %forms_desc = (
            l_form_choose_table => __("Choose table/column set for the policy"),
            l_arm_table_name    => __("TABLE NAME"),
            l_arm_table_columns => __("TABLE COLUMNS"),
        );
    }

    if ( $used_form eq "descriptors" ) {
        %forms_desc = (
            l_form_descriptors       => __("Descriptor Definitions"),
            l_arm_descriptor_name    => __("NAME"),
            l_arm_descriptor_value   => __("VALUE(S)"),
            l_arm_descriptor_desc    => __("DESCRIPTION"),
            l_arm_descriptor_info    => __("NOTICE: If you define values for descriptor than you have to always put 
                                            operator before each value. There are the following operators which 
                                            can be used: (=) (>) (<) (><)"),
            l_arm_add_new_descriptor => __("Add New Descriptor"),
            l_arm_back_button        => __("Back to the policy definitions"),
        );
    }

    if ( $used_form eq "descriptors_define_sql" ) {
        %forms_desc = (
            l_form_descriptors_define_sql =>
                __("Define SQL which return the values for descriptor"),
            l_arm_descriptor_name  => __("NAME"),
            l_arm_descriptor_value => __("VALUE(S)"),
            l_arm_descriptor_desc  => __("DESCRIPTION"),
            l_arm_submit_button    => __("Submit values"),
        );
    }

    if ( $used_form eq "choose_descriptor" ) {
        %forms_desc = (
            l_form_choose_descriptor => __("Choose descriptor for the policy"),
            l_arm_descriptor_name    => __("NAME"),
            l_arm_descriptor_value   => __("VALUE(S)"),
        );
    }

    ## all forms ##
    $forms_desc{'l_arm_submit'}       = __("Submit");
    $forms_desc{'l_arm_submit_close'} = __("Close");
    $forms_desc{'l_arm_checkall'}     = __("Check all");
    $forms_desc{'l_arm_bottom'}       = __("Go to bottom");
    $forms_desc{'l_arm_top'}          = __("Back to top");
    $forms_desc{'js_change'}          =
          " onchange=\"setstatus(document.getElementById('"
        . $used_form
        . "'));\"",
        $forms_desc{'js_submit'} = " onsubmit=\"return check_status();\"";
    $forms_desc{'js_submit_button'} =
        " onclick=\"document.forms[0].action.value=\'arm"
        . $used_form . "\';\"";
    ## all forms ##

    return \%forms_desc;
}

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

1;
