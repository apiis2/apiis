package ARM::ARMReadDB;
##############################################################################
# $Id: ARMReadDB.pm,v 1.3 2019/09/24 13:01:00 ulf Exp $
##############################################################################

=head1 NAME

ARM::ARMReadDB

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

# use Env qw( APIIS_HOME );
#  push @INC, "$APIIS_HOME/lib/Apiis/Auth";
#  require AR_User;
#  require AR_Common;
#  require AR_View;
#  require AR_Component;
##############################################################################

=head2 select_user_or_roles 
	
   This subroutine returns list of users or roles which are defined 
   in the database.  

=cut

sub select_user_or_roles {
    my ( $call, $role_type, $sid ) = @_;
    my @roles;
    my @users;

    EXIT: {
        if ( $call eq 'users' ) {
            my $sql =
                "SELECT user_id, user_login,user_second_name,user_language_id,
                     user_marker,user_first_name,user_email,user_disabled
              FROM ar_users
              INNER JOIN ar_users_data using(user_id) ORDER BY user_login";
            my $sql_ref = $apiis->DataBase->user_sql($sql);
            if ( $sql_ref->status ) {
                $apiis->errors( $sql_ref->errors );
                $apiis->status(1);
                last EXIT;
            }

            while ( my $value = $sql_ref->handle->fetch ) {
                my ( $user_roles, $language );
                my $sql_2 =
                    "select lang from languages WHERE lang_id=@$value[3]";
                my $sql_ref_2 = $apiis->DataBase->user_sql($sql_2);
                if ( $sql_ref_2->status ) {
                    $apiis->errors( $sql_ref_2->errors );
                    $apiis->status(1);
                    last EXIT;
                }
                while ( my $first_value = $sql_ref_2->handle->fetch ) {
                    $language = @$first_value[0];
                }

                my $sql_3 =
                    "select role_id from ar_user_roles WHERE user_id=@$value[0]";
                my $sql_ref_3 = $apiis->DataBase->user_sql($sql_3);
                if ( $sql_ref_3->status ) {
                    $apiis->errors( $sql_ref_3->errors );
                    $apiis->status(1);
                    last EXIT;
                }
                my $style_status = 1;
                while ( my $second_value = $sql_ref_3->handle->fetch ) {
                    my $sql_4 =
                        "SELECT role_name FROM ar_roles WHERE role_id=@$second_value[0]";
                    my $sql_ref_4 = $apiis->DataBase->user_sql($sql_4);
                    while ( my $third_value = $sql_ref_4->handle->fetch ) {
                        if ( $user_roles eq '' ) {
                            $user_roles = join( $user_roles, @$third_value[0] );
                        }
                        else {
                            $user_roles =
                                join( ',  ', $user_roles, @$third_value[0] );
                        }
                    }
                }
                my $style = "fillline";
                my %tmp_hash;
                %tmp_hash = (
                    USER_ID           => @$value[0],
                    LOGIN             => @$value[1],
                    SECONDNAME        => @$value[2],
                    MARKER            => @$value[4],
                    FIRSTNAME         => @$value[5],
                    EMAIL             => @$value[6],
                    LANG              => $language,
                    ROLES             => $user_roles,
                    TR_STYLE          => $style,
                    L_SHOW_USER       => __("Show"),
                    L_SHOW_USER_TITLE =>
                        __("Click to see more information about the user"),
                    L_DELETE_USER       => __("Delete"),
                    L_DELETE_USER_TITLE =>
                        __("Click to remove user from the system"),
                );
                $tmp_hash{'DISABLED'} = __("LOCKED") if ( @$value[7] );
                $tmp_hash{'DISABLED'} = __("UNLOCKED") unless ( @$value[7] );
                push @users, \%tmp_hash;
            }
            return \@users;
        }
        elsif ( $call eq 'roles' ) {
            my $sql =
                "SELECT role_id,role_name,role_subset,role_descr,role_type FROM ar_roles
               where role_type='$role_type' order by role_name";
            my $sql_ref = $apiis->DataBase->user_sql($sql);
            while ( my $value = $sql_ref->handle->fetch ) {
                my $style = "fillline";
                my $role_subset = join( ", ", split( ",", @$value[2] ) );
                my %tmp_hash;
                %tmp_hash = (
                    ROLE_ID           => @$value[0],
                    ROLE_NAME         => @$value[1],
                    ROLE_SUBSET       => $role_subset,
                    ROLE_DESC         => @$value[3],
                    ROLE_TYPE         => @$value[4],
                    TR_STYLE          => $style,
                    L_SHOW_ROLE       => __("Show"),
                    L_SHOW_ROLE_TITLE =>
                        __("Click to see more information about the role"),
                    L_DELETE_ROLE       => __("Delete"),
                    L_DELETE_ROLE_TITLE =>
                        __("Click to role from the system"),
                );
                push @roles, \%tmp_hash;
            }
            return \@roles;
        }
    }    #EXIT
}
######################################################################

=head2 select_user 
	
   This subroutine returns information about single user which is 
   identified by the user_id. 

=cut

sub select_user {
    my ( $user_id, $content_lang ) = @_;
    my %return_hash;
    my ( $i, $ret, @country_loop, @iso_country_loop );

    my @columns = (
        'user_first_name',  'user_second_name',
        'user_institution', 'user_email',
        'user_country',     'user_street',
        'user_town',        'user_zip',
        'user_other_info',  'user_login',
        'user_language_id', 'user_marker',
        'user_disabled'
    );
    my $cols = join( ',', @columns );

    EXIT: {
        my $sql = "SELECT $cols FROM ar_users u 
             INNER JOIN ar_users_data ud USING (user_id) 
             WHERE u.user_id='$user_id'";
        my $sql_ref = $apiis->DataBase->user_sql($sql);
        if ( $sql_ref->status ) {
            $apiis->errors( $sql_ref->errors );
            last EXIT;
        }
        while ( $ret = $sql_ref->handle->fetch ) {
            for ( $i = 0; $i < @columns; $i++ ) {
                $return_hash{ $columns[$i] } = $$ret[$i]
                    if ( defined $$ret[$i] );
            }
        }
        $return_hash{'user_lang_loop'} =
            dd_languages( $return_hash{'user_language_id'} );
        $return_hash{'user_id'} = $user_id;
        my $lang_id = ARM::ARMGeneral::get_language_id($content_lang);

        my $sql_1 =
            "SELECT db_code,long_name FROM codes WHERE class='COUNTRY'
                ORDER BY short_name";
        my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
        if ( $sql_ref_1->status ) {
            $apiis->errors( $sql_ref_1->errors );
            last EXIT;
        }
        while ( my $row = $sql_ref_1->handle->fetch ) {
            my %tmp_hash = ();
            $tmp_hash{'country_id'} = $$row[1];
            $tmp_hash{'name'}       = $$row[1];
            if ( ( $return_hash{'user_country'} eq $$row[1] ) ) {
                $tmp_hash{select} = " selected=\"selected\" ";
            }
            else {
                $tmp_hash{select} = "";
            }
            push @country_loop, \%tmp_hash;
        }

        $return_hash{'user_country_loop'} = \@country_loop;
        $return_hash{'user_marker'} = $apiis->node_name if ($return_hash{'user_marker'} eq '') ;
    }
    return \%return_hash;
}
######################################################################

=head2 get_loops_for_user 
	
   This subroutine returns basic information which are required
   for defining new user. These information are: list of langauges,
   list of countires and default user marker which is taken form
   apiisrc (node_name). 

=cut

sub get_loops_for_user {
    my $content_lang = shift;
    my %return_hash;
    my ( @country_loop, @iso_country_loop );

    EXIT: {
        my $lang_id = ARM::ARMGeneral::get_language_id($content_lang);
        my $sql_1 =
            "SELECT db_code,long_name FROM codes WHERE class='COUNTRY'
                ORDER BY short_name";
        my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
        if ( $sql_ref_1->status ) {
            $apiis->errors( $sql_ref_1->errors );
            last EXIT;
        }
        while ( my $row = $sql_ref_1->handle->fetch ) {
            my %tmp_hash = ();
            $tmp_hash{'country_id'} = $$row[1];
            $tmp_hash{'name'}       = $$row[1];
            if ( ( $return_hash{'user_country'} eq $$row[1] ) ) {
                $tmp_hash{select} = " selected=\"selected\" ";
            }
            else {
                $tmp_hash{select} = "";
            }
            push @country_loop, \%tmp_hash;
        }

        $return_hash{'user_lang_loop'}    = dd_languages();
        $return_hash{'user_country_loop'} = \@country_loop;
        $return_hash{'user_marker'} = $apiis->node_name;

    }
    return \%return_hash;
}
######################################################################

=head2 select_role
	
   This subroutine returns information about single role which is 
   identified by the role_id. As a result you get the basic information 
   about role, list of subroles and the list of policies. 

=cut

sub select_role {
    my $role_id = shift;
    my %return_hash;
    my ( $i, $ret, @subroles_loop, @policies_into_session );

    my @columns = (
        'role_id',   'role_name', 'role_subset', 'role_descr',
        'role_type', 'role_long_name'
    );
    my $cols = join( ',', @columns );

    EXIT: {
        my $sql     = "SELECT  $cols FROM ar_roles WHERE role_id='$role_id'";
        my $sql_ref = $apiis->DataBase->user_sql($sql);
        if ( $sql_ref->status ) {
            $apiis->errors( $sql_ref->errors );
            last EXIT;
        }
        while ( $ret = $sql_ref->handle->fetch ) {
            for ( $i = 0; $i < @columns; $i++ ) {
                $return_hash{ $columns[$i] } = $$ret[$i]
                    if ( defined $$ret[$i] );
            }
        }
        ### role subset loop
        my @subset = split( ',', $return_hash{'role_subset'} );
        my $sql_1 = "SELECT role_name,role_subset,role_descr FROM ar_roles
                WHERE (role_type='"
            . $return_hash{'role_type'}
            . "') and NOT (role_name='"
            . $return_hash{'role_name'} . "')
                ORDER BY role_name";
        my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
        if ( $sql_ref_1->status ) {
            $apiis->errors( $sql_ref_1->errors );
            last EXIT;
        }
        while ( my $row = $sql_ref_1->handle->fetch ) {
            my %tmp_hash_1 = ();
            my $subrole    = $$row[0];
            $tmp_hash_1{'name'} = $$row[0];
            if ( $$row[1] ne '' ) {
                $tmp_hash_1{'subset'} = "subset: " . $$row[1];
            }
            else {
                $tmp_hash_1{'subset'} = "no subset";
            }
            $tmp_hash_1{'descr'} = $$row[2];
            if ( grep( /^$subrole$/, @subset ) ) {
                $tmp_hash_1{select} = " selected=\"selected\" ";
            }
            else {
                $tmp_hash_1{select} = "";
            }
            push @subroles_loop, \%tmp_hash_1;
        }
        $return_hash{'subroles_loop'}    = \@subroles_loop;
        $return_hash{'current_subroles'} = $return_hash{'role_subset'};
        
        #select the policies
        if ($return_hash{'role_type'} eq "ST") {
          my ($policies,$ids) = select_stpolicies($role_id);
          $return_hash{'stpolicies_loop'} = \@$policies;
          @policies_into_session = @$ids;
        }
        elsif ($return_hash{'role_type'} eq "DBT") {
          my ($policies,$ids) = select_dbtpolicies($sid,$script_name,$role_id);
          $return_hash{'dbtpolicies_loop'} = \@$policies;
          @policies_into_session = @$ids;
        }
    }
    return \%return_hash,\@policies_into_session;
}
######################################################################

=head2 select_subroles_for_insert_role 
	
   This subroutine returns list of roles which can be assigned 
   to the new role as a subroles. 

=cut

sub select_subroles_for_insert_role {
   my $role_type = shift ;
   my %return_hash;
   my @subroles_loop;

   my $sql_1 = "SELECT role_name,role_subset,role_descr FROM ar_roles
                WHERE (role_type='". $role_type . "') 
                ORDER BY role_name";
   my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
   if ( $sql_ref_1->status ) {
      $apiis->errors( $sql_ref_1->errors );
      last EXIT;
   }
   while ( my $row = $sql_ref_1->handle->fetch ) {
     my %tmp_hash_1 = ();
     my $subrole    = $$row[0];
     $tmp_hash_1{'name'} = $$row[0];
     if ( $$row[1] ne '' ) {
       $tmp_hash_1{'subset'} = "subset: " . $$row[1];
     }
     else {
       $tmp_hash_1{'subset'} = "no subset";
     }
     $tmp_hash_1{select} = "";
     push @subroles_loop, \%tmp_hash_1;
   }
   $return_hash{'subroles_loop'}    = \@subroles_loop;

 return \%return_hash;
}
######################################################################

=head2 select_user_roles 
	
   This subroutine returns list of user roles. 

=cut

sub select_user_roles {
    my $user_id = shift;
    my %return_hash;
    my ( @role_ids, @stroles_loop, @dbtroles_loop, @current_roles );

    EXIT: {
        my $sql = "SELECT  role_id FROM ar_user_roles WHERE user_id='$user_id'";
        my $sql_ref = $apiis->DataBase->user_sql($sql);
        if ( $sql_ref->status ) {
            $apiis->errors( $sql_ref->errors );
            last EXIT;
        }
        while ( my @ret = $sql_ref->handle->fetchrow_array ) {
            push @role_ids, $ret[0];
        }

        my $sql_1 = "SELECT role_id,role_name,role_descr,role_type 
                FROM ar_roles order by role_name";
        my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
        if ( $sql_ref_1->status ) {
            $apiis->errors( $sql_ref_1->errors );
            last EXIT;
        }
        while ( my $row = $sql_ref_1->handle->fetch ) {
            my %tmp_hash = ();
            my $rid      = $$row[0];
            $tmp_hash{'role_id'}    = $$row[0];
            $tmp_hash{'role_name'}  = $$row[1];
            $tmp_hash{'role_descr'} = $$row[2];
            $tmp_hash{'role_type'}  = $$row[3];

            if ( grep( /^$rid$/, @role_ids ) ) {
                $tmp_hash{'select'} = " selected=\"selected\" ";
                push @current_roles, $$row[1];
            }
            else {
                $tmp_hash{'select'} = "";
            }
            if ( $$row[3] eq "DBT" ) {
                push @dbtroles_loop, \%tmp_hash;
            }
            elsif ( $$row[3] eq "ST" ) {
                push @stroles_loop, \%tmp_hash;
            }
        }
        $return_hash{'stroles_loop'}  = \@stroles_loop;
        $return_hash{'dbtroles_loop'} = \@dbtroles_loop;
        $return_hash{'current_roles'} = join( ",", @current_roles );
    }
    return \%return_hash;
}
######################################################################

=head2 get_subroles_for_reload 
	
   This subroutine returns additional list of roles which have to be 
   reloaded. The role definitions are reloaded in case of changing 
   their information. When the definitions is changed then this subroutine
   checks if this role name appears on the list of subroles of other 
   role. If the changed role exists on the list of subroles then this 
   other role is also put on reload list.

=cut

sub get_subroles_for_reload {
  my ($role_name,$roles_to_reload) = @_;

EXIT:{
  my $sql_1     = "SELECT role_id,role_name,role_subset FROM ar_roles";
  my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
  if ( $sql_ref_1->status ) {
    $apiis->errors( $sql_ref_1->errors );
    last EXIT;
  }

  while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
    my $rname = $ret[1];
    my @rsub = split( ',', $ret[2] );
    foreach $role (@$role_name) {
      
      if ( (grep( /^$role$/, @rsub)) and !(grep(/^$rname$/,@$role_name)) ) {
        my %tmp_hash = (
             role_id   => $ret[0],
             role_name => $ret[1],
           );
        push @$roles_to_reload, \%tmp_hash;
      }
    }
  }
 }#EXIT
 return \@$roles_to_reload;
}
######################################################################

######################################################################

=head2 select_stpolicies
	
   This subroutine returns list of system task policies and is 
   called by the subroutine "select_role". 

=cut


sub select_stpolicies {
   my $role_id = shift;
   my @policies;
   my @st_policies;

 EXIT:{
   if (defined $role_id) {
     my $sql_1 =
         "SELECT stpolicy_id FROM ar_role_stpolicies where role_id='$role_id'";
     my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
     if ( $sql_ref_1->status ) {
       $apiis->errors( $sql_ref_1->errors );
       last EXIT;
     }
     my $rows = $sql_ref_1->handle->rows;
     while ( my $value = $sql_ref_1->handle->fetch ) {
        push @st_policies, $$value[0];
     }
   }
   
   my $sql_2 =
       "SELECT stpolicy_id,stpolicy_name,stpolicy_type,stpolicy_desc 
         FROM ar_stpolicies 
         ORDER BY stpolicy_type,stpolicy_name";
   my $sql_ref_2 = $apiis->DataBase->user_sql($sql_2);
   if ( $sql_ref_2->status ) {
     $apiis->errors( $sql_ref_2->errors );
     last EXIT;
   }

   while ( my $row = $sql_ref_2->handle->fetch ) {
     my %tmp_hash_1 = ();
     $tmp_hash_1{'id'}      = $$row[0];
     $tmp_hash_1{'name'}    = $$row[1];
     if (defined $role_id) {
       $tmp_hash_1{'type'} = $$row[2];;
     }
     else {
       $tmp_hash_1{'type_loop'} = st_policy_types($$row[2]);
     }
     $tmp_hash_1{'descr'}   = $$row[3];
     $tmp_hash_1{'l_show_policy_title'}   = __("Show information about this policy");
     $tmp_hash_1{'l_delete_policy_title'}   = __("Remove this policy from the database");
     $tmp_hash_1{'l_show_policy'}   = __("Apply");
     $tmp_hash_1{'l_delete_policy'}   = __("Delete");
     my $id = $$row[0];
     if (grep (/^$id$/,@st_policies)){
      $tmp_hash_1{'checked'} = " checked";
     }
     else{
      $tmp_hash_1{'checked'} = " ";
     }
     push @policies, \%tmp_hash_1;
   }
 }#EXIT
 return \@policies,\@st_policies;;
}


######################################################################

=head2 st_policy_types 
	
   This subroutine returns types for system task policies. 

=cut


sub st_policy_types {
  my $database_action = shift;
  my @policy_action = qw /action form www program report/;
  my @type_loop;

  foreach (@policy_action) {
    my $selected;
    $selected = " selected" if ( $database_action eq $_);
    my %tmp_hash_0 = ( type => $_, select => $selected, );
    push @type_loop, \%tmp_hash_0;
  }
  return \@type_loop;
}
######################################################################

=head2 select_dbtpolicies
	
   This subroutine returns list of database policies and it is called 
   by the subroutine "select_role".

=cut

sub select_dbtpolicies {
   my ($sid,$script_name,$role_id) = @_;
   my @policies;
   my @dbt_policies;

 EXIT:{
   if (defined $role_id) {
     my $sql_1 =
         "SELECT dbtpolicy_id FROM ar_role_dbtpolicies where role_id='$role_id'";
     my $sql_ref_1 = $apiis->DataBase->user_sql($sql_1);
     if ( $sql_ref_1->status ) {
       $apiis->errors( $sql_ref_1->errors );
       last EXIT;
     }
     my $rows = $sql_ref_1->handle->rows;
     while ( my $value = $sql_ref_1->handle->fetch ) {
        push @dbt_policies, $$value[0];
     }
   }

   my $sql_2 =
       "SELECT dbtpolicy_id,table_name,table_columns,descriptor_name,descriptor_value,
         (SELECT short_name 
          FROM codes 
          WHERE class='SQLACTION' and db_code=action_id
         ) as action,
         a.table_id,a.descriptor_id
        FROM ar_dbtpolicies a,ar_dbttables b, ar_dbtdescriptors c 
        WHERE a.table_id=b.table_id and a.descriptor_id=c.descriptor_id 
        ORDER BY action,table_name";
   my $sql_ref_2 = $apiis->DataBase->user_sql($sql_2);
   if ( $sql_ref_2->status ) {
     $apiis->errors( $sql_ref_2->errors );
     last EXIT;
   }

   ### get sql actions
   my $sqlactions = select_sqlactions();

   while ( my $row = $sql_ref_2->handle->fetch ) {
     my %tmp_hash_1 = ();
     $tmp_hash_1{'id'}                 = $$row[0];
     $tmp_hash_1{'table_name'}         = $$row[1];
     $tmp_hash_1{'table_columns'}      = $$row[2];
     $tmp_hash_1{'descriptor_name'}    = $$row[3];
     $tmp_hash_1{'descriptor_value'}   = $$row[4];
     $tmp_hash_1{'table_id'}   = $$row[6];
     $tmp_hash_1{'descriptor_id'}   = $$row[7];
     
    if (defined $role_id) {
       $tmp_hash_1{'action'} = $$row[5];
     }
     else {
       $tmp_hash_1{'action'} = 
          select_sqlactions(\@$sqlactions,$$row[5]);
     }
 
     $tmp_hash_1{'l_show_policy_title'}   = __("Show information about this policy");
     $tmp_hash_1{'l_delete_policy_title'}   = __("Remove this policy from the database");
     $tmp_hash_1{'l_show_policy'}   = __("Apply");
     $tmp_hash_1{'l_delete_policy'}   = __("Delete");
     $tmp_hash_1{'l_change_table'}   = __("Table");
     $tmp_hash_1{'l_change_descriptor'}   = __("Descriptor");
     $tmp_hash_1{'l_change_table_title'}   = __("Change table definition for this policy");
     $tmp_hash_1{'l_change_descriptor_title'}   = __("Change descriptor definition for this policy");
     $tmp_hash_1{'session_id'} = $sid;
     $tmp_hash_1{'form_action'} = $script_name;
     
     my $id = $$row[0];
     if (grep (/^$id$/,@dbt_policies)){
      $tmp_hash_1{'checked'} = " checked";
     }
     else{
      $tmp_hash_1{'checked'} = " ";
     }
     push @policies, \%tmp_hash_1;
   }
 }#EXIT
 return \@policies, \@dbt_policies;
}
######################################################################

=head2 select_sqlactions
	
   This subroutine returns list of basic sql actions which are used 
   by the database task policies.

=cut

sub select_sqlactions {
  my ($sqlactions,$selected) = @_;
  my @actions;

 EXIT:{
  if ($sqlactions) {
    foreach (@$sqlactions) {
         my %tmp_hash =();
         $tmp_hash{'value'} = %{$_->{'value'}};
         $tmp_hash{'name'} = %{$_->{'name'}};
         if ($selected eq %{$_->{'name'}}) {
           $tmp_hash{'select'}  = " selected";
         }
         else {
           $tmp_hash{'select'}  = "";
         }
         push @actions, \%tmp_hash;
       }
  }
  else {
    my $sql_1 = "SELECT ext_code,short_name 
                 FROM codes
                 WHERE class='SQLACTION'";
    my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
    if ( $sql_ref_1->status ) {
      $apiis->errors( $sql_ref_1->errors );
      last EXIT;
    }

    while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
      my %tmp_hash =();
      $tmp_hash{'value'} = $ret[0];
      $tmp_hash{'name'}  = $ret[1];
      push @actions, \%tmp_hash;
    }
  }
 }#EXIT
 return \@actions;
}
######################################################################

=head2 select_table_names
	
   This subroutine returns list of tables. It takes table name
   as an input parameter and then this table is marked on the
   drop-down list.

=cut

sub select_table_names {
  my $selected = shift;
  my @tables = $apiis->Model->tables;
  my @ret_list_tables;

  foreach (@tables){
    my %tmp_hash =();
    $tmp_hash{'value'} = $_;
    $tmp_hash{'name'} = $_;
    if ($selected eq $_) {
      $tmp_hash{'select'}  = " selected";
    }
    else {
      $tmp_hash{'select'}  = "";
    }
    push @ret_list_tables, \%tmp_hash;
  }
  return \@ret_list_tables;
}

######################################################################

=head2 select_descriptor_names
	
   This subroutine returns unique list of all column names.It takes 
   table name as an input parameter and then this table is marked 
   on the drop-down list.

=cut

sub select_descriptor_names {
  my ( $selected, $table_name ) = @_;
  my @ret_list_columns;
  my @all_columns;
  my @tables = $apiis->Model->tables;

  foreach my $table (@tables) {
    my $tab_ref = $apiis->Model->table($table);
    my @columns = $tab_ref->cols; 

    foreach my $mycolumn (@columns){
      my %tmp_hash =();
      $tmp_hash{'value'} = $mycolumn;
      $tmp_hash{'name'} = $mycolumn;
      if ($selected eq $mycolumn) {
        $tmp_hash{'select'}  = " selected";
      }
      else {
        $tmp_hash{'select'}  = "";
      }
      if (!(grep (/^$mycolumn$/, @all_columns))) {
        push @ret_list_columns, \%tmp_hash;
        push @all_columns, $mycolumn;
      }
    }
  }
  return \@ret_list_columns;

}
######################################################################

=head2 select_column_names
	
   This subroutine returns columns for defined table.

=cut

sub select_column_names {
  my $table_name  = shift;

  my $tab_ref = $apiis->Model->table($table_name);
  my $columns = join (',',@{$tab_ref->cols});

  return $columns;
}
######################################################################

=head2 choose_tables
	
   This subroutine returns list of table/columns sets which are 
   currently defined in the database. They are used for defining 
   database task policies.

=cut

sub choose_tables {
  my ($table_id,$policy_id) = @_;
  my @tables;

 EXIT:{
   my $sql_1 = "SELECT table_id, table_name, table_columns, table_desc
                 FROM ar_dbttables
                 ORDER BY table_name,table_columns";
   my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
   if ( $sql_ref_1->status ) {
     $apiis->errors( $sql_ref_1->errors );
     last EXIT;
   }

   while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
     my @change_format = split (',',$ret[2]);
     my $formated_columns = join (', ', @change_format);

     my %tmp_hash =();
     $tmp_hash{'table_id'} = $ret[0];
     $tmp_hash{'all_table_columns'}  = select_column_names($ret[1]);
     $tmp_hash{'table_columns'}  = $formated_columns;
     if (defined $policy_id) {
       $tmp_hash{'policy_id'} = $policy_id;
       $tmp_hash{'table_name'}  = $ret[1];
     }
     else {
       $tmp_hash{'table_name'}  = select_table_names($ret[1]);
       $tmp_hash{'img_table_name'}  = $ret[1];
       $tmp_hash{'table_desc'}  = $ret[3];
       $tmp_hash{'l_apply'} = __("Apply");
       $tmp_hash{'l_delete'} = __("Delete");
       $tmp_hash{'l_apply_title'} = __("Apply changes");
       $tmp_hash{'l_delete_title'} = __("Delete table definition from the database");
       $tmp_hash{'l_img_title'} = __("Click to print all columns for selected table");
     }

     if ($ret[0] eq $table_id) {
       $tmp_hash{'selected'} = " checked";
     }
     else{
       $tmp_hash{'selected'} = "";
     }
     push @tables, \%tmp_hash;
   }
 }
 return \@tables;
}
######################################################################

=head2 choose_descriptors
	
   This subroutine returns list of descriptors (name and value) 
   which are currently defined in the database. They are used for 
   defining database task policies. 

=cut

sub choose_descriptors {
  my ($sid,$script_name,$descriptor_id,$policy_id,$table_name) = @_;
  my @descriptors;
  my @columns_from_table;

  if (defined $table_name){
     my $tab_ref = $apiis->Model->table($table_name);
     @columns_from_table = $tab_ref->cols;
  }

 EXIT:{
   my $sql_1 = "SELECT descriptor_id, descriptor_name, descriptor_value,
                       descriptor_desc 
                 FROM ar_dbtdescriptors
                 ORDER BY descriptor_name,descriptor_value";
   my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
   if ( $sql_ref_1->status ) {
     $apiis->errors( $sql_ref_1->errors );
     last EXIT;
   }

   while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
     my @change_format = split (',',$ret[2]);
     my $formated_columns = join (', ', @change_format);

     my %tmp_hash =();
     $tmp_hash{'descriptor_id'} = $ret[0];
     $tmp_hash{'descriptor_value'}  = $formated_columns;
     if (defined $policy_id) {
       $tmp_hash{'policy_id'} = $policy_id;
       $tmp_hash{'descriptor_name'}  = $ret[1];
     }
     else {
       $tmp_hash{'descriptor_name'}  = select_descriptor_names($ret[1]);
       $tmp_hash{'descriptor_desc'}  = $ret[3];
       $tmp_hash{'l_apply'} = __("Apply");
       $tmp_hash{'l_delete'} = __("Delete");
       $tmp_hash{'l_sql'} = __("SQL");
       $tmp_hash{'l_sql_title'} = __("Define your own SQL which return you the values for descriptor");
       $tmp_hash{'l_apply_title'} = __("Apply changes");
       $tmp_hash{'l_delete_title'} = __("Delete table definition from the database");
       $tmp_hash{'session_id'}  = $sid;
       $tmp_hash{'form_action'}  = $script_name;
     }
     if ($ret[0] eq $selected) {
       $tmp_hash{'selected'} = " checked";
     }
     else{
       $tmp_hash{'selected'} = "";
     }
     
     if (defined $policy_id) {
       my $col = $ret[1];
       push @descriptors, \%tmp_hash if (grep(/^$col$/, @columns_from_table));
     }
     else {
       push @descriptors, \%tmp_hash;
     }  
   }
 }

 return \@descriptors;
}
######################################################################

=head2 select_tables_which_have_this_column
	
   This subroutine returns table names which have defined colum name.
   The column name is supplied as an input parameter.

=cut

sub select_tables_which_have_this_column {
  my $selected = shift;
  my @ret_tables;
  my @tables = $apiis->Model->tables;

  foreach my $table (@tables) {
    my $tab_ref = $apiis->Model->table($table);
    my @columns = $tab_ref->cols; 

    if (grep (/^$selected$/, @columns)) {
        if (!(grep (/^$table$/, @ret_tables))) {
          push @ret_tables, $table;
        }
    }
  }
  my $ret_tables_string = join (', ',@ret_tables);
  return $ret_tables_string;
}
######################################################################

=head2 merging_hashes
	
   This subroutine merges two hashes

=cut

sub merging_hashes {
    my ( $A, $B ) = @_;

    my %merged = ();
    while ( my ( $k, $v ) = each( %{$A} ) ) {
        $merged{$k} = $v;
    }
    while ( my ( $k, $v ) = each( %{$B} ) ) {
        $merged{$k} = $v;
    }
    return \%merged;
}
######################################################################

=head2 get_language
	
   This subroutine returns language name for given lang_id.

=cut

sub get_language {
    my $lang_id = shift;
    my $language;
    my $sql     = "select lang from languages WHERE lang_id=$lang_id";
    my $sql_ref = $apiis->DataBase->user_sql($sql);
    while ( my $value = $sql_ref->handle->fetch ) {
        $language = @$value[0];
    }

    return $language;
}
######################################################################

sub execute_user_sql {
    my $sql       = shift;
    my $error     = 0;
    my $sql_ref   = $apiis->DataBase->user_sql($sql);
    my $data_rows = $sql_ref->handle->rows;

    return $sql_ref, $data_rows;

}

#######################################################################

=head2 dd_languages

   This subroutine returns list of languages. The lang_id is supplied
   as an input parameter. 

=cut

sub dd_languages {
    my $select       = shift;
    #my $gui_langs = $apiis->gui_lang;

    my $sql_statement =
        sprintf(
        "select distinct lang_id,lang,iso_lang from languages order by lang");
    my $sql_ref = $Apiis::Model::apiis->DataBase->user_sql($sql_statement);
    $Apiis::Model::apiis->check_status;
    my @loop_array = ();
    while ( my @data_array = $sql_ref->handle->fetchrow_array ) {
     #   next unless ( $contentlangs =~ /$data_array[2]/ );
        my %tmp_hash = ();
        $tmp_hash{'lang_id'}  = $data_array[0];
        $tmp_hash{'lang'}     = $data_array[1];
        $tmp_hash{'iso_lang'} = $data_array[2];
        if ( ( $select eq $data_array[0] ) || ( $select eq $data_array[1] ) ) {
            $tmp_hash{select} = "selected";
        }
        else { $tmp_hash{select} = ""; }
        push @loop_array, \%tmp_hash;
    }
    return \@loop_array;
}

#######################################################################

1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

__END__
