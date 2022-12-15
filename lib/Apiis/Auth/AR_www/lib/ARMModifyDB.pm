package ARM::ARMModifyDB;
##############################################################################
# $Id: ARMModifyDB.pm,v 1.7 2020/03/31 19:43:41 ulf Exp $
##############################################################################

=head1 NAME

ARM::lib::ARMModifyDB

=head1 SYNOPSIS

 This module stores all subroutines which read the data from the database.

=head1 DESCRIPTION

 long description of your module

=head1 SEE ALSO

 need to know things before somebody uses your program
use strict;

=head1 METHODS

=cut

##############################################################################
use Apiis::Init;
use Data::Dumper;
use ARMReadDB;

use Env qw( APIIS_HOME );
 push @INC, "$APIIS_HOME/lib/Apiis/Auth";
 require AR_User;
 require AR_Common;
 require AR_View;
 require AR_Component;
##############################################################################

#### USER SECTION ############################################################

=head2 modify_user 
	
   This subroutine is responsible for updating or inserting user data.

=cut

sub modify_user {
    my $form_input     = shift;
    my $from_interface = 1;
    my $errors;

    my $first_name       = $form_input->{'ar_users__user_first_name'};
    my $second_name      = $form_input->{'ar_users__user_second_name'};
    my $institution      = $form_input->{'ar_users__user_institution'};
    my $user_email       = $form_input->{'ar_users__user_email'};
    my $user_country     = $form_input->{'ar_users__user_country'};
    my $user_street      = $form_input->{'ar_users__user_street'};
    my $user_town        = $form_input->{'ar_users__user_town'};
    my $user_zip         = $form_input->{'ar_users__user_zip'};
    my $user_other_info  = $form_input->{'ar_users__user_other_info'};
    my $user_login       = $form_input->{'ar_users__user_login'};
    my $user_language_id = $form_input->{'ar_users__user_language_id'};
    my $user_marker      = $form_input->{'ar_users__user_marker'};
    my $pass1            = $form_input->{'ar_users__pass1'};
    my $pass2            = $form_input->{'ar_users__pass2'};
    my $show_user        = $form_input->{'show_apply'};
    my $user_disabled    = $form_input->{'ar_users__user_disabled'};

    my $enc_pass;
    if ( ( $pass1 ne "" ) and ( $pass2 ne "" ) and ( $pass1 eq $pass2 ) ) {
        use Digest::MD5 qw(md5_base64);
        $enc_pass = md5_base64($pass1);
        if ( $apiis->User->id eq $user_login ) {
            $errors = __("Password changed - please logout from the system");
        }
    }

    if ( $form_input->{'form_status'} eq "update" ) {
        #UPDATE USER INFORMATION#
        my $upd_record =
            Apiis::DataBase::Record->new( tablename => 'ar_users', );
        $upd_record->column('user_id')->extdata($show_user);

        my @records_to_update = $upd_record->fetch;
        foreach my $thisrecord (@records_to_update) {
            if ( defined $pass2 and $pass2 ne "" ) {
                $thisrecord->column('user_password')->extdata($enc_pass);
            }
            $thisrecord->column('user_language_id')->extdata($user_language_id);
            $thisrecord->column('user_marker')->extdata($user_marker);
            $thisrecord->column('user_disabled')->extdata($user_disabled);
            $thisrecord->update();
            $thisrecord->check_status;
            if ( !$thisrecord->status ) {
                $apiis->log( 'debug', "User '$user_login' changed" );
                $apiis->DataBase->commit;
                $apiis->check_status;

                my $upd_record_1 =
                    Apiis::DataBase::Record->new( tablename => 'ar_users_data',
                    );
                $upd_record_1->column('user_id')->extdata($show_user);

                my @records_to_update_1 = $upd_record_1->fetch;
                foreach my $thisrecord_1 (@records_to_update_1) {
                    $thisrecord_1->column('user_first_name')
                        ->extdata($first_name);
                    $thisrecord_1->column('user_second_name')
                        ->extdata($second_name);
                    $thisrecord_1->column('user_institution')
                        ->extdata($institution);
                    $thisrecord_1->column('user_street')->extdata($user_street);
                    $thisrecord_1->column('user_town')->extdata($user_town);
                    $thisrecord_1->column('user_zip')->extdata($user_zip);
                    $thisrecord_1->column('user_email')->extdata($user_email);
                    $thisrecord_1->column('user_country')
                        ->extdata($user_country);
                    $thisrecord_1->column('user_other_info')
                        ->extdata($user_other_info);
                    $thisrecord_1->update();
                    $thisrecord_1->check_status;

                    if ( !$thisrecord_1->status ) {
                        $apiis->log( 'debug',
                            "Address data for user '$user_login' changed" );
                        $apiis->DataBase->commit;
                        $apiis->check_status;
                    }
                }
            }
            else {
                if ( not defined $user_language_id
                        or $user_language_id eq "" )
                {
                   $errors = __("Please, choose the language - can not be null");
                }
                else {
                   $errors = " "
                        . @{ $thisrecord->errors }[0]->msg_short . " "
                        . @{ $thisrecord->errors }[0]->msg_long;
                }
                $apiis->errors( $thisrecord->errors );
                $apiis->status(1);
            }
        }
    }
    elsif ( $form_input->{'form_status'} eq "insert" ) {
        EXIT: {
            #check if the user is existing inPostgreSQL
            my $pguser_status = 0;
            my $sql_pguser    =
                "select usename from pg_catalog.pg_user where usename='$user_login'";
            my $sql_ref_pg = $apiis->DataBase->sys_sql($sql_pguser);
            if ( $sql_ref_pg->status ) {
                $apiis->errors( $sql_ref_pg->errors );
            }
            else {
                $pguser_status = 1 if ( $sql_ref_pg->handle->rows );
            }

            #create new PostgreSQL user
            if ( !$pguser_status ) {
                #system("createuser -W $user"); #parametr -W Pg password
#my $sql_create_pguser = "create user $user_login password '$pass1' nocreatedb nocreateuser";
                #-- since 10.0 without nocreateuser 
                my $sql_create_pguser = "create user $user_login password '$pass1' nocreatedb ";
                my $sql_ref_cpguser =
                    $apiis->DataBase->sys_sql($sql_create_pguser);
                if ( $sql_ref_cpguser->status ) {
                    $apiis->errors( $sql_ref_cpguser->errors );
                    $apiis->status(1);
                }
            }
            #create user schema
            create_schema( $user_login, 1 );
            if ( $apiis->status ) {
                $apiis->DataBase->sys_dbh->rollback;
                last EXIT;
            }
            else {
                $apiis->DataBase->commit;
            }

            #create apiis user
            my $apiis_status  = 0;
            my $sql_apiisuser =
                "select user_id from ar_users where user_login='$user_login'";
            my $sql_ref_apiis = $apiis->DataBase->sys_sql($sql_apiisuser);
            if ( $sql_ref_apiis->status ) {
                $apiis->errors( $sql_ref_apiis->errors );
            }
            else {
                $apiis_status = 1 if ( $sql_ref_apiis->handle->rows );
            }
            if ( !$apiis_status ) {
                my $user_id =
                    $apiis->DataBase->seq_next_val('seq_ar_users__user_id');
                my $ins_record =
                    Apiis::DataBase::Record->new( tablename => 'ar_users', );
                $ins_record->check_status;

                $ins_record->column('user_id')->extdata($user_id);
                $ins_record->column('user_password')->extdata($enc_pass);
                $ins_record->column('user_language_id')
                    ->extdata($user_language_id);
                $ins_record->column('user_login')->extdata($user_login);
                $ins_record->column('user_marker')->extdata($user_marker);
                $ins_record->column('user_status')->extdata('n');
                $ins_record->column('user_disabled')->extdata($user_disabled);
                $ins_record->insert();
                $ins_record->check_status;

                if ( $ins_record->status ) {
                    if ( !$enc_pass ) {
                        $errors = __("Please, set the password - can not be null");
                    }
                    elsif ( not defined $user_language_id
                        or $user_language_id eq "" )
                    {
                        $errors = __("Please, choose the language - can not be null");
                    }
                    else {
                        $errors = " "
                            . @{ $ins_record->errors }[0]->msg_short . " "
                            . @{ $ins_record->errors }[0]->msg_long;
                    }
                    $apiis->errors( $ins_record->errors );
                    $apiis->status(1);
                }
                else {
                    $apiis->DataBase->commit;
                    $apiis->check_status;

                    my $ins_record_1 =
                        Apiis::DataBase::Record->new(
                        tablename => 'ar_users_data', );
                    $ins_record_1->check_status;

                    $ins_record_1->column('user_id')->extdata($user_id);
                    $ins_record_1->column('user_first_name')
                        ->extdata($first_name);
                    $ins_record_1->column('user_second_name')
                        ->extdata($second_name);
                    $ins_record_1->column('user_institution')
                        ->extdata($institution);
                    $ins_record_1->column('user_street')->extdata($user_street);
                    $ins_record_1->column('user_town')->extdata($user_town);
                    $ins_record_1->column('user_zip')->extdata($user_zip);
                    $ins_record_1->column('user_email')->extdata($user_email);
                    $ins_record_1->column('user_country')
                        ->extdata($user_country);
                    $ins_record_1->column('user_other_info')
                        ->extdata($user_other_info);
                    $ins_record_1->insert();
                    $ins_record_1->check_status;

                    if ( $ins_record_1->status ) {
                        $errors = " "
                            . @{ $ins_record_1->errors }[0]->msg_short . " "
                            . @{ $ins_record_1->errors }[0]->msg_long;
                        $apiis->errors( $ins_record_1->errors );
                        $apiis->status(1);
                    }
                    else {
                        $apiis->DataBase->commit;
                        $apiis->check_status;
                        $errors =
                            __("New user '$user_login' added to the system");
                        $show_user = $user_id;
                    }
                }
            }
            else {
                $errors = __("User with login '$user_login' already exists");
            }
        }    #EXIT
    }
    return $errors, $show_user;
}
##############################################################################

=head2 call_delete_user 
	
   This subroutine calls function AR_Users::delete_user which removes
   user from the system.

=cut

sub call_delete_user {
    my $user_to_delete = shift;
    my $from_interface = 1;
    my $errors;

    EXIT: {
        my $sql_1 =
            "SELECT user_id FROM ar_users where user_login='$user_to_delete'";
        my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
        if ( $sql_ref_1->status ) {
            $apiis->errors( $sql_ref_1->errors );
            last EXIT;
        }
        my @ret         = $sql_ref_1->handle->fetchrow_array;
        my $ret_user_id = $ret[0];

        if ( $ret_user_id eq $apiis->Auth->user_id ) {
            $errors =
                __("You can not remove user which you are currently  using.");
            last EXIT;
        }
        #create user schema
        delete_user( $user_to_delete, 'del_user', $from_interface );
        if ( $apiis->status ) {
            $apiis->DataBase->sys_dbh->rollback;
            $errors =
                __(
                "!!!Error!!! User '$user_to_delete' NOT removed from the system"
                );
            last EXIT;
        }
        else {
            $apiis->DataBase->commit;
            $errors = __("User '$user_to_delete' removed from the system");
        }
    }    #EXIT
    return $errors;
}

##############################################################################

=head2 update_user_roles 
	
   This subroutine change the list of roles which are assigned to the user. 

=cut

sub update_user_roles {
    my ( $user, $cr, $new_roles ) = @_;
    my $from_interface = 1;
    my @current_roles = split( ',', $cr );
    my ( @revoked_roles, @assigned_roles );
    my $errors = undef;

    EXIT: {
        my $sql_1 =
            "SELECT user_marker,user_id FROM ar_users where user_login='$user'";
        my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
        if ( $sql_ref_1->status ) {
            $apiis->errors( $sql_ref_1->errors );
            last EXIT;
        }
        my @ret         = $sql_ref_1->handle->fetchrow_array;
        my $user_marker = $ret[0];
        my $ret_user_id = $ret[1];

        if ( $ret_user_id eq $apiis->Auth->user_id ) {
            $errors = __(
                "You can not change the role definitions for yourself (security reasons).
                If you want to do this, you can create new user with the same access 
                rights and this new user will be able to change your access rights."
            );
            last EXIT;
        }

        foreach my $curr (@current_roles) {
            if ( !( grep( /^$curr$/, @$new_roles ) ) ) {
                push @revoked_roles, $curr;
                $apiis->log( 'debug', "Role $curr revoked from the user" );
            }
        }
        foreach my $newr (@$new_roles) {
            if ( !( grep( /^$newr$/, @current_roles ) ) ) {
                push @assigned_roles, $newr;
                $apiis->log( 'debug', "Role $newr assigned to the user" );
            }
        }

        check_users_table();
        revoke_role_from_user( \@revoked_roles, $user, $from_interface )
            if ( @revoked_roles );
        assign_roles( \@assigned_roles, lc $user, $from_interface )
            if ( @assigned_roles );
        create_st_access_view( $user, $from_interface );
        create_dbt_access_view( $user, $from_interface );
        table_views( lc $user, $user_marker, $from_interface );

        if ( $apiis->status ) {
            $apiis->log( 'debug', "ERROR -> User roles not changed" );
            $apiis->DataBase->rollback;
        }
        else {
            $apiis->log( 'debug', "OK -> User roles changed" );
            $apiis->DataBase->commit;
        }
    }    #EXIT
    return $errors if ( defined $errors and $errors ne '' );
}
### END USER SECTION #########################################################


### ROLE SECTION #############################################################

=head2 insert_role
	
   This subroutine inserts new role in to the database.

=cut

sub insert_role {
    my $form_input     = shift;
    my $from_interface = 1;
    my $errors;

    my @current_subroles = split( ',', $form_input->{'current_subroles'} );
    my $role_name        = $form_input->{'ar_roles__role_name'};
    my $role_type        = $form_input->{'ar_roles__role_type'};
    my $descr            = $form_input->{'ar_roles__role_descr'};
    my $long_name        = $form_input->{'ar_roles__role_long_name'};
    my $role_id = $apiis->DataBase->seq_next_val('seq_ar_roles__role_id');

 EXIT: {
    my $new_sub_roles = $form_input->{'ar_role__role_subset'};
    $new_sub_roles = join( ',', @$new_sub_roles ) if (@$new_sub_roles);

    my $apiis_status  = 0;
    my $sql_role =
       "SELECT role_id FROM ar_roles WHERE role_name='$role_name'
        AND role_type='$role_type'";
    my $sql_ref_apiis = $apiis->DataBase->sys_sql($sql_role);
    if ( $sql_ref_apiis->status ) {
      $apiis->errors( $sql_ref_apiis->errors );
    }
    else {
      $apiis_status = 1 if ( $sql_ref_apiis->handle->rows );
    }
    
    if ( !$apiis_status ) {
      my $thisrecord = Apiis::DataBase::Record->new( tablename => 'ar_roles', );
      $thisrecord->column('role_id')->extdata($role_id);
      $thisrecord->column('role_name')->extdata($role_name);
      $thisrecord->column('role_type')->extdata($role_type);
      $thisrecord->column('role_long_name')->extdata($long_name);
      $thisrecord->column('role_descr')->extdata($descr);
      $thisrecord->column('role_subset')->extdata($new_sub_roles);
      $thisrecord->insert();
      $thisrecord->check_status;
      if ( !$thisrecord->status ) {
        $apiis->log( 'debug', "Role '$role_name' added" );
        $apiis->DataBase->commit;
        $apiis->check_status;
      }
      else {
        $apiis->status(1);
        $errors = " !!! " . @{ $thisrecord->errors }[0]->msg_short . " !!! -";
        $errors .= " " . @{ $thisrecord->errors }[0]->msg_long;
        last EXIT; 
      }
    }
    else {
                $errors = __("Role with the name '$role_name' already exists");
    }
 }    #EXIT
    return $errors, $role_id;
}

##############################################################################

=head2 update_role 
	
   This subroutine changes information about selected role. If the role 
   definition is changed then the access rights of users which have this role 
   are also reloaded.

=cut

sub update_role {
    my $form_input     = shift;
    my $from_interface = 1;
    my $errors;

    my @current_subroles = split( ',', $form_input->{'current_subroles'} );
    my $role_name        = $form_input->{'ar_roles__role_name'};
    my $descr            = $form_input->{'ar_roles__role_descr'};
    my $long_name        = $form_input->{'ar_roles__role_long_name'};
    my $role_id          = $form_input->{'show_apply'};

    my $new_sub_roles = $form_input->{'ar_role__role_subset'};
    $new_sub_roles = join( ',', @$new_sub_roles ) if (@$new_sub_roles);

    my @roles_to_reload;
    my %hash = ( role_id => $role_id, role_name => $role_name );
    push @roles_to_reload, \%hash;

  EXIT:{
    #UPDATE ROLE INFORMATION#
    my $upd_record = Apiis::DataBase::Record->new( tablename => 'ar_roles', );
    $upd_record->column('role_id')->extdata($role_id);

    my @records_to_update = $upd_record->fetch;
    foreach my $thisrecord (@records_to_update) {
        $thisrecord->column('role_long_name')->extdata($long_name);
        $thisrecord->column('role_descr')->extdata($descr);
        $thisrecord->column('role_subset')->extdata($new_sub_roles);
        $thisrecord->update();
        $thisrecord->check_status;
        if ( !$thisrecord->status ) {
            $apiis->log( 'debug', "Role '$role_name' changed" );
            $apiis->DataBase->commit;
            $apiis->check_status;
        }
        else {
            $apiis->status(1);
            $errors = " !!! " . @{ $thisrecord->errors }[0]->msg_short . " !!! -";
            $errors .= " " . @{ $thisrecord->errors }[0]->msg_long;
            last EXIT; 
        }
    }
    ##CHECK IF TEH ROLE HAS TO BE RELOADE FOR THE USERS ##
    my @new_sub_roles_array = split( ',', $new_sub_roles );
    my $reload_roles = 0;
    $reload_roles = 1 if (!@new_sub_roles_array);
    foreach my $newsr (@new_sub_roles_array) {
        if ( !( grep( /^$newsr$/, @current_subroles ) ) ) {
            $reload_roles = 1;
            last;
        }
    }

    foreach my $current (@current_subroles) {
        if ( !( grep( /^$current$/, @new_sub_roles_array ) ) ) {
            $reload_roles = 1;
            last;
        }
    }

    if ($reload_roles) {
        push my @roles, $role_name;
        my $ret_roles = 
          ARM::ARMReadDB::get_subroles_for_reload(\@roles,\@roles_to_reload);

        check_users_table();
        #CHECK THE USERS WHICH HAVE SUCH ROLE DEFINITUONS#
        #And reload their access rights#
        $errors = reloading_role_definitions_for_selected_users(\@$ret_roles);
    }
  }#EXIT
  return $errors;
}
##############################################################################

=head2 call_delete_role 
	
   This subroutine calls function AR_Component::delete_role which removes role 
   from the stystem.

=cut

sub call_delete_role {
  my $role_to_delete = shift;
  my $from_interface = 1;
  my $errors;

 EXIT: {
  delete_role( $role_to_delete, $from_interface );
  if ( $apiis->status ) {
    $apiis->DataBase->rollback;
    $errors = " !!! " . @{ $apiis->errors }[0]->msg_short . " !!! -";
    $errors .= " " . @{ $apiis->errors }[0]->msg_long;
    last EXIT;
  }
  else {
    $apiis->DataBase->commit;
    $errors = __("Role removed from the system");
  }
 }#EXIT
 return $errors;
}
##############################################################################

=head2 update_role_policies
	
   This subroutine changes list of policies which are assigned to role. If  
   definition of policies is changed then the access rights of users which have 
   this role are also reloaded.

=cut

sub update_role_policies {
   my ($new_policy_ids,$existing_policy_ids,
       $role_name,$role_id,$role_type) = @_;
   my (@policies_to_add,@policies_to_remove);
   my $errors;

 EXIT:{
   foreach my $new (@$new_policy_ids){
     push @policies_to_add, $new 
        unless (grep (/^$new$/,@$existing_policy_ids));
   }

   foreach my $existing (@$existing_policy_ids){
     push @policies_to_remove, $existing 
        unless (grep (/^$existing$/,@$new_policy_ids));
   }

   if (@policies_to_add){
     my $joined_policies = join (',',@policies_to_add);
     my %tmp_hash;
     $tmp_hash{$role_name}{'TYPE'} = $role_type;
     $tmp_hash{$role_name}{'ROLE_POLICIES'} = $joined_policies;
     assign_policy(\%tmp_hash,1); 
     if ($apiis->status) {
       $errors = " !!! " . @{ $apiis->errors }[0]->msg_short . " !!! -";
       $errors .= " " . @{ $apiis->errors }[0]->msg_long;
       last EXIT; 
     }
   }
   if (@policies_to_remove) {
     remove_policies_from_role(\@policies_to_remove,$role_id,$role_type);
     if ($apiis->status) {
       $errors = " !!! " . @{ $thisrecord->errors }[0]->msg_short . " !!! -";
       $errors .= " " . @{ $thisrecord->errors }[0]->msg_long;
       last EXIT; 
     }
   }
   #update role for the user which have it
   my @roles_to_reload;
   my %tmp_hash = (
      role_id   => $role_id,
      role_name => $role_name,
   );
   push @roles_to_reload, \%tmp_hash; 

   push my @roles, $role_name;
   my $ret_roles = 
   ARM::ARMReadDB::get_subroles_for_reload(
        \@roles,\@roles_to_reload
   );

   check_users_table();
   $errors = reloading_role_definitions_for_selected_users(\@$ret_roles);

 }#EXIT;   
 return $errors;
}
##############################################################################

=head2 remove_policies_from_role
	
   This subroutine removes policies from the role definition.

=cut


sub remove_policies_from_role {
  my ($policies_to_remove,$role_id,$role_type) = @_;
  my $sql;

  my $joined_policies = join (',',@$policies_to_remove);
  
  if ($role_type eq "ST") {
    $sql ="DELETE FROM ar_role_stpolicies 
            WHERE role_id=$role_id AND stpolicy_id IN ($joined_policies)";
  }
  elsif ($role_type eq "DBT") {
    $sql ="DELETE FROM ar_role_dbtpolicies 
            WHERE role_id=$role_id AND dbtpolicy_id IN ($joined_policies)";
  }
  
  my $fetched  = $apiis->DataBase->sys_sql($sql);
  if ($fetched->status) {
    $apiis->errors( $fetched->errors );
    $apiis->status(1);
  }
}
### END SECTION ROLE #########################################################

### SECTION SYSTEM TASK POLICY ###############################################

=head2 insert_stpolicy
	
   This inserts new system task policy .

=cut


sub insert_stpolicy {
  my $policy_data = shift;
  my $errors = undef;

 EXIT:{
  my $sql_0 =
         "SELECT stpolicy_id FROM ar_stpolicies
          WHERE stpolicy_name ='".%{$policy_data->{'policy_name'}}."' 
            AND stpolicy_type ='".%{$policy_data->{'policy_type'}}."'
         ";
  my $sql_ref_0 = $apiis->DataBase->sys_sql($sql_0);
  if ( $sql_ref_0->status ) {
     $apiis->errors( $sql_ref_0->errors );
     last EXIT;
  }
  my $ret_0 = $sql_ref_0->handle->rows;

  if (defined $ret_0 and $ret_0 != 0) {
    $errors = __("The policy which you are trying to 
               enter is already defined in the database");
  }
  else {
    my $sql_1 =
         "SELECT max(stpolicy_id) FROM ar_stpolicies";
    my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
    if ( $sql_ref_1->status ) {
      $apiis->errors( $sql_ref_1->errors );
      last EXIT;
    }
    my $ret = $sql_ref_1->handle->fetch;
    my $stpolicy_id =$$ret[0]+1;

    my $ins_record =
        Apiis::DataBase::Record->new( tablename => 'ar_stpolicies', );
    $ins_record->check_status;

    $ins_record->column('stpolicy_id')->extdata($stpolicy_id);
    $ins_record->column('stpolicy_name')->extdata(%{$policy_data->{'policy_name'}});
    $ins_record->column('stpolicy_type')->extdata(%{$policy_data->{'policy_type'}});
    $ins_record->column('stpolicy_desc')->extdata(%{$policy_data->{'policy_desc'}});
    $ins_record->insert();
    $ins_record->check_status;

    if ( !$ins_record->status ) {
      $apiis->log( 'debug', "New policy added" );
      $apiis->DataBase->commit;
      $apiis->check_status;
    }
    else {
      $apiis->status(1);
      $errors = " !!! " . @{ $ins_record->errors }[0]->msg_short . " !!! -";
      $errors .= " " . @{ $ins_record->errors }[0]->msg_long;
      last EXIT; 
    }
  }
 }#EXIT
 return $errors;
}
##############################################################################

=head2 update_stpolicy
	
   This subroutine updates single system task policy. If definition of policy 
   is changed then the access rights of users which have this policy 
   are also changed.

=cut

sub update_stpolicy {
  my $policy_data = shift;
  my $errors = undef;

 EXIT:{ 
  my $sql_0 =
         "SELECT stpolicy_id FROM ar_stpolicies
          WHERE stpolicy_name ='".%{$policy_data->{'policy_name'}}."' 
            AND stpolicy_type ='".%{$policy_data->{'policy_type'}}."'
         ";
  my $sql_ref_0 = $apiis->DataBase->sys_sql($sql_0);
  if ( $sql_ref_0->status ) {
     $apiis->errors( $sql_ref_0->errors );
     last EXIT;
  }
  my $ret_0 = $sql_ref_0->handle->rows;

 
  my $upd_record =
     Apiis::DataBase::Record->new( tablename => 'ar_stpolicies', );
  $upd_record->column('stpolicy_id')->extdata(%{$policy_data->{'policy_id'}});
 
  my @records_to_update = $upd_record->fetch;
  foreach my $thisrecord (@records_to_update) {
    if ($ret_0 == 0) {
      $thisrecord->column('stpolicy_name')->extdata(%{$policy_data->{'policy_name'}})
        if (%{$policy_data->{'policy_name'}});
      $thisrecord->column('stpolicy_type')->extdata(%{$policy_data->{'policy_type'}})
        if (%{$policy_data->{'policy_type'}});
    }
    $thisrecord->column('stpolicy_desc')->extdata(%{$policy_data->{'policy_desc'}})
      if ( %{$policy_data->{'policy_desc'}});
    $thisrecord->update();
    $thisrecord->check_status;
    if ( !$thisrecord->status ) {
      $apiis->log( 'debug', "Policy definition changed" );
      $apiis->DataBase->commit;
      $apiis->check_status;
    } 
    else {
      $apiis->status(1);
      $errors = " !!! " . @{ $thisrecord->errors }[0]->msg_short . " !!! -";
      $errors .= " " . @{ $thisrecord->errors }[0]->msg_long;
      last EXIT; 
    }
  }
  
  ### select roles which have this policy
  my $sql_1     = "SELECT a.role_id,a.role_name 
                    FROM ar_roles a, ar_role_stpolicies b
                    WHERE a.role_id = b.role_id 
                      AND b.stpolicy_id =".%{$policy_data->{'policy_id'}};
  my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
  if ( $sql_ref_1->status ) {
    $apiis->errors( $sql_ref_1->errors );
    last EXIT;
  }

  my $rows = $sql_ref_1->handle->rows;
  my (@role_names,@roles_to_reload);
  if ($rows) {
    while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
      my %tmp_hash = (
           role_id   => $ret[0],
           role_name => $ret[1],
         );
      push @role_names, $ret[1];
      push @roles_to_reload, \%tmp_hash;
    }
    
    my $ret_roles = 
      ARM::ARMReadDB::get_subroles_for_reload(\@roles,\@roles_to_reload);
    check_users_table();
    $errors = reloading_role_definitions_for_selected_users(\@$ret_roles);
  }

 }#EXIT
 return $errors;
}
##############################################################################

=head2 delete_stpolicy
	
   This subroutine removes single policy form the database and the reloads
   the roles and user access rights.

=cut

sub delete_stpolicy {
  my $policy_id = shift;
  my $reload_roles = 0;
  my @roles_to_reload;
  my @role_names;
  my $errors;
  
 EXIT:{
  $sql = "DELETE FROM ar_stpolicies 
            WHERE stpolicy_id IN ($policy_id)";

  my $fetched  = $apiis->DataBase->sys_sql($sql);
  if ($fetched->status) {
    $apiis->status(1);
    $errors = " !!! " . @{ $fetched->errors }[0]->msg_short . " !!! -";
    $errors .= " " . @{ $fetched->errors }[0]->msg_long;
    $apiis->DataBase->sys_dbh->rollback;
    last EXIT; 
  }
  else {
    $apiis->check_status;
    $reload_roles = 1;
  }

  if ($reload_roles) {
    ### select roles which have this policy
    my $sql_1     = "SELECT a.role_id,a.role_name 
                     FROM ar_roles a, ar_role_stpolicies b
                     WHERE a.role_id = b.role_id AND b.stpolicy_id = $policy_id";
    my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
    if ( $sql_ref_1->status ) {
      $apiis->errors( $sql_ref_1->errors );
      last EXIT;
    }

    my $rows = $sql_ref_1->handle->rows;
    if ($rows) {
      while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
        my %tmp_hash = (
             role_id   => $ret[0],
             role_name => $ret[1],
           );
        push @role_names, $ret[1];
        push @roles_to_reload, \%tmp_hash;
      }
      
      ### delete connection beetwen the roles and the policy
      $sql_3 = "DELETE FROM ar_role_stpolicies 
                WHERE stpolicy_id IN ($policy_id)";

      my $sql_ref_3  = $apiis->DataBase->sys_sql($sql_3);
      if ($sql_ref_3->status) {
        $apiis->errors( $sql_ref_3->errors );
        $apiis->status(1);
        last EXIT;
      }

      my $ret_roles = 
        ARM::ARMReadDB::get_subroles_for_reload(\@role_name,\@roles_to_reload);
      check_users_table();
      $errors = reloading_role_definitions_for_selected_users(\@$ret_roles);  
    } else {
      $apiis->log( 'debug', "OK -> ST Policy deleted" );
      $apiis->DataBase->sys_dbh->commit;
    }
  }
 }#EXIT
 return $errors;
}
### END SYSTEM TASK POLICES SECTION ##########################################

### DATABASE TASK POLICIES SECTION ###########################################

=head2 insert_dbtpolicy
	
   This subroutine insert new database task policy.

=cut

sub insert_dbtpolicy {
  my $policy_data = shift;
  my $errors = undef;

 EXIT:{
  my $sql_0 =
         "SELECT dbtpolicy_id FROM ar_dbtpolicies
          WHERE table_id =".%{$policy_data->{'table_id'}}." 
            AND descriptor_id =".%{$policy_data->{'descriptor_id'}}."
            AND action_id IN (
              SELECT db_code FROM codes 
              WHERE ext_code ='".%{$policy_data->{'action_id'}}."'
            )";
  my $sql_ref_0 = $apiis->DataBase->sys_sql($sql_0);
  if ( $sql_ref_0->status ) {
     $apiis->errors( $sql_ref_0->errors );
     last EXIT;
  }
  my $ret_0 = $sql_ref_0->handle->rows;

  if (defined $ret_0 and $ret_0 != 0) {
    $errors = __("The policy which you are trying to 
               enter is already defined in the database");
  }
  else {
    my $sql_1 =
         "SELECT max(dbtpolicy_id) FROM ar_dbtpolicies";
    my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
    if ( $sql_ref_1->status ) {
      $apiis->errors( $sql_ref_1->errors );
      last EXIT;
    }
    my $ret = $sql_ref_1->handle->fetch;
    my $dbtpolicy_id =$$ret[0]+1;

    my $ins_record =
       Apiis::DataBase::Record->new( tablename => 'ar_dbtpolicies', );
    $ins_record->check_status;

    $ins_record->column('dbtpolicy_id')->extdata($dbtpolicy_id);
    $ins_record->column('action_id')->extdata(%{$policy_data->{'action_id'}});
    $ins_record->column('descriptor_id')->extdata(%{$policy_data->{'descriptor_id'}});
    $ins_record->column('table_id')->extdata(%{$policy_data->{'table_id'}});
    $ins_record->insert();
    $ins_record->check_status;

    if ( !$ins_record->status ) {
      $apiis->log( 'debug', "New policy added" );
      $apiis->DataBase->commit;
      $apiis->check_status;
    }
    else {
      $apiis->status(1);
      $errors = " !!! " . @{ $ins_record->errors }[0]->msg_short . " !!! -";
      $errors .= " " . @{ $ins_record->errors }[0]->msg_long;
      last EXIT; 
    }
  }
 }#EXIT
 return $errors;
}
##############################################################################

=head2 update_dbtpolicy
	
   This subroutine updates single database task policy. When definition of 
   policy is changed the roles and user access rights are reloaded.

=cut

sub update_dbtpolicy {
  my $policy_data = shift;
  my $errors = undef;

 EXIT:{
  my $sql_0 =
         "SELECT dbtpolicy_id FROM ar_dbtpolicies
          WHERE table_id =".%{$policy_data->{'table_id'}}." 
            AND descriptor_id =".%{$policy_data->{'descriptor_id'}}."
            AND action_id IN (
              SELECT db_code FROM codes 
              WHERE ext_code ='".%{$policy_data->{'action_id'}}."'
            )";
  my $sql_ref_0 = $apiis->DataBase->sys_sql($sql_0);
  if ( $sql_ref_0->status ) {
     $apiis->errors( $sql_ref_0->errors );
     last EXIT;
  }
  my $ret_0 = $sql_ref_0->handle->rows;

  if (defined $ret_0 and $ret_0 != 0) {
    $errors = __("The policy which you are trying to 
               enter is already defined in the database");
  }
  else {
    my $upd_record =
         Apiis::DataBase::Record->new( tablename => 'ar_dbtpolicies', );
    $upd_record->column('dbtpolicy_id')->extdata(%{$policy_data->{'policy_id'}});
 
    my @records_to_update = $upd_record->fetch;
    foreach my $thisrecord (@records_to_update) {
      $thisrecord->column('action_id')->extdata(%{$policy_data->{'action_id'}})
        if ( %{$policy_data->{'action_id'}});
      $thisrecord->column('table_id')->extdata(%{$policy_data->{'table_id'}})
        if ( %{$policy_data->{'table_id'}});
      $thisrecord->column('descriptor_id')->extdata(%{$policy_data->{'descriptor_id'}})
        if ( %{$policy_data->{'descriptor_id'}});
      $thisrecord->update();
      $thisrecord->check_status;
      if ( !$thisrecord->status ) {
        $apiis->log( 'debug', "Policy definition changed" );
        $apiis->DataBase->commit;
        $apiis->check_status;
      }
      else {
        $apiis->status(1);
        $errors = " !!! " . @{ $thisrecord->errors }[0]->msg_short . " !!! -";
        $errors .= " " . @{ $thisrecord->errors }[0]->msg_long;
        last EXIT; 
      }
    }
  }
  
  ### select roles which have this policy
  my $sql_1     = "SELECT a.role_id,a.role_name 
                    FROM ar_roles a, ar_role_dbtpolicies b
                    WHERE a.role_id = b.role_id 
                      AND b.dbtpolicy_id =".%{$policy_data->{'policy_id'}};
  my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
  if ( $sql_ref_1->status ) {
    $apiis->errors( $sql_ref_1->errors );
    last EXIT;
  }

  my $rows = $sql_ref_1->handle->rows;
  my (@role_names,@roles_to_reload);
  if ($rows) {
    while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
      my %tmp_hash = (
           role_id   => $ret[0],
           role_name => $ret[1],
         );
      push @role_names, $ret[1];
      push @roles_to_reload, \%tmp_hash;
    }
    
    my $ret_roles = 
      ARM::ARMReadDB::get_subroles_for_reload(\@role_names,\@roles_to_reload);
    check_users_table();
    $errors = reloading_role_definitions_for_selected_users(\@$ret_roles);
  }

 }#EXIT
 return $errors;
}
##############################################################################

=head2 delete_dbtpolicy
	
   This subroutine removes database task policy from the database and then 
   reload the roles and then the user access rights.

=cut

sub delete_dbtpolicy {
  my $policy_id = shift;
  my $reload_roles = 0;
  my @roles_to_reload;
  my @role_names;
  my $errors;

 EXIT:{
  $sql = "DELETE FROM ar_dbtpolicies 
            WHERE dbtpolicy_id IN ($policy_id)";

  my $fetched  = $apiis->DataBase->sys_sql($sql);
  if ($fetched->status) {
    $apiis->errors( $fetched->errors );
    $apiis->status(1);
    $apiis->DataBase->sys_dbh->rollback;
    last EXIT;
  }
  else {
    $apiis->check_status;
    $reload_roles = 1;
  }

  if ($reload_roles) {
    ### select roles which have this policy
    my $sql_1     = "SELECT a.role_id,a.role_name 
                     FROM ar_roles a, ar_role_dbtpolicies b
                     WHERE a.role_id = b.role_id AND b.dbtpolicy_id = $policy_id";
    my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
    if ( $sql_ref_1->status ) {
      $apiis->errors( $sql_ref_1->errors );
      last EXIT;
    }

    my $rows = $sql_ref_1->handle->rows;
    if ($rows) {
      while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
        my %tmp_hash = (
             role_id   => $ret[0],
             role_name => $ret[1],
           );
        push @role_names, $ret[1];
        push @roles_to_reload, \%tmp_hash;
      }
    
      ### delete connection beetwen the roles and the policy
      $sql_3 = "DELETE FROM ar_role_dbtpolicies 
                WHERE dbtpolicy_id IN ($policy_id)";

      my $sql_ref_3  = $apiis->DataBase->sys_sql($sql_3);
      if ($sql_ref_3->status) {
        $apiis->errors( $sql_ref_3->errors );
        $apiis->status(1);
        last EXIT;
      }

      my $ret_roles = 
        ARM::ARMReadDB::get_subroles_for_reload(\@role_names,\@roles_to_reload);
      check_users_table();
      $errors = reloading_role_definitions_for_selected_users(\@$ret_roles);  
    }
    else {
      $apiis->log( 'debug', "OK -> DBT Policy deleted" );
      $apiis->DataBase->sys_dbh->commit;
    }
  }
 }#EXIT
 return $errors;
}
##############################################################################

### DESCRIPTOR SECTION #######################################################

=head2 insert_descriptor
	
   This subroutine inserts new descriptor.

=cut

sub insert_descriptor {
  my $desc_data = shift;
  my $errors = undef;

  my $descriptor_value = %{$desc_data->{'descriptor_value'}};
  $descriptor_value =~ s/\s+//g; #removes all white spaces

 EXIT:{
  my $sql_0 =
         "SELECT descriptor_id FROM ar_dbtdescriptors
          WHERE 
              descriptor_name='".%{$desc_data->{'descriptor_name'}}."'  
          AND descriptor_value='".%{$desc_data->{'descriptor_value'}}."'
         ";
  my $sql_ref_0 = $apiis->DataBase->sys_sql($sql_0);
  if ( $sql_ref_0->status ) {
     $apiis->errors( $sql_ref_0->errors );
     last EXIT;
  }
  my $ret_0 = $sql_ref_0->handle->rows;

  if (defined $ret_0 and $ret_0 != 0) {
    $errors = __("The descriptor which you are trying to 
               enter is already defined in the database");
  }
  else {
    my $sql_1 =
         "SELECT max(descriptor_id) FROM ar_dbtdescriptors";
    my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
    if ( $sql_ref_1->status ) {
      $apiis->errors( $sql_ref_1->errors );
      last EXIT;
    }
    my $ret = $sql_ref_1->handle->fetch;
    my $descriptor_id =$$ret[0]+1;

    my $ins_record =
       Apiis::DataBase::Record->new( tablename => 'ar_dbtdescriptors', );
    $ins_record->check_status;

    $ins_record->column('descriptor_id')->extdata($descriptor_id);
    $ins_record->column('descriptor_name')->extdata(%{$desc_data->{'descriptor_name'}});
    $ins_record->column('descriptor_value')->extdata($descriptor_value);
    $ins_record->column('descriptor_desc')->extdata(%{$desc_data->{'descriptor_desc'}});
    $ins_record->insert();
    $ins_record->check_status;

    if ( !$ins_record->status ) {
      $apiis->log( 'debug', "New descriptor added" );
      $apiis->DataBase->commit;
      $apiis->check_status;
    }
    else {
      $apiis->status(1);
      $errors = " !!! " . @{ $ins_record->errors }[0]->msg_short . " !!! -";
      $errors .= " " . @{ $ins_record->errors }[0]->msg_long;
      last EXIT; 
    }
  }
 }#EXIT
 return $errors;
}
##############################################################################

=head2 update_descriptor
	
   This subroutine updates information about descriptor and the reload 
   policies, roles and users which are based on it.

=cut

sub update_descriptor {
  my $desc_data = shift;
  my $errors = undef;

  my $descriptor_value = %{$desc_data->{'descriptor_value'}};
  $descriptor_value =~ s/\s+//g; #removes all white spaces

 EXIT:{
  my $sql_0 =
         "SELECT descriptor_id FROM ar_dbtdescriptors
          WHERE 
              descriptor_name='".%{$desc_data->{'descriptor_name'}}."'  
          AND descriptor_value='".%{$desc_data->{'descriptor_value'}}."'
         ";
  my $sql_ref_0 = $apiis->DataBase->sys_sql($sql_0);
  if ( $sql_ref_0->status ) {
     $apiis->errors( $sql_ref_0->errors );
     last EXIT;
  }
  my $ret_0 = $sql_ref_0->handle->rows;

  my $upd_record =
       Apiis::DataBase::Record->new( tablename => 'ar_dbtdescriptors', );
  $upd_record->column('descriptor_id')->extdata(%{$desc_data->{'descriptor_id'}});
 
  my @records_to_update = $upd_record->fetch;
  foreach my $thisrecord (@records_to_update) {
    if ($ret_0 == 0) {
      $thisrecord->column('descriptor_name')->extdata(%{$desc_data->{'descriptor_name'}})
        if ( %{$desc_data->{'descriptor_name'}});
      $thisrecord->column('descriptor_value')->extdata($descriptor_value)
        if ( %{$desc_data->{'descriptor_value'}});
    }
    $thisrecord->column('descriptor_desc')->extdata(%{$desc_data->{'descriptor_desc'}})
      if (%{$desc_data->{'descriptor_desc'}});
    $thisrecord->update();
    $thisrecord->check_status;
    if ( !$thisrecord->status ) {
      $apiis->log( 'debug', "Descriptor definition changed" );
      $apiis->DataBase->commit;
      $apiis->check_status;
    }
    else {
      $apiis->status(1);
      $errors = " !!! " . @{ $thisrecord->errors }[0]->msg_short . " !!! -";
      $errors .= " " . @{ $thisrecord->errors }[0]->msg_long;
      last EXIT; 
    }
  }
  
  my $sql_1     = "SELECT DISTINCT a.role_id, role_name 
                   FROM ar_roles a 
                   INNER JOIN ar_role_dbtpolicies  USING (role_id)  
                   WHERE dbtpolicy_id IN (
                      SELECT dbtpolicy_id 
                      FROM ar_dbtpolicies 
                      INNER JOIN ar_dbtdescriptors USING (descriptor_id)  
                      WHERE descriptor_id=".%{$desc_data->{'descriptor_id'}}."
                   )";
  my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
  if ( $sql_ref_1->status ) {
    $apiis->errors( $sql_ref_1->errors );
    last EXIT;
  }

  my $rows = $sql_ref_1->handle->rows;
  my (@role_names,@roles_to_reload);
  if ($rows) {
    while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
      my %tmp_hash = (
           role_id   => $ret[0],
           role_name => $ret[1],
         );
      push @role_names, $ret[1];
      push @roles_to_reload, \%tmp_hash;
    }
    
    my $ret_roles = 
      ARM::ARMReadDB::get_subroles_for_reload(\@role_names,\@roles_to_reload);
    check_users_table();
    $errors = reloading_role_definitions_for_selected_users(\@$ret_roles);
  }
 }#EXIT
 return $errors;
}
##############################################################################

=head2 delete_descriptor
	
   This subroutine removes descriptor from the database and then reload
   policies, roles and users which are based on it. 

=cut

sub delete_descriptor {
  my $descriptor_id = shift;
  my $errors;
  
 EXIT:{
  my $sql_1     = "SELECT descriptor_id 
                     FROM ar_dbtpolicies
                     WHERE descriptor_id = $descriptor_id";
  my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
  if ( $sql_ref_1->status ) {
    $apiis->errors( $sql_ref_1->errors );
    last EXIT;
  }

  my $rows = $sql_ref_1->handle->rows;
  if ($rows) {
    $errors = __("This descriptor is used by $rows policies.
                  You can remove only these descriptors which 
                  are not used by the policies.
                 ");
  }
  else {
    $sql = "DELETE FROM ar_dbtdescriptors 
            WHERE descriptor_id IN ($descriptor_id)";

    my $fetched  = $apiis->DataBase->sys_sql($sql);
    if ($fetched->status) {
      $apiis->errors( $fetched->errors );
      $apiis->status(1);
      last EXIT;
    }
    else {
      $apiis->check_status;
    }
  
  }

  if ( $apiis->status ) {
    $apiis->log( 'debug', "ERROR -> Descriptor not removed" );
    $apiis->DataBase->sys_dbh->rollback;
  }
  else {
    $apiis->log( 'debug', "OK -> Descriptor removed" );
    $apiis->DataBase->commit;
  }
 }#EXIT

 return $errors;
}
### END DESCRIPTOR SECTION ###################################################

### TABLE/COLUMNS SECTIONS ###################################################


=head2 insert_table
	
   This subroutine inserts new table/column set.

=cut

sub insert_table {
  my $tab_data = shift;
  my $errors = undef;
  
  my $table_columns = %{$tab_data->{'table_columns'}};
  $table_columns =~ s/\s+//g; #removes all white spaces

 EXIT:{
  my $sql_0 =
         "SELECT table_id FROM ar_dbttables
          WHERE 
              table_name='".%{$tab_data->{'table_name'}}."'  
          AND table_columns='".%{$tab_data->{'table_columns'}}."'
         ";
  my $sql_ref_0 = $apiis->DataBase->sys_sql($sql_0);
  if ( $sql_ref_0->status ) {
     $apiis->errors( $sql_ref_0->errors );
     last EXIT;
  }
  my $ret_0 = $sql_ref_0->handle->rows;

  if (defined $ret_0 and $ret_0 != 0) {
    $errors = __("The table/column set which you are trying to 
               enter is already defined in the database");
  }
  else {
    my $sql_1 =
         "SELECT max(table_id) FROM ar_dbttables";
    my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
    if ( $sql_ref_1->status ) {
      $apiis->errors( $sql_ref_1->errors );
      last EXIT;
    }
    my $ret = $sql_ref_1->handle->fetch;
    my $table_id =$$ret[0]+1;

    my $ins_record =
       Apiis::DataBase::Record->new( tablename => 'ar_dbttables', );
    $ins_record->check_status;

    $ins_record->column('table_id')->extdata($table_id);
    $ins_record->column('table_name')->extdata(%{$tab_data->{'table_name'}});
    $ins_record->column('table_columns')->extdata($table_columns);
    $ins_record->column('table_desc')->extdata(%{$tab_data->{'table_desc'}});
    $ins_record->insert();
    $ins_record->check_status;

    if ( !$ins_record->status ) {
      $apiis->log( 'debug', "New table/column set added" );
      $apiis->DataBase->commit;
      $apiis->check_status;
    }
    else {
      $apiis->status(1);
      $errors = " !!! " . @{ $ins_record->errors }[0]->msg_short . " !!! -";
      $errors .= " " . @{ $ins_record->errors }[0]->msg_long;
      last EXIT; 
    }
  }
 }#EXIT
 return $errors;
}
##############################################################################

=head2 update_table
	
   This subroutine updates single table/column set and then reload
   policies, roles and users which are based on it.

=cut

sub update_table {
  my $tab_data = shift;
  my $errors = undef;

  my $table_columns = %{$tab_data->{'table_columns'}};
  $table_columns =~ s/\s+//g; #removes all white spaces

 EXIT:{
  my $sql_0 =
         "SELECT table_id FROM ar_dbttables
          WHERE 
              table_name='".%{$tab_data->{'table_name'}}."'  
          AND table_columns='".%{$tab_data->{'table_columns'}}."'
         ";
  my $sql_ref_0 = $apiis->DataBase->sys_sql($sql_0);
  if ( $sql_ref_0->status ) {
     $apiis->errors( $sql_ref_0->errors );
     last EXIT;
  }
  my $ret_0 = $sql_ref_0->handle->rows;

  my $upd_record =
       Apiis::DataBase::Record->new( tablename => 'ar_dbttables', );
  $upd_record->column('table_id')->extdata(%{$tab_data->{'table_id'}});
 
  my @records_to_update = $upd_record->fetch;
  foreach my $thisrecord (@records_to_update) {
    if ($ret_0 == 0) {
      $thisrecord->column('table_name')->extdata(%{$tab_data->{'table_name'}})
        if ( %{$tab_data->{'table_name'}});
      $thisrecord->column('table_columns')->extdata($table_columns)
        if ( %{$tab_data->{'table_columns'}});
    }
    $thisrecord->column('table_desc')->extdata(%{$tab_data->{'table_desc'}})
      if ( %{$tab_data->{'table_desc'}});
    $thisrecord->update();
    $thisrecord->check_status;
    if ( !$thisrecord->status ) {
      $apiis->log( 'debug', "Table/column set changed" );
      $apiis->DataBase->commit;
      $apiis->check_status;
    }
    else {
      $apiis->status(1);
      $errors = " !!! " . @{ $thisrecord->errors }[0]->msg_short . " !!! -";
      $errors .= " " . @{ $thisrecord->errors }[0]->msg_long;
      last EXIT; 
    }
  }
  
  my $sql_1     = "SELECT DISTINCT a.role_id, role_name 
                   FROM ar_roles a 
                   INNER JOIN ar_role_dbtpolicies  USING (role_id)  
                   WHERE dbtpolicy_id IN (
                      SELECT dbtpolicy_id 
                      FROM ar_dbtpolicies 
                      INNER JOIN ar_dbttables USING (table_id)  
                      WHERE table_id=".%{$tab_data->{'table_id'}}."
                   )";
  my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
  if ( $sql_ref_1->status ) {
    $apiis->errors( $sql_ref_1->errors );
    last EXIT;
  }

  my $rows = $sql_ref_1->handle->rows;
  my (@role_names,@roles_to_reload);
  if ($rows) {
    while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
      my %tmp_hash = (
           role_id   => $ret[0],
           role_name => $ret[1],
         );
      push @role_names, $ret[1];
      push @roles_to_reload, \%tmp_hash;
    }
    
    my $ret_roles = 
      ARM::ARMReadDB::get_subroles_for_reload(\@role_names,\@roles_to_reload);
    check_users_table();
    $errors = reloading_role_definitions_for_selected_users(\@$ret_roles);
  }

 }#EXIT
 return $errors;
}
##############################################################################

=head2 delete_table
	
   This subroutine removes single table/columns set and then reloads policies,
   roles and users which are based on it.

=cut

sub delete_table {
  my $table_id = shift;
  my $errors;
  
 EXIT:{
  my $sql_1     = "SELECT table_id 
                     FROM ar_dbtpolicies
                     WHERE table_id = $table_id";
  my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
  if ( $sql_ref_1->status ) {
    $apiis->errors( $sql_ref_1->errors );
    last EXIT;
  }

  my $rows = $sql_ref_1->handle->rows;
  if ($rows) {
    $errors = __("This table/column set is used by $rows policies.
                  You can remove only these sets which 
                  are not used by the policies.
                 ");
  }
  else {
    $sql = "DELETE FROM ar_dbttables 
            WHERE table_id IN ($table_id)";

    my $fetched  = $apiis->DataBase->sys_sql($sql);
    if ($fetched->status) {
      $apiis->errors( $fetched->errors );
      $apiis->status(1);
      last EXIT;
    }
    else {
      $apiis->check_status;
    }
  
  } 

  if ( $apiis->status ) {
    $apiis->log( 'debug', "ERROR -> Table/column set not removed" );
    $apiis->DataBase->sys_dbh->rollback;
  }
  else {
    $apiis->log( 'debug', "OK -> Table/column set removed" );
    $apiis->DataBase->commit;
  }
 }#EXIT

 return $errors;
}
### END TABLE/COLUMN SECTION #################################################

### END DATABASE TASK POLICIES SECTION #######################################

=head2 reloading_role_definitions_for_selected_users
	
   This subroutine is ude by all other subroutines and it reloads 
   the access right of users in case of changign policy or role definition. 

=cut

sub reloading_role_definitions_for_selected_users {
  my $roles_to_reload = shift;
  my $from_interface = 1;
  my @user_logins;
  my $errors;

 EXIT:{
  foreach my $role_def (@$roles_to_reload) {
    my $tmp_name = $role_def->{role_name};
    my $tmp_id   = $role_def->{role_id};
    
    my $sql      = "SELECT user_login,user_marker,user_id FROM ar_users WHERE user_id
                IN ( SELECT user_id FROM ar_user_roles WHERE role_id='$tmp_id')";
    my $sql_ref = $apiis->DataBase->user_sql($sql);
    if ( $sql_ref->status ) {
       $apiis->errors( $sql_ref->errors );
       last EXIT;
    }
    my @users;
    while ( my @ret = $sql_ref->handle->fetchrow_array ) {
         my $mylogin = $ret[0];
         my %tmp_hash = ();
         $tmp_hash{'login'}      = $ret[0];
         $tmp_hash{'marker'}     = $ret[1];
         $tmp_hash{'user_id'}    = $ret[2];
         unless (grep /^$mylogin$/, @user_logins){
           push @users, \%tmp_hash;
           push @user_logins, $mylogin;
         }
    }

    foreach my $user (@users) {
      my $ulogin  = $user->{'login'};
      my $umarker =$user->{'marker'};
      my $uid     =$user->{'user_id'};
      revoke_role_from_user( \@$tmp_name, $ulogin,$from_interface );
      assign_roles( \@$tmp_name, lc $ulogin, $from_interface )
         if ( @$role_name );
      if ($uid ne $apiis->Auth->user_id) {
        #create_st_access_view( $ulogin, $from_interface );
        #create_dbt_access_view( $ulogin, $from_interface );
        table_views( lc $ulogin, $umarker, $from_interface );
        $apiis->log( 'debug',
              "Role '$tmp_name' reloaded for user ->" . $ulogin );
      }
    }
  }

  if ( $apiis->status ) {
    #catching errors from AR and apiis objects
    $apiis->log( 'debug', "ERROR -> Access rights not updated" );
    #setting default error message to notify the user
    $errors='ERROR -> Access rights not updated';
    #catching errors from AR and apiis objects
    for my $err ($apiis->Auth->errors) {
      $errors = " !!! " . $err->msg_short . " !!! -";
      $errors .= " " . $err->msg_long;
      last;
    };
    for my $err ($apiis->errors) {
      $errors = " !!! " . $err->msg_short . " !!! -";
      $errors .= " " . $err->msg_long;
      last;
    };
    $apiis->DataBase->sys_dbh->rollback;
  }
  else {
    $apiis->log( 'debug', "OK -> Access rights updated" );
    $apiis->DataBase->commit;
  }
 }#EXIT
 return $errors;
}
##############################################################################

1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

__END__
