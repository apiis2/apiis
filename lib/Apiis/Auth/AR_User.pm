##############################################################################
# $Id: AR_User.pm,v 1.15 2021/05/27 19:54:33 ulf Exp $
##############################################################################.
#package Apiis::Auth::AR_User;
$VERSION = '$Revision: 1.15 $';
##############################################################################

=head1 NAME

Apiis::Auth::AR_User

=head1 SYNOPSIS

 how to us your module

=head1 DESCRIPTION

 long description of your module

=head1 SEE ALSO

 need to know things before somebody uses your program
use strict;

=head1 METHODS

=cut

##############################################################################
use strict;
use warnings;
use Carp;
use Apiis::DataBase::Record;
use Apiis::Init;
use Data::Dumper;
use Digest::MD5 qw(md5_base64);
use Term::ReadKey;

our $apiis;
our $admin_defined;
our $debug;
##############################################################################

=head2 create_schema

  this subroutine creates individual user schema

=cut

sub create_schema{
 my ($user,$from_interface) = @_;

 EXIT:{
    my $sql = "select nspname from pg_catalog.pg_namespace where nspname='$user'";
    my $sql_ref = $apiis->DataBase->sys_sql($sql);
    if ($sql_ref->status){
      $apiis->errors( $sql_ref->errors );
      $apiis->status(1);
      last EXIT;
    }
    unless ($sql_ref->handle->rows){
      my $sql_1 = "CREATE SCHEMA $user";
      my $sql_ref_1 = $apiis->DataBase->sys_sql($sql_1);
      if ($sql_ref_1->status){
        $apiis->errors( $sql_ref_1->errors );
        $apiis->status(1);
        last EXIT;
      }
    }
    my $sql_2 = "GRANT USAGE ON SCHEMA $user to $user";
    my $sql_ref_2 = $apiis->DataBase->sys_sql($sql_2);
    if ($sql_ref_2->status){
         $apiis->errors( $sql_ref_2->errors );
         $apiis->status(1);
         last EXIT;
    }
    my $sql_3 = "REVOKE create ON SCHEMA $user FROM $user";
    my $sql_ref_3 = $apiis->DataBase->sys_sql($sql_3);
    if ($sql_ref_3->status){
         $apiis->errors( $sql_ref_3->errors );
         $apiis->status(1);
         last EXIT;
    }

    if ($debug>0){
      if ($apiis->status){
        print "\nOK: Schema created" unless (defined $from_interface);
      }else{
        print "\nER: Schema not created" unless (defined $from_interface);
      }
    }
  };
}
##############################################################################

=head2 create_user

  This subroutine creates new user. The new user is added in to the APIIS
  system and also in to the PostgreSQL database. The information about user is
  collected in the following tables: naming, address, unit, ar_users.

=cut

sub create_user{
   my ($user,$set_first_name,$set_second_name,$set_language,$set_user_marker,$set_password,$user_category) = @_;
   my ($user_id,$lang_id,$user_disabled,$user_status,$last_change_user,$last_change_dt,$guid,
       $version,$synch,$owner);
   my @err_array;
   my $pguser_status=0;
   my $new_apiis_user=1;
   my $user_registered=0;
   my $system_user = $apiis->Model->db_user;
   my $new_user_marker;
   $user_category='admin' if (!$user_category);

   ### set metafields which will be entered to the record if the admin is not defined ###
   if (!$admin_defined){
     $user_disabled='n';
     $user_status='n';
     $last_change_user= $apiis->os_user;
     $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
     $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
     $version=1;
     $synch='n';
     $owner=$apiis->node_name;
   }

EXIT:{
   ### check that the user is existing in the database ############################
   my $sql = "SELECT user_id FROM ar_users WHERE user_login='$user'";
   my $sql_ref = $apiis->DataBase->sys_sql($sql);
   if ($sql_ref->status){
     $apiis->errors( $sql_ref->errors );
     $apiis->status(1);
     last EXIT;
   }
   if ($sql_ref->handle->rows){
     my $value = $sql_ref->handle->fetch;
     $new_apiis_user=0;
     $user_id =@{$value}[0];
   }

   ### add new user ##############################
   if ($new_apiis_user){
     my ($passwd,$first_name,$second_name,$language);
     our $user_id =$apiis->DataBase->seq_next_val('seq_ar_users__user_id');
     my $language_status=1;

     print "\n";
     print __("REGISTERING NEW APIIS USER:");
     print "\n";
     print __("User login: [_1]",$user);
     print "\n";
     ### FIRST NAME ###
     print __("First user name: ");
     if ($set_first_name){
       $first_name=$set_first_name;
       print "$first_name\n";
     }else{
       chomp( $first_name = <> );
     }
     #print "\n";
     ### SECOND NAME ###
     print __("Second user name: ");
     if ($set_second_name){
       $second_name=$set_second_name;
       print "$second_name\n";
     }else{
       chomp( $second_name = <> );
     }
     #print "\n";
     ### PASSWORD ###
     print __("User password: ");
     if ($set_password){
       $passwd=$set_password;
       print "***\n";
     }else{
       ReadMode 2;
       chomp( $passwd = <> );
       ReadMode 0;
       print "\n";
     }
     my $password = md5_base64($passwd);
     #print "\n";
     ### USER MARKER ###
     print __("User marker which will be insert into the records as an owner column: ");
     if($set_user_marker){
       $new_user_marker=$set_user_marker;
       print "$new_user_marker\n";
     }else{
       chomp( $new_user_marker = <> );
     }
     #print "\n";
     ### LANGUAGE ###
     print __("User language (ISO code: en,pl,de, ...): ");
     while ($language_status){
       if($set_language){
         $language=$set_language;
         print "$language\n";
       }else{
         chomp( $language = <> );
       }
       my $sql_lang_1 = "SELECT lang_id FROM languages WHERE iso_lang = '$language'";
       my $fetched_1 = query_db($sql_lang_1);
       $fetched_1->status;
       if ($fetched_1->status){
         $apiis->errors( $fetched_1->errors );
         $apiis->status(1);
         last EXIT;
       }
       while ( my $ret = $fetched_1->handle->fetch ) {
         $lang_id = @{$ret}[0];
         $language_status = 0;
       }
       if ($language_status){
         my $msg1=__("No such language definition in the database");
         print "!!! $msg1 !!! \n";
	 my $sql_lang_2 = "SELECT lang_id FROM languages WHERE iso_lang = 'en'";
         my $fetched_2 = query_db($sql_lang_2);
         $fetched_2->check_status;
         while ( my $ret = $fetched_2->handle->fetch ) {
           $lang_id = @{$ret}[0];
           $language_status = 0;
         }
	 if ($language_status){
           $apiis->status(1);
               $apiis->errors(
                  Apiis::Errors->new(
                     type      => 'DATA',
                     severity  => 'ERR',
                     from      => 'Apiis::Auth::AR_User::create_user',
                     msg_short => __('No language definition in the database'),
                     msg_long  => __('You have to add at list englisch language in to the database'),
                  )
               );
           last EXIT;
	 }else{
	    my $msg1=__("Englisch set as default");
	    print "!!! $msg1 !!!\n";
	 }
       }
     }

     ### inserting user data ###

     if ($admin_defined){
       ### insert into the ar_users table ###
       my @mycolumns_1 =
         qw (user_id user_login user_password user_category user_language_id user_marker user_disabled user_status synch);
       push my @myvalues_1, $user_id,$user,$password,$user_category, $lang_id,$new_user_marker,"n","n","n";
       my $check_apiis_status = insert_record(\@mycolumns_1,\@myvalues_1,'ar_users');
       if ($check_apiis_status){
         $apiis->status(1);
         last EXIT;
       }else {
         $apiis->DataBase->dbh->commit;
       }
       ### insert into the ar_users_data table ###
       my @mycolumns_2 = qw (user_id user_first_name user_second_name synch);
       push my @myvalues_2, $user_id,$first_name,$second_name,"n";
       insert_record(\@mycolumns_2,\@myvalues_2,'ar_users_data');
       if ($check_apiis_status){
         $apiis->status(1);
         last EXIT;
       }
     }else{
       my $user_data_columns ='user_id,user_first_name,user_second_name,
          last_change_dt,last_change_user,creation_dt,creation_user,guid,version,synch,owner';
       my $user_data_values  ="$user_id,'$first_name','$second_name','$last_change_dt',
          '$last_change_user','$last_change_dt','$last_change_user',$guid,$version,'$synch','$owner'";

       my $user_columns ='user_id,user_login,user_password,user_category,user_language_id,user_marker,
          user_disabled,user_status,last_change_dt,last_change_user,guid,version,synch,owner';
       my $user_values="$user_id,'$user','$password','$user_category',$lang_id,'$new_user_marker','$user_disabled',
          '$user_status','$last_change_dt','$last_change_user',$guid,$version,'$synch','$owner'";

       ### insert into the ar_users_data table ###
       my $sql_usd = "INSERT INTO $system_user.ar_users_data ($user_data_columns)
                        VALUES ($user_data_values)";
       my $sql_ref_usd  = query_db($sql_usd);
       ### insert into the users table ###
       my $sql_us = "INSERT INTO $system_user.ar_users ($user_columns) VALUES ($user_values)";
       my $sql_ref_us  = query_db($sql_us);
     }

     ### create user in PostgreSQL  ###############
     my $msg4 = __("Checking the status of the user in PostgreSQL");
     print ">>> $msg4\n";
     my $sql_pguser = "select usename from pg_catalog.pg_user where usename='$user'";
     my $sql_ref_pg = $apiis->DataBase->sys_sql($sql_pguser);
     if ($sql_ref_pg->status){
       $apiis->errors( $sql_ref_pg->errors );
       $apiis->status(1);
       last EXIT;
     }else{
       $pguser_status=1 if ($sql_ref_pg->handle->rows);
     }

     if (!$pguser_status){
       #system("createuser -W $user"); #parametr -W Pg password
#my $sql_create_pguser = "create user $user password '$passwd' nocreatedb nocreateuser";
       #-- nocreateuser obsolete since 10.0
       my $sql_create_pguser = "create user $user password '$passwd' nocreatedb";
       my $sql_ref_cpguser = $apiis->DataBase->sys_sql($sql_create_pguser);

       if ($sql_ref_cpguser->status){
         $apiis->errors( $sql_ref_cpguser->errors );
         $apiis->status(1);
         last EXIT;
       }
       my $msg5 = __("User '[_1]' added to PostgreSQL",$user);
       print "OK: $msg5\n";

     }else{#pguser_status
       my $msg1 = __("User '[_1]' is existing in PostgreSQL",$user);
       print "!!! $msg1 !!!\n";
       $apiis->log( 'debug',"Apiis::Auth::AR_User::create_user: User '$user' is existing in PostgreSQL\n");
     }
     ### creates user in PostgreSQL (end) ###########

     unless ($apiis->status){
       $apiis->log( 'debug',"Apiis::Auth::AR_User::create_user:
                    User '$user' will be added to the APIIS system\n");
       my $msg3=__("User '[_1]' added to the APIIS system",$user);
       print "OK: $msg3\n";
     }

   }else{ #else for new apiis user
     $new_user_marker = $set_user_marker;
     my $msg1 = __("User '[_1]' is already registered in the APIIS System",$user);
     print "\n!!! $msg1 !!!\n";
     $user_registered=1;
     $apiis->log( 'debug',"Apiis::Auth::AR_User::create_user:
                  User '$user' is already registered in the APIIS System\n");
   }#end new apiis user
 }#EXIT
   return $user_id,$user_registered,$new_user_marker;
 }
##############################################################################

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
    }else{
      print __("Sorry, passwords do not match");
      print "\n";
      $i++;
    }
  }

  if($i==3){
    print "\n";
    print __("ERR: Authentication information cannot be recovered");
  }else{
    my $password = md5_base64($passwd);
    my $upd_record = Apiis::DataBase::Record->new( tablename => 'ar_users',);
    $upd_record->column('user_login')->extdata($login);
    my @records_to_update = $upd_record->fetch;
    foreach my $thisrecord (@records_to_update) {
      $thisrecord->column('user_password')->extdata($password);
      $thisrecord->column('user_password')->updated(1); # mark column as updated
      $thisrecord->update();
      $thisrecord->check_status;
      unless ( $thisrecord->status ) {
        $apiis->DataBase->commit;
        $apiis->check_status;
        $apiis->log( 'info',"Password changed for user $login");
        print "\n";
        print __("OK: Password changed for user '[_1]'",$login);
        print "\n";
      }
    }
  }
}
##############################################################################

=head2 delete_user

  this subroutine deletes user from the system.

=cut

sub delete_user{
    my ($user,$call_type,$from_interface) = @_;
    my ($user_id,$uname);
    my $delete_status=0;
    my $system_user = $apiis->Model->db_user;

 EXIT:{
    my $sql ="SELECT user_id FROM ar_users WHERE user_login='$user'";
    my $fetched  = query_db($sql);
    if ($fetched->status){
         $apiis->errors( $fetched->errors );
         $apiis->status(1);
         last EXIT;
    }
    while(my $value = $fetched->handle->fetch){
      $delete_status=1;
      $user_id= @{$value}[0];
    }

    if ($delete_status){
      my $sql_1a ="SELECT * from ar_user_roles WHERE user_id=$user_id";
      my $fetched_1a  = query_db($sql_1a);
      if ($fetched_1a->status){
         $apiis->errors( $fetched_1a->errors );
         $apiis->status(1);
         last EXIT;
      }
      my $rows = $fetched_1a->handle->rows;
      if ($rows){
        my $sql_1b ="DELETE from $system_user.ar_user_roles WHERE user_id=$user_id";
        my $fetched_1b  = $apiis->DataBase->sys_sql($sql_1b);
        if ($fetched_1b->status){
          $apiis->errors( $fetched_1b->errors );
          $apiis->status(1);
          last EXIT;
       }
      }

      my $sql_2a ="DELETE from $system_user.ar_users WHERE user_id=$user_id";
      my $fetched_2a  = $apiis->DataBase->sys_sql($sql_2a);
      if ($fetched_2a->status){
         $apiis->errors( $fetched_2a->errors );
         $apiis->status(1);
         last EXIT;
      }
      my $sql_2b ="DELETE from $system_user.ar_users_data WHERE user_id=$user_id";
      my $fetched_2b  = $apiis->DataBase->sys_sql($sql_2b);
      if ($fetched_2b->status){
         $apiis->errors( $fetched_2b->errors );
         $apiis->status(1);
         last EXIT;
      }
      print "\nOK: " if (not defined $from_interface);;
      print __("User '[_1]' removed from the APIIS system",$user) if (not defined $from_interface);;
      $apiis->log( 'info',"User '$user' removed from the APIIS system");

      if ($call_type eq 'del_user_p'){
        my $sql_3 ="DROP SCHEMA $user CASCADE";
        my $fetched_3  = $apiis->DataBase->sys_sql($sql_3);;
        if ($fetched_3->status){
          $apiis->errors( $fetched_3->errors );
          $apiis->status(1);
          last EXIT;
        }
        print "\nOK: ";
        print __("Schema \"[_1]\" removed from PostgresSQL",$user);
        $apiis->log( 'info',"Schema '$user' removed from the PostgreSQL");

        my $sql_4 ="DROP USER $user";
        my $fetched_4  = $apiis->DataBase->sys_sql($sql_4);;
        if ($fetched_4->status){
          $apiis->errors( $fetched_4->errors );
          $apiis->status(1);
          last EXIT;
        }
        print "\nOK: " if (not defined $from_interface);;
        print __("User '[_1]' removed from the PostgresSQL",$user) if (not defined $from_interface);;
        print "\n" if (not defined $from_interface);;
        $apiis->log( 'info',"User '$user' removed from the PostgreSQL");
      }

    }else{
      my $msg = __("User '[_1]' is not existing in the APIIS system.",$user);
      my $msg_l = __("Try to run this script with '-s users' parameter
                    to check which users are defined in the system");
      $apiis->status(1);
      $apiis->errors(
        Apiis::Errors->new(
          type      => 'DATA',
          severity  => 'ERR',
          from      => 'Apiis::Auth::AR_User::delete_user',
          msg_short => $msg,
          msg_long => $msg_l,
        )
      );
      last EXIT;
    }
 };#EXIT
}
###########################################################################
=head2 delete_role

  this subroutine deletes role from the system.

=cut

sub delete_role{
  my ($role,$from_interface) = @_;
  my ($role_id,$role_type);
  my @ret_logins;
  my $rol_del_status=0;
  my $system_user = $apiis->Model->db_user;

 EXIT:{
  my $sql ="SELECT role_id,role_type FROM ar_roles WHERE role_name='$role'";
  my $fetched  = query_db($sql);
  if ($fetched->status){
    $apiis->errors( $fetched->errors );
    $apiis->status(1);
    last EXIT;
  }
  while(my $value = $fetched->handle->fetch){
    $rol_del_status=1;
    $role_id= @{$value}[0];
    $role_type= @{$value}[1];
  }

  if ($rol_del_status){
    my $sql_1 ="SELECT role_id,user_id FROM ar_user_roles WHERE role_id=$role_id";
    my $fetched_1  = query_db($sql_1);
    if ($fetched_1->status){
      $apiis->errors( $fetched_1->errors );
      $apiis->status(1);
      last EXIT;
    }
    my $rows = $fetched_1->handle->rows;
    my @user_for_recreation;
    while (my $value = $fetched_1->handle->fetch) {
      push @user_for_recreation,$value->[1];
    }
    
    if ($rows){
      my $sql_2 ="DELETE from ar_user_roles WHERE role_id=$role_id";
      my $fetched_2  = $apiis->DataBase->sys_sql($sql_2);
      if ($fetched_2->status){
        $apiis->errors( $fetched_2->errors );
        $apiis->status(1);
        last EXIT;
      }
      
      my $sql ="SELECT user_login,user_marker FROM ar_users 
                WHERE user_id IN (". join (',',@user_for_recreation) .")";
      my $fetched  = query_db($sql);
      if ($fetched->status){
        $apiis->errors( $fetched->errors );
        $apiis->status(1);
        last EXIT;
      }
      while (my $value = $fetched->handle->fetch) {
        if ($role_type eq 'ST') {
          create_st_access_view( $value->[0], $from_interface );
        } 
        else {
          create_dbt_access_view( $value->[0], $from_interface );
          table_views( lc $value->[0], $value->[1], $from_interface );
        }
      }

      if ($apiis->status){
        last EXIT;
      }
      else {
        print "\nOK: " if (not defined $from_interface);
        print __("Role \"[_1]\" revoked from the users",$role) if (not defined $from_interface);
      }
    }

    if ($role_type eq 'DBT') {
      my $sql_3a ="SELECT role_id FROM ar_role_dbtpolicies WHERE role_id=$role_id";
      my $fetched_3a  = query_db($sql_3a);
      if ($fetched_3a->status){
        $apiis->errors( $fetched_3a->errors );
        $apiis->status(1);
        last EXIT;
      }
      my $rows_3a = $fetched_3a->handle->rows;
      if ($rows_3a) {
        my $sql_3b ="DELETE from ar_role_dbtpolicies WHERE role_id=$role_id";
        my $fetched_3b  = $apiis->DataBase->sys_sql($sql_3b);
        if ($fetched_3b->status){
          $apiis->errors( $fetched_3b->errors );
          $apiis->status(1);
          last EXIT;
        }
      }
    }elsif($role_type eq 'ST'){
      my $sql_3a ="SELECT role_id FROM ar_role_stpolicies WHERE role_id=$role_id";
      my $fetched_3a  = query_db($sql_3a);
      if ($fetched_3a->status){
        $apiis->errors( $fetched_3a->errors );
        $apiis->status(1);
        last EXIT;
      }
      my $rows_3a = $fetched_3a->handle->rows;
      if ($rows_3a) {
        my $sql_3b ="DELETE from ar_role_stpolicies WHERE role_id=$role_id";
        my $fetched_3b  = $apiis->DataBase->sys_sql($sql_3b);
        if ($fetched_3b->status){
          $apiis->errors( $fetched_3b->errors );
          $apiis->status(1);
          last EXIT;
        }
      }
    }
    my $sql_4 ="DELETE from ar_roles WHERE role_id=$role_id";
    my $fetched_4  = $apiis->DataBase->sys_sql($sql_4);
    if ($fetched_4->status){
      $apiis->errors( $fetched_4->errors );
      $apiis->status(1);
      last EXIT;
    }
    print "\nOK: " if (not defined $from_interface);
    print __("Role '[_1]' removed from the APIIS system",$role) if (not defined $from_interface);
    $apiis->log( 'info',"Role '$role' removed from the APIIS system");

  }else{
    my $msg = __("Role '[_1]' is not existing in the APIIS system.",$role);
    my $msg_l = __("Try to run this script with '-s roles' parameter
                    to check which roles are defined in the system");
    $apiis->status(1);
    $apiis->errors(
      Apiis::Errors->new(
        type      => 'DATA',
        severity  => 'ERR',
        from      => 'Apiis::Auth::AR_User::delete_role',
        msg_short => $msg,
        msg_long => $msg_l,
      )
    );
    last EXIT;
  }
 };#EXIT
}
##############################################################################

=head2 revoke_role_from_user

  this subroutine revoke role from the user. $from_interface parameter is used
  only if you want to call this subroutine from the interface and is needed to
  remove the standard print-outs.

=cut

sub revoke_role_from_user{
  my ($ret_role,$user,$from_interface) = @_;
  my $role_id;
  my ($user_id,$user_login);
  my $system_user = $apiis->Model->db_user;

 EXIT:{
  foreach my $role (@$ret_role){
    my $sql ="SELECT role_id FROM ar_roles WHERE role_name='$role'";
    my $fetched  = query_db($sql);
    if ($fetched->status){
      $apiis->errors( $fetched->errors );
      $apiis->status(1);
      last EXIT;
    }
    my $rows = $fetched->handle->rows;
    if (!$rows){
      my $msg = __("Role '[_1]' is not existing in the APIIS system",$role);
      $apiis->status(1);
      $apiis->errors(
        Apiis::Errors->new(
          type      => 'DATA',
          severity  => 'ERR',
          from      => 'Apiis::Auth::AR_User::revoke_role_from_user',
          msg_short => $msg,
        )
      );
      last EXIT;
    }
    while(my $value = $fetched->handle->fetch){
      $role_id= @{$value}[0];
    }

    my $sql_1 ="SELECT user_id FROM ar_users WHERE user_login='$user'";
    my $fetched_1  = query_db($sql_1);
    if ($fetched_1->status){
      $apiis->errors( $fetched_1->errors );
      $apiis->status(1);
      last EXIT;
    }
    my $rows_1 = $fetched_1->handle->rows;
    if (!$rows_1){
      my $msg = __("User '[_1]' is not existing in the APIIS system",$user);
      $apiis->status(1);
      $apiis->errors(
        Apiis::Errors->new(
          type      => 'DATA',
          severity  => 'ERR',
          from      => 'Apiis::Auth::AR_User::revoke_role_from_user',
          msg_short => $msg,
        )
      );
      last EXIT;
    }

    while(my $value = $fetched_1->handle->fetch){
      $user_id= @{$value}[0];
    }

    my $sql_2a ="SELECT role_id FROM ar_user_roles WHERE role_id=$role_id and user_id=$user_id";
    my $fetched_2a  = query_db($sql_2a);
    if ($fetched_2a->status){
      $apiis->errors( $fetched_2a->errors );
      $apiis->status(1);
      last EXIT;
    }
    my $rows_2 = $fetched_2a->handle->rows;
    if (!$rows_2){
      my $msg = __("Role '[_1]' is not asigned to the user '[_2]'",$role,$user);
      $apiis->status(1);
      $apiis->errors(
        Apiis::Errors->new(
          type      => 'DATA',
          severity  => 'ERR',
          from      => 'Apiis::Auth::AR_User::revoke_role_from_user',
          msg_short => $msg,
        )
      );
      last EXIT;
    }

    my $sql_2b ="DELETE from ar_user_roles WHERE role_id=$role_id and user_id=$user_id";
    my $fetched_2b  = $apiis->DataBase->sys_sql($sql_2b);
    if ($fetched_2b->status){
      $apiis->errors( $fetched_2b->errors );
      $apiis->status(1);
      last EXIT;
    }
    print "\nOK: " if (not defined $from_interface);
    print __("Role '[_1]' revoked from user '[_2]'",$role,$user) if (not defined $from_interface);
    $apiis->log( 'info',"Role '$role' revoked from user '$user'");
  }
 };#EXIT
}
##############################################################################
1;

__END__

=head1 AUTHOR

 Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut
