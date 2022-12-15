#!/usr/bin/env perl
##############################################################################
# $Id: access_control.pl,v 1.12 2005/05/03 15:46:29 marek Exp $
##############################################################################.

=head1 NAME

access_control.pl -- perl script to management of access rights. Add and delete users, add and delete roles, 
                     grant roles to the users, revoke roles from the users, show users and roles already 
		     defined in the system.

=head1 SYNOPSIS

access_control.pl  [OPTIONS]

=head1 COMMENTS

       If you want to add new role, first you have to define this role in \"APIIS_LOCAL/etc/Roles.conf\" file (initially all
       information are taken from this file). Parameter [role name] has to be the same like you are defined in Roles.conf file
       (role name form quadrat brackets).

=head1 OPTIONS
       
       -p [project name]                       - sets project name; 
       -r [role name]                          - adds new role to the system; role name have to be defined in \"etc/Roles.conf\" file;
       -u [login name]                         - adds new user to PostgreSQL and to the system; 
       -d user -r [login name]                 - deletes user [login name] from PostgreSQL and from the system;
       -d role -r [role name]                  - deletes role [role name]  from the system;
       -u [login name] -r [role name]          - assigns role to the user and also add role and user if they are not defined in the system; 
       -d revoke -u [user name] -r [role name] - revokes role [role name] from the user [login name];
       -s [roles|users]                        - prints all roles or users which are already defined in the system;
       -v [login name]                         - creates system of view for the user [login name];
       -w [login name]                         - creates 'v_' views for each table unedr user schema [login name];
       -t [login name]                         - change a password for defined user
       -h                                      - prints help;
        
=cut


BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}
#use strict;
#use warnings;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.12 $ ');
use Apiis::Init;
use apiis_alib;
use Apiis::DataBase::Record;
use Apiis::Auth::AccessControl;
use Term::ReadKey;
our $apiis;

#############################################################################
my ($project_name, $role_shortcut,$user,$s_call,$call_type) = parameters();
my $proj_apiis_local = $apiis->project($project_name);
$apiis->APIIS_LOCAL($proj_apiis_local);
my $model_file = $apiis->APIIS_LOCAL."/etc/".$project_name.'.model';
$apiis->join_model($project_name);
#############################################################################

### Cheking access rights for this application ##############################
my $login_user=$apiis->User->id;
$apiis->join_auth($login_user);
$apiis->Auth->check_os_action('access_control.pl','program');
#############################################################################

if ($call_type eq 'select_db'){
  if (($s_call eq 'roles') or ($s_call eq 'users')){ 
    $apiis->Auth->check_os_action('show info about users or roles','action');  
    select_db($s_call);
  }else{
    my $msg1 = __("Parameter '-s' is not corectly set");
    my $msg2 = __("With this parameter you can use 'roles' or 'users' only");
    my $msg3 = __("access_control - p project_name -s roles");
    print "\n!!! $msg1 !!!\n";
    print "$msg2\n\n";
    die "$msg3\n\n";
  }
}
elsif ($call_type eq 'create_views'){
  $apiis->Auth->check_os_action('create public views','action');
  public_views($user); 
}
elsif ($call_type eq 'create_views_v_'){
  creates_views_v_($user); 
}
elsif ($call_type eq 'change_passwd'){
  $apiis->Auth->check_os_action('create public views','action');
  change_password($user); 
}
elsif ($call_type eq 'add_user'){
  $apiis->Auth->check_os_action('add new user','action');
  creates_schema($user);
  creates_user($user); 
}
elsif ($call_type eq 'add_role'){
  $apiis->Auth->check_os_action('add new role','action');
  my ($thisrole,$create_role_status) = creates_role($role_shortcut);

  if($create_role_status){
     my $roletype =  $thisrole->role_type;
     my $role_name = $thisrole->role_name;
      if ($roletype eq 'DB'){
         my @ret_db_policies = creates_db_policies($thisrole);
         asigns_db_policies($thisrole,\@ret_db_policies);
      }
      elsif ($roletype eq 'OS'){
         my @ret_os_policies = creates_os_policies($thisrole);
         asigns_os_policies($thisrole,\@ret_os_policies);          
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
	 die "\n\n!!! $msg !!!\n";
      }
    }
  }
elsif ($call_type eq 'grant_role_to_user'){
  $apiis->Auth->check_os_action('grant role to the user','action');
  creates_schema($user);
  creates_user($user);
  my ($thisrole,$create_role_status) = creates_role($role_shortcut);

  if($create_role_status){
   my $roletype =  $thisrole->role_type;
   my $role_name = $thisrole->role_type;
      if ($roletype eq 'DB'){
         my @ret_db_policies = creates_db_policies($thisrole);
         asigns_db_policies($thisrole,\@ret_db_policies);
      }
      elsif ($roletype eq 'OS'){
         my @ret_os_policies = creates_os_policies($thisrole);
         asigns_os_policies($thisrole,\@ret_os_policies);          
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
  assigns_role($user,$role_shortcut);
  creates_access_view($user);
}
elsif ($call_type eq 'del_role'){
  $apiis->Auth->check_os_action('delete role','action');
  del_role($role_shortcut);
}
elsif ($call_type eq 'del_user'){
  $apiis->Auth->check_os_action('delete user','action');
  del_user($user);
}
elsif ($call_type eq 'revoke_role_from_user'){
  $apiis->Auth->check_os_action('revoke role from the user','action');
  del_role_from_user($role_shortcut,$user);
}
print "\n\n";

### parameters ############################################################
sub parameters{
#my ($opt_p,$opt_u,$opt_r,$opt_s,$opt_d,$opt_v,$opt_h);
use vars qw( $opt_p $opt_u $opt_r $opt_s $opt_d $opt_v $opt_w $opt_t $opt_h );
 
my $role;
my $project_name;
my ($r_call,$u_call,$s_call,$c_call);
my $call_type;
# allowed parameters:
use Getopt::Std;
getopts('p:u:r:s:d:v:w:t:h'); # option -h  => Help

if ($opt_h) {
  system ("clear");
  die __('access_control_USAGE_MESSAGE');
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
  die "$msg3\n\n"; 
}


if (((defined $opt_r) and (defined $opt_s)) or ((defined $opt_u) and (defined $opt_s)) 
     or ((defined $opt_d) and (defined $opt_s)) or ((defined $opt_v) and (defined $opt_s)) or ((defined $opt_w) and (defined $opt_s)) or ((defined $opt_t) and (defined $opt_s))){
  my $msg1 = __("Parameter '-s' can be used only with '-p' parameter");   
  die "\n!!! $msg1 !!!\n\n"; 
}
elsif (($opt_r and $opt_v) or ($opt_u and $opt_v) or ($opt_d and $opt_v) or ($opt_w and $opt_v)){
  my $msg1 = __("Parameter '-v' can be used only with '-p' parameter");
  die "\n!!! $msg1 !!!\n\n"; 
}
elsif (($opt_r and $opt_t) or ($opt_u and $opt_t) or ($opt_d and $opt_t) or ($opt_v and $opt_t)){
  my $msg1 = __("Parameter '-t' can be used only with '-p' parameter");
  die "\n!!! $msg1 !!!\n\n"; 
}
elsif ($opt_d eq 'revoke' and $opt_r and $opt_u){
  $r_call =$opt_r;
  $u_call=$opt_u;
  $call_type ='revoke_role_from_user';
}
elsif ($opt_d eq 'user' and $opt_u ){
  $u_call=$opt_u;
  $call_type ='del_user';
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
elsif ($opt_r  or $opt_u or $opt_s or $opt_d or $opt_v or $opt_t or $opt_w){
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

Marek Imialek <marek@tzv.fal.de>

=cut
