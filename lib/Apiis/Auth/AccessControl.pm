##############################################################################
# $Id: AccessControl.pm,v 1.35 2021/05/27 19:51:10 ulf Exp $
##############################################################################.

=head1 NAME

Apiis::Auth::AccessControl -- used by the runall.pl and access_control.pl scripts to define user access rights

=head1 SYNOPSIS

Adding, deleting roles and users in the Apiis system.

=head1 DESCRIPTION

These subroutines are used to define access rights in the system. New roles and users are created on the basis of information
which are defined in the $APIIS_LOCAL/etc/Roles.conf. Roles and users name are set as a parameters.

=head1 SUBROUTINES

=cut

use strict;
use warnings;

use Apiis::Init;
use Apiis::DataBase::Record;
use Apiis::Auth::Role;
use Digest::MD5 qw(md5_base64);
use Term::ReadKey;
use Apiis::DataBase::SQL::MakeSQL;
#use Apiis::Misc qw(mychomp);


#global variables moved here Jivko 30-04-2008
our ($tab,$user_id,$rid,$role_id,$guid,$act,$revoke_action,$revoke_table);


=head2 access_rights

 this subroutine can be used to define access rights directly in the code without access_control.pl script

=cut

sub access_rights{
 my ($def_user,$def_roles,$user_creator,$set_second_name,$set_language,$set_password,$set_user_node,$set_user_cagegory)=@_;

 creates_user($def_user,$user_creator,$set_second_name,$set_language,$set_password,$set_user_node,$set_user_cagegory); 
 creates_schema($def_user);
 foreach my $role_name (@{$def_roles}){
    my ($thisrole,$create_role_status) = creates_role($role_name,$user_creator);
    if($create_role_status){
      my $roletype =  $thisrole->role_type;
      if ($roletype eq 'DB'){
         my @ret_db_policies = creates_db_policies($thisrole,$user_creator);
         asigns_db_policies($thisrole,\@ret_db_policies,$user_creator);
      }
      elsif ($roletype eq 'OS'){
         my @ret_os_policies = creates_os_policies($thisrole,$user_creator);
         asigns_os_policies($thisrole,\@ret_os_policies,$user_creator);          
      }
      else{
         my $msg = __("Not corect role type ([_1]) for role '[_2]'. Use 'OS' or 'DB' as a role type in Roles.conf file",$roletype,$role_name);
         $apiis->status(1);
	 $apiis->errors(
		       Apiis::Errors->new(
				      type      => 'AUTH',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::AccessControl::access_rights',
				      msg_short => $msg,
				     )
		      );
	 print "\n";
	 die "\n!!! $msg !!!\n";
      }
    }
   assigns_role($def_user,$role_name,$user_creator);
 }  
 creates_access_view($def_user);
 public_views($def_user);
 creates_views_v_($def_user);
}


#### create schema ####################################################

=head2 creates_schema 

  this subroutine creates individual user schema

=cut

sub creates_schema{
  my $user = shift;  
  
  my $sql = "CREATE SCHEMA $user";
  my $sql_ref = query_db($sql);
  $sql = "GRANT USAGE ON SCHEMA $user to $user";
  $sql_ref  = query_db($sql);
  $sql = "REVOKE create ON SCHEMA $user FROM $user";
  $sql_ref = query_db($sql);
}
#### create schema (end) ###############################################

#### create user #############################################################

=head2 creates_user

  this subroutine adds new user.

=cut

sub  creates_user{
   my ($user,$user_creator,$set_second_name,$set_language,$set_password,$set_user_node,$set_user_category) = @_; 
   my ($lang_id); #added by Jivko 30-04-2008
   my @err_array;
   my $efabisuser_status=1;
   my $pguser_status=1;
   my $system_user = $apiis->Model->db_user;
   my $last_change_user;
   
   if ($user_creator){
     $last_change_user=$user_creator;
   }else{
      $last_change_user=$apiis->User->id ;
    }
   ### check that user existing in the database ############################
   my $queriedtable = 'users';
   my $sql = "SELECT user_id FROM $system_user.$queriedtable WHERE login='$user'";
   my $sql_ref  = query_db($sql);
   while(my $value = $sql_ref->handle->fetch){
     $efabisuser_status=0;
     $user_id =${$value}[0];
     @err_array= ${$value}[0];
   }
   warn "More then one user with login $user!\n" if(@err_array>1);
   ################################################################
   if ($efabisuser_status){
     ### creates user in  database  ##############################
     $user_id =$apiis->DataBase->seq_next_val('seq_users__user_id');
     my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
     my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
     my $owner=$apiis->node_name;
     my $version=1;
     my ($passwd,$name,$language,$user_node,$user_category);
     my $langstatus=1;
     print "\n";
     print __("REGISTERING NEW USER IN THE SYSTEM WITH LOGIN: >> [_1] <<",$user);
     if($set_second_name){
       $name=$set_second_name;
     }else{  
       print "\n";
       print __("Please enter user first name and name: ");
       chomp( $name = <> );
     }

     #-- mue admin|coord|user|anon 
     if($set_user_category){
       $user_category=$set_user_category;
     }

     if($set_user_node){
       $user_node=$set_user_node;
     }else{
       print "\n";  
       print __("Please enter a node name: ");
       chomp( $user_node = <> );
     }
     while ($langstatus){
       if($set_language){
         $language=$set_language;
       }else{  
         print __("Please enter user language (en,pl,de, ...): ");
         chomp( $language = <> );
       }
       my $sql_lang = "SELECT lang_id FROM languages WHERE iso_lang = '$language'";
       my $fetched=$apiis->DataBase->sys_sql($sql_lang); #query_db($sql_lang);
       my $fetch_stat = $fetched->status;
       while ( my $ret = $fetched->handle->fetch ) {
        $lang_id = @{$ret}[0];
        $langstatus = 0;
       }
       if ($langstatus){
         my $msg1=__("No such language definition in the database"); 
         print "!!! $msg1 !!! \n"; 
	 my $sql_lang = "SELECT lang_id FROM languages WHERE iso_lang = 'en'";
         my $fetched=$apiis->DataBase->sys_sql($sql_lang); #query_db($sql_lang);
         $fetched->check_status;
         while ( my $ret = $fetched->handle->fetch ) {
           $lang_id = @{$ret}[0];
           $langstatus = 0;
         } 
	 if ($langstatus){
	   my $msg1=__("No such language definition in the database"); 
	   my $msg2=__("You have to add some language to the database"); 
           print "\n!!! $msg1 !!!\n";
	   die "!!! $msg2\n";  
	 }else{
	    my $msg1=__("Englisch set as default"); 
	    print "!!! $msg1 !!!\n";
	 }   
       }	
     }
     
     if($set_password){
       $passwd=$set_password;
     }else{      
       print __("Please enter the password for the new user: ");
       ReadMode 2;
       chomp( $passwd = <> );
       ReadMode 0;
     }  
     my $password = md5_base64($passwd);
     my $values ="$user_id,'$user','$password','$name',$lang_id,'$user_node','$user_category','$last_change_dt','$last_change_user',$guid,'$owner',$version";
     my $columns ='user_id,login,password,name,lang_id,user_node,user_category, last_change_dt,last_change_user,guid,owner,version';
     my $queriedtable = 'users';
     my $sql = "INSERT INTO $system_user.$queriedtable ($columns) VALUES ($values)";
     my $sql_rer  = query_db($sql);
     my $msg3=__("User [_1] (login: [_2]) added to the system\n",$name,$user); 
     print "\nOK: $msg3\n";

     ### creates user in postgresql  ###############
     my $msg4 = __("Registering new user in PostgreSQL");
     print "\n>>> $msg4";
     my $sql1 = "select usename from pg_catalog.pg_user where usename='$user'";
     my $sql_ref = query_db($sql1);
     while(my $value = $sql_ref->handle->fetch){
       $pguser_status=0
     }
     if($pguser_status){
       print "\n";
       #system("createuser -W $user"); #parametr -W Pg password
       my $msg1 = __("User [_1] (login: [_2]) added to PostgresSQL",$name,$user);
       print "OK: $msg1";
#       my $sql = "create user $user password '$passwd' nocreatedb nocreateuser";
       #-- without nocreateuser 
       my $sql = "create user $user password '$passwd' nocreatedb ";
       my $sql_ref = query_db($sql);
     }
     else{ #else for efabisuser_status
       my $msg1 = __("User [_1] is existing in PostgreSQL",$user);
       print "\n!!! $msg1 !!!";
     }
     ### creates user in postgresql (end) ###########

     }else{ #else for efabisuser_status
       my $msg1 = __("User [_1] is existing in the system",$user);
       print "\n!!! $msg1 !!!";
     }
   
   return $user_id;
 }
#### create user (end) #######################################################

#### create role ############################################################

=head2 creates_role 

  this subroutine adds new role. 

=cut

sub creates_role{
  my ($role_shortcut,$user_creator)=@_;
  my @err_array;
  my $rstatus=1;
  my $system_user = $apiis->Model->db_user;
  my $last_change_user;
  
  if ($user_creator){
     $last_change_user=$user_creator;
   }else{
      $last_change_user=$apiis->User->id ;
    }
  my $msg1 = __("Creating role and policies");
  print "\n\n>>> $msg1";
  ### check that role existing in the database ############################
  my $queriedtable = 'roles';
  my $sql = "SELECT role_id FROM $system_user.$queriedtable WHERE role='$role_shortcut'";
  my $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetch){
    $rstatus=0;
    $rid =${$value}[0];
    @err_array= ${$value}[0];
  }
  warn __("More then one role [_1]!\n",$role_shortcut) if(@err_array>1);
  ### create role object #############
  my $thisrole = Apiis::Auth::Role->new(
     role_shortcut => $role_shortcut,
   );
  ###############################

  ################################################################
   if ($rstatus){
     ### set values #########################
     my $short_name = $thisrole->short_name;
     my $long_name = $thisrole->long_name;
     my $description = $thisrole->description;
     my $role_id = $thisrole->role_id();
     my $role_type=$thisrole->role_type;
     my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
     my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
     my $owner=$apiis->node_name;
     my $version=1;
     ### create sql ###################################
     my $values ="$role_id,'$role_shortcut','$role_type','$short_name','$long_name','$description','$last_change_dt','$last_change_user',$guid,'$owner',$version";
     my $columns ='role_id,role,role_type,role_name_sh,role_name_lng,description,last_change_dt,last_change_user,guid,owner,version';
     my $queriedtable = 'roles';
     my $sql = "INSERT INTO $system_user.$queriedtable ($columns) VALUES ($values)";
     ### insert role ###################################
     my $sql_ref  = query_db($sql);
     my $msg2 = __("Role '[_1]' ([_2]) added to the system",$short_name,$long_name);
     print "\nOK: $msg2";
     print "\n    \"With this role $description\"";
     }else{
       $thisrole->role_id($rid);
       my $msg3 = __("Role '[_1]' is existing in the database",$role_shortcut);
       print "\n!!! $msg3 !!!";
   }
return $thisrole,$rstatus;
}
#### create role (end) #######################################################

##### assign role to the user ##############################################

=head2 assigns_role

  this subroutine assigns role to the user.

=cut

sub assigns_role{
  my ($as_user,$as_role,$user_creator)= @_;
  my @err_array;
  my @policy_to_grant;
  my $arstatus=1;
  my $system_user = $apiis->Model->db_user; 
#  my $db_role = $thisrole->role_id();
  my $last_change_user;
  
  if ($user_creator){
     $last_change_user=$user_creator;
   }else{
      $last_change_user=$apiis->User->id ;
    } 
  ### query db about user_id ####
  my $sql = "SELECT user_id FROM $system_user.users WHERE login='$as_user'";
  my $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetch){
    $user_id =@{$value}[0];
  }
  ### query db about role_id ####
  $sql = "SELECT role_id FROM $system_user.roles WHERE role='$as_role'";
  $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetch){
    $role_id =@{$value}[0];
  }
  
  ### check that record existing in the database ############################
  my $queriedtable = 'user_roles';
  $sql = "SELECT guid FROM $system_user.$queriedtable WHERE role_id=$role_id and user_id=$user_id";
  $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetch){
    $arstatus=0;
    $guid =@{$value}[0]; #was "our $guid" jivko 30-04-2008
    @err_array= @{$value}[0];
  }
  warn "More then one ascription the same role to the user in user_roles table !\n" if(@err_array>1);
  if ($arstatus){
    ### create sql ###################################
    my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
    my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
    my $owner=$apiis->node_name;
    my $version=1;
    my $values ="$user_id,$role_id,'$last_change_dt','$last_change_user',$guid,'$owner',$version";
    my $columns ='user_id,role_id,last_change_dt,last_change_user,guid,owner,version';
    my $queriedtable = 'user_roles';
    ### insert ######## ##############################
    $sql = "INSERT INTO $system_user.$queriedtable ($columns) VALUES ($values)";
    my $sql_ref  = query_db($sql);
    my $msg4 = __("Role '[_1]' assigned to the user '[_2]'",$as_role,$as_user);
    print "\nOK: $msg4";
  }
  else{
    my $msg5 = __("Role '[_1]' was already assigned to the user [_2]'",$as_role,$as_user);
    print "\n!!! $msg5 !!!";  
    }
 
}
#########################################################################

=head2 creates_db_policies 
 
 This subroutine reads database policies from the Roles.conf file and adds it to the database.
 Only these policies are added which are defined for the current role.

=cut

sub creates_db_policies{
     my ($thisrole,$user_creator)= @_;
     my $last_change_user;
     
     my $rtype=$thisrole->role_type;
     my $numbers = $thisrole->policies;
     my  @policies_from_file= split /,/, $numbers;
     my @policies= check_policies($rtype,\@policies_from_file);
     my $system_user = $apiis->Model->db_user;   
     
  
     if ($user_creator){
       $last_change_user=$user_creator;
     }else{
       $last_change_user=$apiis->User->id ;
     }     
     
     foreach my $policy (@policies){
       my $policy_id = $policy; #get_next_val('seq_policies__policy_id');
       my $policy_value= $thisrole->db_policy($policy);
       my @values= split /\|/, $policy_value;

       ### check action #######
       if (($values[0] eq 'insert') or ($values[0] eq 'update') or ($values[0] eq 'delete') or ($values[0] eq 'select')){
	 $act = $values[0];
       }else{
         my $msg5 = __("DB policy [_1] is wrong definited in the Roles.conf file. Action name '[_2]' is not allowed",$policy,$values[0]);
       	 $apiis->status(1);
	 $apiis->errors(
		       Apiis::Errors->new(
				      type      => 'AUTH',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::AccessControl::creates_db_policies',
				      msg_short => $msg5,
				     )
		      );
	 print "\n"; 	
	 die "\n!!! $msg5 !!!";
       }

       ### check table name ###
       my $tabstatus=1;
       my @tables;
       foreach my $table (@{ $apiis->Model->tables} ){
	 push @tables, $table;
       }
     EXIT1:
       foreach my $tablename(@tables){
	 if($values[1] eq $tablename or $values[1]=~ /entry_/){
	   $tabstatus=0;
	   last EXIT1;
	 }
       }
       if($tabstatus){
	 die __(" Policy number [_1]: wrong definition in the Roles.conf file. There is no table '[_2]' in the model file or not corect order",$policy,$values[1]);
       }else{
	$tab = $values[1];
       }

       ### check columns ######
       my @columns = split /,/, $values[2];
       my $colstatus;
       my $modtable;
       my @modtablecols;
       
       if ($values[1]=~ /entry_/){
         my $entrytab = $values[1];
         $entrytab =~ s/(.*entry_)(.*)$/$2/;
         $modtable = $apiis->Model->table($entrytab);  
         @modtablecols = @{$modtable->cols};
       }else{  
	 $modtable = $apiis->Model->table($values[1]);
	 @modtablecols = @{$modtable->cols};
       }
	 
       foreach my $mycolumn (@columns){
	 $colstatus=1;
       EXIT2:
	 foreach my $modcolumn (@modtablecols){
	   if(($mycolumn eq $modcolumn) or ($mycolumn eq $apiis->DataBase->rowid)){
	     $colstatus=0;
	     last EXIT2;
	   }
	 }
	 if($colstatus){
	 
	   die __("Policy number [_1]: wrong policy definition in the Roles.conf file. Thers is no column '[_2]'  in the table '[_3]'  or not corect order",$policy,$mycolumn,$values[1]); 
	 }
       }
       my $join = join('|',@columns);
       my $col;
       $col= join('|', $col,$join);
       $col = join('|',$col,'');
       

       my $cla = $values[3];
       ### create sql ###################
       my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
       my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
       my $owner=$apiis->node_name;
       my $version=1;
       my $values ="$policy_id,'$tab','$col','$cla','$act','$last_change_dt','$last_change_user',$guid,'$owner',$version";
       my $columns ='policy_id,tablename,columns,class,action,last_change_dt,last_change_user,guid,owner,version';
       my $queriedtable = 'policies';
       my $sql = "INSERT INTO $system_user.$queriedtable ($columns) VALUES ($values)";
       my $sql_ref  = query_db($sql);
     }
     return @policies_from_file;
}
#############################################################################

=head2 asigns_db_policies

  this subroutine asigns databse policies to the current role.

=cut

sub asigns_db_policies{
   my ($thisrole,$ret_policies,$user_creator) = @_;
   my $system_user = $apiis->Model->db_user; 
   my $db_role =$thisrole->role_id();
   my $i=0;
   my $last_change_user;
  
   if ($user_creator){
     $last_change_user=$user_creator;
   }else{
     $last_change_user=$apiis->User->id ;
   }     
    
   foreach my $policyid  (@{$ret_policies}){
     ### create sql ###################################
     my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
     my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
     my $owner=$apiis->node_name;
     my $version=1;
     my $values ="$policyid,$db_role,'$last_change_dt','$last_change_user',$guid,'$owner',$version";
     my $columns ='policy_id,role_id,last_change_dt,last_change_user,guid,owner,version';
     my $queriedtable = 'role_policies';
     my $sql = "INSERT INTO $system_user.$queriedtable ($columns) VALUES ($values)";
     my $sql_ref  = query_db($sql);
     $i++;
   }
   my $temp = $thisrole->short_name;
   my $msg6 = __("OK: [_1] policies assigned to the '[_2]' role",$i,$temp);
   print "\nOK: $msg6";
}

##############################################################################

=head2 creates_os_policies
 
 This subroutine reads os policies from the Roles.conf file and adds it to the database.
 Only these policies are added which are defined for the current role

=cut

sub creates_os_policies{
     my ($thisrole,$user_creator)= @_;
     my $last_change_user;
     my @action_types = qw ( program form raport subroutine www action);
     
     my $rtype=$thisrole->role_type;
     my $numbers = $thisrole->policies;
     my  @policies_from_file= split /,/, $numbers;
     my @policies= check_policies($rtype,\@policies_from_file);
     my $system_user = $apiis->Model->db_user;   
  
     if ($user_creator){
       $last_change_user=$user_creator;
     }else{
       $last_change_user=$apiis->User->id ;
     }     
     
     foreach my $policy (@policies){
       my $policy_id = $policy; #get_next_val('seq_policies__policy_id');
       my $policy_value= $thisrole->os_policy($policy);
       my @values= split /\|/, $policy_value;
       
       ### check action type #######
       if (grep /^$values[1]$/,  @action_types){
       
          my $app_policy_id= $policy;
	  my $app_name = $values[0];
	  my $app_class = $values[1];
	  my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
          my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
          my $owner=$apiis->node_name;
          my $version=1;
          my $values ="$app_policy_id,'$app_name','$app_class','$last_change_dt','$last_change_user',$guid,'$owner',$version";
          my $columns ='app_policy_id,app_name,app_class,last_change_dt,last_change_user,guid,owner,version';
          my $queriedtable = 'policies_app';
          my $sql = "INSERT INTO $system_user.$queriedtable ($columns) VALUES ($values)";
          my $sql_ref  = query_db($sql); 
       
       }else{
         my $msg7 =  __("OS policy [_1] is wrong definited in the Roles.conf file. Action type '[_2]' is not on the list (allowed types: program,form,raport,subroutine,action,www) ",$policy,$values[1]);
         $apiis->status(1);
	 $apiis->errors(
		       Apiis::Errors->new(
				      type      => 'AUTH',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::AccessControl::creates_os_policies',
				      msg_short =>  $msg7,
				     )
		      ); 	
	 die "\n\n!!! $msg7 !!!";
       }
     }
     return @policies_from_file;
}
#############################################################################################

=head2 asigns_os_policies

  this subroutine asigns operating sytstem policies to the current role.

=cut

sub asigns_os_policies{
   my ($thisrole,$ret_policies,$user_creator) = @_;
   my $system_user = $apiis->Model->db_user; 
   my $db_role =$thisrole->role_id();
   my $i=0;
   my $last_change_user;

   if ($user_creator){
     $last_change_user=$user_creator;
   }else{
     $last_change_user=$apiis->User->id ;
   }     
    
   foreach my $policyid  (@{$ret_policies}){
     ### create sql ###################################
     my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
     my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
     my $owner=$apiis->node_name;
     my $version=1;
     my $values ="$db_role,$policyid,'$last_change_dt','$last_change_user',$guid,'$owner',$version";
     my $columns ='role_id,app_policy_id,last_change_dt,last_change_user,guid,owner,version';
     my $queriedtable = 'role_policies_app';
     my $sql = "INSERT INTO $system_user.$queriedtable ($columns) VALUES ($values)";
     my $sql_ref  = query_db($sql);
     $i++;
   }
   my $temp = $thisrole->short_name;
   my $msg8 = __("[_1] policies assigned to the \"[_2]\" role",$i,$temp);
   print "\nOK: $msg8";
}
##### assign OS policy to the role (end) ########################################


##### user access view #######################################################

=head2 creates_access_view

  this subroutine creates user access view.

=cut

sub creates_access_view{
     my $user=shift;
     my $msg9 = __("Creating access view for user '[_1]'",$user);
     print "\n\n>>> $msg9";
     my $sql = "DROP VIEW $user.v_ar_".$user;
     my $sql_ref  = query_db($sql);

     $sql="CREATE VIEW $user.v_ar_".$user." as 
     SELECT
	tablename,
        columns,
        class,
	action
	
     FROM policies
     WHERE policy_id IN( 
	        	SELECT 
			    policy_id 
 	            	FROM role_policies 
	            	WHERE role_id IN(
					  SELECT
			        	      role_id
					  FROM user_roles
					  WHERE  user_id IN(
							     SELECT
							        user_id
							     FROM users
							     WHERE login='".$user."'
							    )
					)
       	      )";
     $sql_ref  = query_db($sql);
     my $msg10= __("User access view v_ar_[_1] (re)created",$user); 
     print "\nOK: $msg10 \n";
   }
#######################################################################

=head2 check_policies
 
 This subroutine checks that policies which we want to load 
 already are defined in the database.

=cut

sub check_policies{
  my ($policy_type,$file_policies)= @_;
  my @db_policies;
  my @finall_policies;
  my $system_user = $apiis->Model->db_user; 
  my ($queriedtable,$queriedcolumn);

  ### get all policy number from the database ####
  if ($policy_type eq 'DB'){
     $queriedtable = 'policies';
     $queriedcolumn= 'policy_id';
  }
  elsif ($policy_type eq 'OS'){
     $queriedtable = 'policies_app';
     $queriedcolumn= 'app_policy_id';
  }
  
  my $sql = "SELECT $queriedcolumn FROM $system_user.$queriedtable";
  my $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetch){
    push @db_policies, @{$value}[0];
  }
  ### check that policy (which are added now) are already existing in the database 
  foreach my $pol_file(@{$file_policies}){
    my $status=1;
  EXIT:
    foreach my $pol_db(@db_policies){
      if ($pol_file eq $pol_db){
	$status=0;
	last EXIT;
      }
    }
    if($status){
      push @finall_policies, $pol_file;
    }
  }
    
  return @finall_policies;
}
###################################################################

### del_user ##############################################################

=head2 del_user

  this subroutine deletes user from the system.

=cut

sub del_user{
    my $user=shift;
    my $user_id;
    my $uname;
    my $del_status=0;
    my $system_user = $apiis->Model->db_user;
    
    my $sql ="SELECT user_id,name FROM $system_user.users WHERE login='$user'";
    my $sql_ref  = query_db($sql);
    while(my $value = $sql_ref->handle->fetch){
      $del_status=1;
      $user_id= @{$value}[0];
      $uname = @{$value}[1];
    }
    if($del_status){
      my $sql ="DELETE from $system_user.user_roles WHERE user_id=$user_id";
      my $sql_ref  = query_db($sql);
      $sql ="DELETE from $system_user.users WHERE user_id=$user_id";
      $sql_ref  = query_db($sql);
      print "\nOK: ";
      print __("User [_1] \(login: [_2]\) removed from the system",$uname,$user);

      $sql ="DROP SCHEMA $user CASCADE";
      $sql_ref  = query_db($sql);
      print "\nOK: ";
      print __("Schema \"[_1]\" removed from PostgresSQL",$user);
      $sql ="DROP USER $user";
      $sql_ref  = query_db($sql);
      print "\nOK: ";
      print __("User [_1] (login: [_2]) removed from PostgresSQL\n",$uname,$user); 
    }else{
    print "\n!!! ";
    print __("This user is not existing in the system. Try run this script with '-s users' parameter to check which users are registered now in the system");
  }
}
#########################################################################

### del_role ###############################################################

=head2 del_role

  this subroutine deletes role from the system.

=cut

sub del_role{
  my $role=shift;
  my ($role_id,$role_type);
  my @ret_logins;
  my $rol_del_status=0;
  my $system_user = $apiis->Model->db_user;

  my $sql ="SELECT role_id,role_type FROM $system_user.roles WHERE role='$role'";
  my $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetch){
    $rol_del_status=1;
    $role_id= @{$value}[0];
    $role_type= @{$value}[1];
  }

  if($rol_del_status){
    my $sql ="SELECT login FROM $system_user.users WHERE user_id IN (SELECT user_id from $system_user.user_roles WHERE role_id=$role_id)";
    my $sql_ref  = query_db($sql);
    while(my $value = $sql_ref->handle->fetchrow_array()){
      push @ret_logins, $value;
    }
    $sql ="DELETE from user_roles WHERE role_id=$role_id";
    $sql_ref  = query_db($sql);
    print "\nOK: ";
    print __("Role \"[_1]\" revoked from the users",$role);
    ### revoke privilages #######
    foreach my $user_db (@ret_logins){
      revoke_priv($role_id,$user_db); 
    }
    if ($role_type eq 'DB'){
      my $sql ="DELETE from role_policies WHERE role_id=$role_id";
      my $sql_ref  = query_db($sql);
    }elsif($role_type eq 'OS'){
      my $sql ="DELETE from role_policies_app WHERE role_id=$role_id";
      my $sql_ref  = query_db($sql);
    }  
    $sql ="DELETE from roles WHERE role_id=$role_id";
    $sql_ref  = query_db($sql);
    print "\nOK: ";
    print __("Role '[_1]' removed from the system",$role);
  }else{
    print "\n";
    print __("This role is not existing in the system. Try run this script with '-s roles' parameter  to check which roles are defined now in the system");
  }
}
##########################################################################

### del_role_from_user #######################################################

=head2 del_role_from_user

  this subroutine revoke role from the user.

=cut

sub del_role_from_user{
  my ($role,$user)=@_;
  my $role_id;
  my $user_id;
  my ($rname,$rlogin);
  my $system_user = $apiis->Model->db_user; 

  my $sql ="SELECT role_id FROM $system_user.roles WHERE role='$role'";
  my $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetch){
    $role_id= @{$value}[0];
  }
  $sql ="SELECT user_id,name,login FROM $system_user.users WHERE login='$user'";
  $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetch){
    $user_id= @{$value}[0];
    $rname = @{$value}[1];
    $rlogin =  @{$value}[2];
  }
  $sql ="DELETE from user_roles WHERE role_id=$role_id and user_id=$user_id";
  $sql_ref  = query_db($sql);
  print "\nOK: ";
  print __("Role '[_1]' revoked from user '[_2]' \(login: [_3]\)",$role,$rname,$rlogin);
  ###revoke all privilages ###
  revoke_priv($role_id,$user);
}
##########################################################################

### revoke privileges ###########

=head2 revoke_priv

  this subroutine revoke user privileges from the PostgreSQL.

=cut

sub revoke_priv{
  my @policy_to_revoke;
  my ($role_id,$rev_user) = @_;
  my $system_user = $apiis->Model->db_user; 

  my $sql ="SELECT policy_id FROM $system_user.role_policies WHERE role_id=$role_id";
  my $sql_ref  = query_db($sql);
  while(my $value = $sql_ref->handle->fetchrow_array()){
    push @policy_to_revoke, $value;
  }
    foreach my $revoke_policy (@policy_to_revoke){
      my $sql ="SELECT action,tablename FROM $system_user.policies WHERE policy_id=$revoke_policy";
      my $sql_ref  = query_db($sql);
      while(my ($re_action,$re_tablename) = $sql_ref->handle->fetchrow_array){
	$revoke_action = $re_action;
	$revoke_table =   $re_tablename;

      }
      #Before variable namewas '$grant_action' (probably the right one is $revoke_action) Jivko 30-04-2008
      if ($revoke_action ne 'select'){
	my $sql ="REVOKE $revoke_action on $system_user.$revoke_table from $rev_user";
	my $sql_ref  = query_db($sql);
      }
    }
    print "\nOK: ";
    print __("Privileges revoked from PostgreSQL");
}
##################################################


### select_db #######################################################

=head2 select_db 

  this subroutine print information about users and roles which are curently defined in the system.

=cut

sub select_db{
  my $call = shift;
  my $no_users=1;
  my $no_roles=1;
  my $system_user = $apiis->Model->db_user;

  if ($call eq 'users'){
    my $sql ="SELECT user_id, login,name FROM $system_user.users";
    my $sql_ref  = query_db($sql);
    while(my @value = $sql_ref->handle->fetchrow_array()){
      $no_users=0;
      print "\n";
      print __("LOGIN:          [_1]",$value[1]);
      print "\n";
      print __("USER NAME:      [_1]",$value[2]);
      print "\n";
      print __("ASSIGNED ROLES:");
      my $sql ="select role_id from $system_user.user_roles WHERE user_id=$value[0]";
      my $sql_ref  = query_db($sql);
      while(my @second_value = $sql_ref->handle->fetchrow_array()){
	my $sql ="SELECT role FROM $system_user.roles WHERE role_id=$second_value[0]";
	my $sql_ref  = query_db($sql);

	while(my @third_value = $sql_ref->handle->fetchrow_array()){
	  print " $third_value[0],";	
	}
      }
      if ($no_users){
        print "\n!!! ";
	print __("No user definitions in the system"); 
      }
      print "\n\n";
    }
  }
  elsif ($call eq 'roles'){
    my $sql ="SELECT role,role_name_sh,role_name_lng,description FROM $system_user.roles";
    my $sql_ref  = query_db($sql);
    while(my @value = $sql_ref->handle->fetchrow_array()){
      $no_roles=0;
      print "\n";
      print __("ROLE:       [_1]",$value[0]);
      print "\n";
      print __("SHORT NAME: [_1]",$value[1]);
      print "\n";
      print __("LONG NAME:  [_1]",$value[2]);
      print "\n";
      print __("DESCRIPTION:[_1]",$value[3]);
      print "\n\n";
    }
    if ($no_roles){
      print "\n!!! ";
      print __("No role definitions in the system");
      print "\n"; 
    }
  }
}
######################################################################

### system of public views ##########################################

=head2 public_views 

  this subroutine creates system of the public views in the user schema.

=cut

sub public_views {
 my $user=shift;
 my @all_tables;
 my $db_code;
 my $user_status=0;
 my $system_user = $apiis->Model->db_user;
  print __("\n>>> Creating system of views");
 ### creates array with all table names allowed for the user (for select action) ###
  my $queriedtable="v_ar_".$user;
  my $sql = "SELECT distinct tablename from $user.$queriedtable WHERE action='select'";
  my $sql_ref = query_db($sql);
  if(!$sql_ref->status){
    while ( my $tablename = $sql_ref->handle->fetch ) {
      $user_status=1;
      push @all_tables, @{$tablename};
    }
  }

  if($user_status){  
  ### creates view for each table ###
   foreach my $table(@all_tables){   
     drop_views($table,$user); 
     my @columns_in_classes = col_in_classes($table,$user);
     my ( $str_maincolumns, @main_columns) = main_columns($table,\@columns_in_classes);
     my @sorted_columns =  class_columns(\@main_columns,\@columns_in_classes);
     creates_public_views($user,$table,$str_maincolumns,\@sorted_columns);
   }
  my $sql_1 = "GRANT ALL ON SCHEMA $user to $user";
  my $sql_ref1  = query_db($sql_1);
  my $sql_2 = "REVOKE create ON SCHEMA $user FROM $user";
  my $sql_ref2 = query_db($sql_2);  
  print "\nOK: "; 
  print __("System of views created");
  print "\n\n";
  }else{
  print "\n!!! ";
  print __("Access view for [_1] is not existing or user [_2] has not access rights to select on any table",$user); 
  print " !!!\n\n";
  }
}

### col_in_classes (system of public views) ###############################

=head2 col_in_classes 

  This subroutine querys DB about allowed columns for current user. Query 
  is executed with select action and current table name as a paramaters. 
  Returned list of columns is added to the hash with class names.  

=cut

sub col_in_classes{

  my ($table,$user)=@_;
  my @class_columns;
  my $finded_stat=0;

  my $queriedtable="v_ar_".$user;
  my $sql = "SELECT columns,class from $user.$queriedtable WHERE tablename='$table' and action='select'";
  my $sql_ref = query_db($sql);
  while ( my ($columns, $class) = $sql_ref->handle->fetchrow_array() ) {
    my %tmp_hash;
    %tmp_hash = 
      ( COLUMNS => $columns,
	CLASS   => $class,
      );
    push @class_columns, \%tmp_hash;

  }
  return @class_columns;
}

###  main columns #######################################################

=head2 main_columns
 
  This subroutine creates main list of column for the current table . Only these column names 
  are taken to the list, to which user have access rights (in several  classes). If table has 
  translation table then this list is created from two tables. This list is needed to 
  creates structure of view via UNION (we have to have list of all columne which will be in the 
  view). 

=cut

sub main_columns{

  my ($table,$columns_in_classes)=@_;
  my @mcolumns;
  ### add oid column ###
  my $rowid =   $apiis->DataBase->rowid;
  push @mcolumns, $rowid if ($rowid eq 'oid');
  ########################
  my $modeltable;
  
  if ($table =~ /entry_/){
    my $entrytab = $table;
    $entrytab =~ s/(.*entry_)(.*)$/$2/;
    $modeltable= $apiis->Model->table($entrytab);
  } else{
    $modeltable = $apiis->Model->table($table);
  }
  
  foreach my $modelcolumn (@{$modeltable->cols}){
    foreach my $tmpcolumn (@{$columns_in_classes}){
      my $column=$tmpcolumn->{COLUMNS};
      if($column=~ m/$modelcolumn/){
	push @mcolumns,$modelcolumn unless (grep /^$modelcolumn$/, @mcolumns);
      }
    }
  }
  my $str_mcolumns = join(',',@mcolumns);
  return  $str_mcolumns, @mcolumns;
}


### class_columns ########################################################

=head2 class_columns 

  Compares main column list to the column allowed for the user 
  in several classes. Columns list is created for each class. Columns order for the each class 
  have to be the same like in main list. Value NULL is putted to the list if some column doesn't 
  occure on the main list and user haven't access rights to this column in this class
  This all is needed to create finall sql where "union all" expresion is used.

=cut

sub class_columns {

my ($main_columns,$columns_in_classes) = @_;
my @sort_class_columns;
my $rowid = $apiis->DataBase->rowid;

foreach my $initcolumns (@{$columns_in_classes}){
  my @temp;
  my $columns = $initcolumns->{COLUMNS};
  my $class   = $initcolumns->{CLASS};
  $columns = join (',',$rowid,$columns) if ($rowid eq 'oid');

  foreach my $maincolumn (@{$main_columns}){
    if ($columns=~ m/$maincolumn/){
      push @temp, $maincolumn;
    }
    else{ 
      $maincolumn='NULL';
      push @temp,$maincolumn;
    }
  }
  my $string = join (',',@temp);
  
  my %tmp_hash;
  %tmp_hash = 
    ( COLUMNS => $string,
      CLASS   => $class,
    );
  push @sort_class_columns, \%tmp_hash;
}
return @sort_class_columns;
}

### creates view #########################################################

=head2 creates_view 

  This subroutine creates user view for current table.

=cut

sub creates_public_views{
  my ($user,$table_name,$str_maincolumns,$sorted_columns)=@_;
  my $system_user = $apiis->Model->db_user;
  my $rowid = $apiis->DataBase->rowid;
  
  my $sql = "CREATE VIEW $user.$table_name AS SELECT $str_maincolumns 
                    FROM $system_user.$table_name
                    WHERE owner=NULL";

  foreach my $sort (@{$sorted_columns}){
    my $columns = $sort->{COLUMNS}; 
    my $class = $sort->{CLASS}; 
    
    
    my $sql_ext =  "UNION  SELECT $columns FROM  $system_user.$table_name WHERE owner='$class'";
    $sql=join(' ',$sql,$sql_ext);
  }
  #my $dsql ="DROP VIEW $user.$table_name" ;
  #my $dsql_ref  = query_db($dsql);
  print "\n$sql\n";
  my $sql_ref= query_db($sql);

  my $gsql = "GRANT SELECT ON $user.$table_name to $user";
  my $gsql_ref  = query_db($gsql);
}
### drop_views ########################################################

=head2 drop_views 
  
  this subroutine drop current view from user schema.

=cut

sub drop_views{
  my ($drop_view,$user) =@_;
  my $system_user = $apiis->Model->db_user;
  
  my $dsql = "DROP VIEW $user.$drop_view";
  my $sql_ref= query_db($dsql);
}

### query_db #########################################################
 
=head2 query_db
  
  this subroutine executs system SQL statements.

=cut
 
 sub query_db {
  my $sql=shift;
  my $sql_ref = $apiis->DataBase->sys_sql($sql);
  $apiis->check_status;
  unless ( $apiis->status ){
    $apiis->DataBase->commit;
  }  

return $sql_ref;
} 

######################################################################

=head2 change_password  

  this subroutine is used to change user password.

=cut

 sub change_password {

  my $login= shift;
  my $passwd;
  my $repasswd;
  my $i=0;
  my $check_password=1;
  print "\n";
  print __("Changing password for user '[_1]'",$login);
  print "\n";
  while ($check_password and $i<3){
    print __("Please enter new password: ");
    my $not_ok = 1;
    while ($not_ok) {  
      ReadMode 2;
      chomp( $passwd = <> );
      ReadMode 0;
      print "\n";
      $not_ok = 0 if $passwd;
    } 
    print __("Please retype new password: ");
    my $re_not_ok = 1;
    while ($re_not_ok) {  
      ReadMode 2;
      chomp( $repasswd = <> );
      ReadMode 0;
      print "\n";
      $re_not_ok = 0 if $repasswd;
    }
    if($passwd eq $repasswd){
      $check_password=0;
    }
    else{
      print __("Sorry, passwords do not match");
      print "\n";
      $i++;
    }
  }
  
  if($i==3){
    print "\n";
    print __("ERR: Authentication information cannot be recovered");
  }
  else{ 
    my $password = md5_base64($passwd);   
    my $sql = "UPDATE users SET password='$password' where login='$login'";   
    my $sql_ref = query_db($sql);
    $apiis->check_status;
    unless ( $apiis->status){
      print "\n";
      print __("OK: Password changed for user '[_1]'",$login);
      print "\n";
    }
  } 
}

######################################################################

=head2 creates_views_v_

this code was copied from MakeSQL.pm module and partialy changed.  This
subroutine is used to create "v_" view under user schema.

Note (2008-04-08 heli):
As MakeSQL changed to allow self-referencing foreign keys I also had to change
this part of it. :^(

=cut

sub creates_views_v_ {
    my $user_schema = shift;
    print "\n>>> ", __("Creating views 'v_' for each table"), "\n";

    use vars qw/ $tab_alias %tab_trans %tmp_hash
        @join_tables_pre @join_alias_pre @join_cols_pre
        @join_tables_post @join_alias_post @join_cols_post
        /;

    # read table names from the model file:
    my @tables = $apiis->Model->tables;

    # for each table of this model:
    my ( $create, $columns, @sql_arr, @pk_views, %pk_index );
    TABLE:
    foreach my $tab (@tables) {
        my $table = $apiis->Model->table($tab);
        my $create_view;
        $columns = scalar @{ $table->cols };    # get number of columns

        my $max_db_column = 0;
        my $max_datatype  = 0;
        my @table_columns = $table->cols;
        foreach my $col (@table_columns) {
            my $meta_datatype = $table->datatype($col);
            $max_db_column = length($col) if length($col) > $max_db_column;
            $max_datatype =
                length( $apiis->DataBase->datatypes($meta_datatype) )
                if length( $apiis->DataBase->datatypes($meta_datatype) )
                > $max_datatype;
        }
        $max_db_column += 2;    # add to max length
        $max_datatype  += 2;

        # some view preparations:
        my ( @view_selects, @left_outer_joins );
        $tab_alias = 'a';
        $tab_trans{$tab} = $tab_alias;

        $create_view .= "CREATE VIEW $user_schema.v_$tab AS\nSELECT ";
        push @view_selects,
            "$tab_trans{$tab}" . '.'
            . $apiis->DataBase->rowid
            . ' AS v_'
            . $apiis->DataBase->rowid;

        # Getting the information from 'TABLE' key
        # primary key definitions and views:
        if ( $table->primarykey('ref_col') ) {
            if ( $table->primarykey('view') ) {
                # create special FK-view if defined:
                die sprintf
                    "Cannot create view '%s'! Table with same name defined.\n",
                    $table->primarykey('view') if %{$table->primarykey('view')};
                push @pk_views,
                    "CREATE VIEW " . $table->primarykey('view') . " AS";

                my @tmp_arr;
                push @tmp_arr, $table->cols;
                my $myrowid = $apiis->DataBase->rowid;
                push @tmp_arr, $myrowid if !( grep /^$myrowid$/, @tmp_arr );

                my $where_clause = '';
                $where_clause = sprintf "\nWHERE       %s",
                    $table->primarykey('where')
                    if $table->primarykey('where');
                push @pk_views, sprintf "SELECT      %s\nFROM        %s\n",
                    join( ', ', @tmp_arr ), $tab . $where_clause;
            }
        }    # end PRIMARYKEY

        my $ar_sql = sprintf "SELECT columns FROM %s.v_ar_%s "
                           . "WHERE tablename='%s'"
                           . "AND action='select'",
                     $user_schema, $user_schema, $tab;
        my $sql_ref = query_db($ar_sql);
        $sql_ref->check_status;
        my $row             = $sql_ref->handle->fetch;
        my $ar_columns      = $row->[0];
        my @allowed_columns = split /\|/, $ar_columns;

        my @exclude_cols = qw( last_change_dt last_change_user dirty chk_lvl
            guid owner version creation_dt creation_user end_dt end_user
            opening_dt opening_user );

        COLUMN:
        foreach my $col (@table_columns) {
            next COLUMN if grep /^${col}$/, @exclude_cols;
            next COLUMN if !( grep /^${col}$/, @allowed_columns );

            my $db_column = $col;
            $tmp_hash{ ${tab} . ${db_column} }++;

            # change META datatype into db_specific in one step:
            my $datatype =
                $apiis->DataBase->datatypes( lc $table->datatype($col) );

            $create .= "   $db_column"
                . ' ' x ( $max_db_column - length($db_column) );
            $create .= "$datatype";
            $columns > 1 ? ( $create .= "," ) : ( $create .= " " );
            $create .= ' ' x ( $max_datatype - length($datatype) );
            $create .= "\n";
            $columns--;

            push @view_selects, "$tab_trans{$tab}.${db_column}";

            # create additional column in view for FK-external values:
            # get ForeignKey rules:
            my ( $fk_table, $fk_col ) = HasFKRule( $tab, $col );

            # is there a cascaded chain of FK rules?:
            if ( $fk_table and $fk_col ) {
                ( $fk_table, $fk_col ) = Cascaded_FK( $fk_table, $fk_col );
            }

            if ( $fk_table and $fk_col ) {
                # temp arrays to solve concatenated primary keys
                my ( @fk_tables, @fk_cols, @table_aliases );
                push @fk_tables, $fk_table;
                push @fk_cols,   $fk_col;

                $tab_trans{$fk_table} = ++$tab_alias
                    if !exists $tab_trans{$fk_table};

                # (re)initialize:
                @join_tables_pre  = ($tab);
                @join_alias_pre   = ( $tab_trans{$tab} );
                @join_cols_pre    = ($db_column);
                @join_tables_post = ($fk_table);
                @join_alias_post  = ( $tab_trans{$fk_table} );
                @join_cols_post   = ($fk_col);

                my $new_db_col = $db_column;
                $new_db_col =~ s/^db_/ext_/i;
                $new_db_col = 'ext_' . $new_db_col
                    unless ( $new_db_col =~ /^ext_/i );
                push @table_aliases, $tab_trans{$fk_table};

                # take care of concatenated primary keys:
                my $has_concat_pk = 0;

                # pass parameters as array references for allowing to add
                # tables via recursion:
                resolve_concatenations( \@fk_tables, \@fk_cols, \@table_aliases )
                    if !( $fk_table eq $apiis->codes_table );

                # this is an ugly hardcoded hack:
                # the codes_table (usually codes) is known to have no deeper
                # dependencies to other tables. But what happens, if this
                # changes somewhen/somewhere? :^( I use it to prevent a
                # db_sex solving as: SEX >=< 1 The column class from codes is
                # not needed to solve the foreign key.
                my $delimiter = ${ $apiis->reserved_strings }{v_concat};
                for ( my $i = 0; $i <= $#fk_cols; $i++ ) {
                    # if the $fk_col starts with db_ (e.g. db_code) take the
                    # corresponding ext_ column. A bit clumsy as it depends on
                    # naming conventions, but ...
                    $fk_cols[$i] =~ s/^db_/ext_/;
                    $fk_cols[$i] = $table_aliases[$i] . '.' . $fk_cols[$i];
                }
                push @view_selects,
                    join( " || '$delimiter' || ", @fk_cols )
                    . " AS $new_db_col";

                for ( my $i = 0; $i <= $#join_tables_pre; $i++ ) {
                    push @left_outer_joins,
                        sprintf 'LEFT OUTER JOIN %s %s ON %s.%s = %s.%s',
                        $user_schema . '.' . $join_tables_post[$i],
                        $tab_trans{ $join_tables_post[$i] },
                        $join_alias_pre[$i], $join_cols_pre[$i],
                        $tab_trans{ $join_tables_post[$i] },
                        $join_cols_post[$i];
                }
            }    # end FK exists
        }    # end each $col of this $tab

        $create_view .= join( ",\n       ", @view_selects );
        # A self-referencing FK makes $tab_trans{$table} overwrite the
        # alias. We have to hardcode it in the FROM-clause:
        $create_view .= "\nFROM $user_schema.$tab a";
        my $tmp_count  = 0;
        my $thislength = length("FROM $user_schema.$tab x");
        while (@left_outer_joins) {
            if ($tmp_count) {
                $create_view
                    .= "\n" . ' ' x $thislength . ' ' . shift @left_outer_joins;
            }
            else {
                $create_view .= ' ' . shift @left_outer_joins;
                $tmp_count++;
            }
        }

        my $sql_ref101   = query_db($create_view);
        my $grant_sql = "GRANT SELECT ON $user_schema.v_$tab TO $user_schema";
        my $sql_ref1  = query_db($grant_sql);
    };    # end TABLE loop

    my $sql_1    = "GRANT ALL ON SCHEMA $user_schema to $user_schema";
    my $sql_ref1 = query_db($sql_1);
    $sql_ref1->check_status( die => 'ERR' );
    my $sql_2    = "REVOKE create ON SCHEMA $user_schema FROM $user_schema";
    my $sql_ref2 = query_db($sql_2);
    $sql_ref2->check_status( die => 'ERR' );
    print "\nOK: ", __("Views 'v_' created"), "\n";
}

1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de>

=cut
