#!/usr/bin/env perl
##############################################################################
# $Id: access_rights_manager.pl,v 1.5 2019/09/24 11:49:27 ulf Exp $
##############################################################################.

=head1 NAME

access_rights_manager.pl -- perl script to manage of access rights. Add and delete users, add and delete roles, 
                     grant roles to the users, revoke roles from the users, show users and roles 
		     defined in the system.

=head1 SYNOPSIS

access_rights_manager.pl -p [project_name]  [OPTIONS]

=head1 COMMENTS

       If you want to add new role, first you have to define this role in \"APIIS_LOCAL/etc/AR_Batch.conf\" file (initially all
       information are taken from this file).

=head1 OPTIONS

       -p [project name]                       - set project name (always required);
       -o [password]                           - password for administrator
       -l [loginname administrator]


       -s [roles|users]                        - print all roles or users which are already defined 
                                                 in the system;
       -c [login name]                         - (re)create user access views (system tasks view 
                                                 and database tasks view);
       -v [login name]                         - (re)create system of views in user schema;
       -w [login name]                         - (re)create 'v_' views for each table in user schema;
       -e [login name]                         - (re)create entry views in user schema [login name];
       -t [login name]                         - change a password for defined user
       -r [role name]                          - add new role to the system; role name have 
                                                 to be defined in \"etc/AR_Batch.conf\" file;
       -u [login name]                         - add new user to the PostgreSQL and to the system; 
       -u [login name]  -r [role1,role2,...]   - grant roles to the user;
       -d [user|user_p] -u [login name]        - delete user from the APIIS system (if you use 
                                                 value 'user_p' then the user will be also removed 
                                                 from the PostgreSQL;
       -d role -r [role name]                  - delete role from the APIIS system;
       -u [login name] -r [role name]          - grant role to the user;
       -d revoke -u [user name] -r [role name] - revoke role from the user;
       -h                                      - print help;

=cut


BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.5 $ ');
#############################################################################
#use strict;
#use warnings;
use Apiis::Init;
use apiis_alib;
use Apiis::DataBase::Record;
use Apiis::Auth::AR_Common;
use Apiis::Auth::AR_Component;
use Apiis::Auth::AR_User;
use Apiis::Auth::AR_View;
use Term::ReadKey;
our $apiis;
#############################################################################
my ($project_name, $role_shortcut,$value,$s_call,$call_type) = parameters();
my $proj_apiis_local = $apiis->project($project_name);
$apiis->APIIS_LOCAL($proj_apiis_local);
my $model_file = $apiis->APIIS_LOCAL."/etc/".$project_name.'.model';

use Apiis::DataBase::User;
my $user_obj=Apiis::DataBase::User->new(id =>$opt_l);
$user_obj->password($opt_o);

$apiis->join_model($project_name,  userobj=>$user_obj,);

#############################################################################

$apiis->join_auth($opt_l);

#my $login_user=$apiis->User->id;
#############################################################################

 EXIT:{

  #### Cheking access rights for this application ####
  $apiis->Auth->check_system_tasks('program','access_rights_manager.pl');
  if ($apiis->Auth->status){
      $apiis->status(1);
      $apiis->errors($apiis->Auth->errors);
      last EXIT;
  }

  #### Cheking if the administrator is already defined ####
  check_users_table();
  last EXIT if ($apiis->status); 

  #### SHOW INFORMATION ABOUT USERS AND ROLES ####
  if ($call_type eq 'select_db'){
    if (($s_call eq 'roles') or ($s_call eq 'users')){ 
      $apiis->Auth->check_system_tasks('action','show info about users or roles');
      if ($apiis->Auth->status){
        $apiis->status(1);
        $apiis->errors($apiis->Auth->errors);
        last EXIT;
      }
      read_info_about_user_or_roles($s_call);
    }else{
      my $msg1 = __("Parameter '-s' is not corectly set");
      my $msg2 = __("With this parameter you can use 'roles' or 'users' value");
      my $msg3 = __("access_rights_manager.pl - p project_name -s roles");
      print "\n!!! $msg1 !!!\n";
      print "$msg2\n\n";
      die "$msg3\n\n";
    }
  }
  #### CREATING USER ACCESS RIGHTS VIEWS ####
  elsif ($call_type eq 'create_access_views'){
    create_st_access_view($value); 
    create_dbt_access_view($value); 
  }
  #### CREATING USER PUBLIC VIEWS ####
  elsif ($call_type eq 'create_views'){
    $apiis->Auth->check_system_tasks('action','create public views');
    if ($apiis->Auth->status){
      $apiis->status(1);
      $apiis->errors($apiis->Auth->errors);
      last EXIT;
    }
    table_views($value) ;
  }
  #### CREATING V_ VIEWS ####
  elsif ($call_type eq 'create_views_v_'){
    v_views($value); 
  }
  #### CREATING ENTRY VIEWS ####
  elsif ($call_type eq 'create_entry_views'){
    entry_views($value); 
  }
  #### CHANGING USER PASSWORD ####
  elsif ($call_type eq 'change_passwd'){
    change_password($value); 
  }
  #### ADDING NEW USER ####
  elsif ($call_type eq 'add_user'){
    $apiis->Auth->check_system_tasks('action','add new user');
    if ($apiis->Auth->status){
      $apiis->status(1);
      $apiis->errors($apiis->Auth->errors);
      last EXIT;
    }
    my ($user_id,$user_registered) = create_user(lc $value); 
    unless ($apiis->status or $user_registered){ create_schema(lc $value)};
    last EXIT if ($apiis->status);
  }
  #### ADDING NEW ROLE ####
  elsif ($call_type eq 'add_role'){
    $apiis->Auth->check_system_tasks('action','add new role');
    if ($apiis->Auth->status){
      $apiis->status(1);
      $apiis->errors($apiis->Auth->errors);
      last EXIT;
    }

    my @role_names = split ',', $role_shortcut;
    my ($user_roles,$st_policies,$dbt_policies,$stp_notget,$dbtp_notget) = collect_roles(\@role_names);
    last EXIT if ($apiis->status);

    my $new_roles = create_role(\%$user_roles);
    last EXIT if ($apiis->status);
    $apiis->check_status;
    $apiis->DataBase->dbh->commit;

    create_stpolicies(\%$st_policies,\%$new_roles) unless $stp_notget;
    create_dbtpolicies(\%$dbt_policies,\%$new_roles) unless $dbtp_notget;

    assign_policy(\%$new_roles);

  }
  #### ASIGNING ROLES TO THE USER ####
  elsif ($call_type eq 'grant_role_to_user'){
    $apiis->Auth->check_system_tasks('action','grant role to the user');
    if ($apiis->Auth->status){
      $apiis->status(1);
      $apiis->errors($apiis->Auth->errors);
      last EXIT;
    }
    my @role_names = split ',', $role_shortcut;
    assign_roles(\@role_names,lc $value);
    last EXIT if ($apiis->status);
    create_dbt_access_view($value); 
    create_st_access_view($value); 
  }
  #### DELETING USER ####
  elsif ($call_type eq 'del_user' or $call_type eq 'del_user_p'){
    $apiis->Auth->check_system_tasks('action','delete user');
    if ($apiis->Auth->status){
      $apiis->status(1);
      $apiis->errors($apiis->Auth->errors);
      last EXIT;
    }
    delete_user($value,$call_type);
  }
  #### DELETING ROLE ####
  elsif ($call_type eq 'del_role'){
    $apiis->Auth->check_system_tasks('action','delete role');
    if ($apiis->Auth->status){
      $apiis->status(1);
      $apiis->errors($apiis->Auth->errors);
      last EXIT;
    }
    delete_role($role_shortcut);
  }
  ### REVOKING ROLE FROM THE USER ####
  elsif ($call_type eq 'revoke_role_from_user'){
    $apiis->Auth->check_system_tasks('action','revoke role from the user');
    my @role_names = split ',', $role_shortcut;
    revoke_role_from_user(\@role_names,$value);
  }
  print "\n\n";
 };

$apiis->check_status;
if ($apiis->status){
  $apiis->DataBase->dbh->rollback;
}else {
  $apiis->DataBase->dbh->commit;
}

### parameters ############################################################
sub parameters{
#my ($opt_p,$opt_u,$opt_r,$opt_s,$opt_d,$opt_v,$opt_h);
use vars qw( $opt_p $opt_e $opt_u $opt_r $opt_s $opt_d $opt_v $opt_w $opt_t $opt_c $opt_h $opt_o $opt_l);
 
my $role;
my $project_name;
my ($r_call,$u_call,$s_call,$c_call);
my $call_type;
# allowed parameters:
use Getopt::Std;
getopts('p:e:u:r:s:d:v:w:t:c:hl:o:'); # option -h  => Help

if ($opt_h) {
  system ("clear");
  die __('access_rights_manager_USAGE_MESSAGE');
}

if ($opt_p){
  $project_name = $opt_p;
}
else{ 
  my $msg1 = __("Missing parameter");
  my $msg2 = __("You have to specify project name");
  my $msg3 = __("Try help with -h option");
  print "\n!!! $msg1 !!!"; 
  print "\n$msg2\n"; 
  die("$msg3\n\n"); 
}


if (((defined $opt_r) and (defined $opt_s)) or ((defined $opt_u) and (defined $opt_s)) 
     or ((defined $opt_d) and (defined $opt_s)) or ((defined $opt_v) and (defined $opt_s)) 
     or ((defined $opt_w) and (defined $opt_s)) or ((defined $opt_t) and (defined $opt_s))
     or ((defined $opt_e) and (defined $opt_s)) or ((defined $opt_c) and (defined $opt_s))
     or ((defined $opt_t) and (defined $opt_s))){
  my $msg1 = __("Parameter '-s' can be used only with '-p' parameter");   
  die "\n!!! $msg1 !!!\n\n"; 
}
elsif (($opt_r and $opt_v) or ($opt_u and $opt_v) or ($opt_d and $opt_v) or ($opt_w and $opt_v)
      or ($opt_e and $opt_v) or ($opt_c and $opt_v) ){
  my $msg1 = __("Parameter '-v' can be used only with '-p' parameter");
  die "\n!!! $msg1 !!!\n\n"; 
}
elsif (($opt_r and $opt_t) or ($opt_u and $opt_t) or ($opt_d and $opt_t) or ($opt_v and $opt_t)
      or ($opt_w and $opt_t) or ($opt_c and $opt_t) or ($opt_e and $opt_t)){
  my $msg1 = __("Parameter '-t' can be used only with '-p' parameter");
  die "\n!!! $msg1 !!!\n\n"; 
}
elsif ($opt_d eq 'revoke' and $opt_r and $opt_u){
  $r_call =$opt_r;
  $u_call=$opt_u;
  $call_type ='revoke_role_from_user';
}
elsif (($opt_d eq 'user_p' or $opt_d eq 'user') and $opt_u ){
  $u_call=$opt_u;
  if ($opt_d eq 'user_p'){
    $call_type ='del_user_p';
  }else{
    $call_type ='del_user';
  }
}
elsif ($opt_d eq 'role' and $opt_r){
  $r_call=$opt_r;
  $call_type ='del_role';
}
elsif ($opt_r and $opt_u){
  $r_call =$opt_r;
  $u_call=$opt_u;
  $call_type ='grant_role_to_user';
}
elsif ($opt_r  or $opt_u or $opt_s or $opt_d or $opt_v or $opt_t or $opt_w or $opt_c or $opt_e){
  if ($opt_r){
    $r_call =$opt_r;
    $call_type ='add_role';
  }
  if ($opt_u){
    $u_call=$opt_u;
    $call_type='add_user';
  }
  if ($opt_s){
    $s_call=$opt_s;
    $call_type='select_db';
  }
  if ($opt_d){
    my $msg1 = __("Missing parameters");
    my $msg2 = __("Try help with '-h' option");
    die "\n!!! $msg1 !!!\n$msg2\n\n";
  }
  if ($opt_v){
    $u_call=$opt_v;
    $call_type='create_views';   
  }
  if ($opt_t){
    $u_call=$opt_t;
    $call_type='change_passwd';   
  }
  if ($opt_w){
    $u_call=$opt_w;
    $call_type='create_views_v_';   
  }
  if ($opt_c){
    $u_call=$opt_c;
    $call_type='create_access_views';   
  }
  if ($opt_e){
    $u_call =$opt_e;
    $call_type ='create_entry_views';
  }
}
else { 
  my $msg1 = __("Missing parameters");
    my $msg2 = __("Try help with '-h' option");
    die "\n!!! $msg1 !!!\n$msg2\n\n";
}

return $project_name, $r_call,$u_call,$s_call,$call_type;
}
#########################################################################


######################################################################

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut
