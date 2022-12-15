##############################################################################
# $Id: AR_Common.pm,v 1.12 2021/05/27 19:55:02 ulf Exp $
##############################################################################.
#package Apiis::Auth::AR_Common;
$VERSION = '$Revision: 1.12 $';
##############################################################################

=head1 NAME

Apiis::Auth::AR_Common

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
use Apiis::Auth::AR_Batch;
use Apiis::Auth::AR_Component;
use Apiis::Auth::AR_User;
use Apiis::Auth::AR_View;
use Benchmark;

our $apiis;
our $admin_defined;
our $debug=0; #levels 0,1,2 
##############################################################################

=head2 access_rights

 this subroutine can be used to define access rights directly in the code without access_control.pl script

=cut

sub access_rights{
   my ($def_user,$user_role_names,$set_first_name,$set_second_name,$set_language,$set_user_marker,$set_password,$set_user_category)= @_;
   # start timer
   my $start_1 = new Benchmark if $debug>0;

 EXIT:{
   ### check if the administrator account is already defined ###
   check_users_table();
   #insert_codes();
   last EXIT if ($apiis->status);

   print "\n*************************************************************************";
   my ($user_id,$user_registered,$umarker) = create_user(lc $def_user,$set_first_name,
       $set_second_name,$set_language,$set_user_marker,$set_password,$set_user_category); 

   my $msg_1 = __("CREATING SCHEMA FOR THE USER '[_1]'",$def_user);
   print "\n>>> $msg_1" if ($debug>0);
   unless ($apiis->status or $user_registered){ create_schema(lc $def_user)};
   last EXIT if ($apiis->status);

   my ($user_roles,$user_stpol,$user_dbtpol,$stpnotget,$dbtpnotget) = collect_roles(\@$user_role_names);
   last EXIT if ($apiis->status);

   my $msg_3 = __("CREATING ROLES"); 
   print "\n>>> $msg_3";
   my $new_roles = create_role(\%$user_roles);
   last EXIT if ($apiis->status);
   $apiis->DataBase->dbh->commit;

   my $msg_4 = __("CREATING SYSTEM TASK POLICIES"); 
   print "\n>>> $msg_4" if ($debug>0);
   create_stpolicies(\%$user_stpol,\%$new_roles) unless $stpnotget;
   last EXIT if ($apiis->status);

   my $msg_5 = __("CREATING DATABASE TASK POLICIES"); 
   print "\n>>> $msg_5" if ($debug>0);
   create_dbtpolicies(\%$user_dbtpol,\%$new_roles) unless $dbtpnotget;
   last EXIT if ($apiis->status);

   my $msg_6 = __("ASSIGNING POLICIES TO THE ROLES"); 
   print "\n>>> $msg_6" if ($debug>0);
   assign_policy(\%$new_roles);
   last EXIT if ($apiis->status);

   $apiis->check_status;
   if ($apiis->status){
     $apiis->DataBase->dbh->rollback;
   }else {
     $apiis->DataBase->dbh->commit;
   }

   my $msg_8 = __("ASSIGNING ROLES TO THE USERS"); 
   print "\n>>> $msg_8";
   assign_roles(\@$user_role_names,lc $def_user);
   last EXIT if ($apiis->status);

   my $msg_9 = __("CREATING ACCESS VIEW FOR THE DATABASE TASKS");
   print "\n>>> $msg_9";
   create_dbt_access_view(lc $def_user);
   last EXIT if ($apiis->status);

   my $msg_10 = __("CREATING ACCESS VIEW FOR THE SYSTEM TASKS");
   print "\n>>> $msg_10";
   create_st_access_view(lc $def_user);
   last EXIT if ($apiis->status);

   my $msg_11 = __("CREATING VIEWS FOR TABLES IN THE USER SCHEMA");
   print "\n>>> $msg_11";   

   table_views(lc $def_user,$umarker);
   last EXIT if ($apiis->status);

   my $msg_12 = __("CREATING ENTRY VIEWS IN THE USER SCHEMA");
   print "\n>>> $msg_12";   

   entry_views(lc $def_user);
   last EXIT if ($apiis->status);
   $apiis->DataBase->dbh->commit;

   my $msg_13 = __("CREATING V_ VIEWS IN THE USER SCHEMA");
   print "\n>>> $msg_13";   

   v_views(lc $def_user);
   last EXIT if ($apiis->status);
 };
   $apiis->check_status;
   if ($apiis->status){
     $apiis->DataBase->dbh->rollback;
   }else {
     $apiis->DataBase->dbh->commit;
   }

   if ($debug>0){
     #end timer
     my $end_1 = new Benchmark;
     #calculate difference
     my $diff_1 = timediff($end_1, $start_1);
     #report
     print "\nCREATING ACCOUNT: Time taken was ", timestr($diff_1, 'all'), " seconds\n";
   }
   exit(0) if ($apiis->status);
}
##############################################################################

=head2 check_users_table

  This subroutine checks if there are any record in the users table. If the
  table is empty (administrator account is not defined yet) then all inserts 
  go through the sys_sql. If there is at list one record (this means that the 
  administrator account is already defined) then all DML go through the user_sql. 
  The global value "admin_defined" is set depending on result.
=cut

sub check_users_table{

 EXIT:{ 
   my $system_user = $apiis->Model->db_user;
   my $sql = "SELECT user_id FROM $system_user.ar_users";
   my $sql_ref = $apiis->DataBase->sys_sql($sql);
   if ($sql_ref->status){
     $apiis->errors( $sql_ref->errors );
     $apiis->status(1);
     last EXIT;
   }
   my $row_no = $sql_ref->handle->rows;
   if ($row_no){ 
     $admin_defined = 1;
     $apiis->log( 'debug',"Apiis::Auth::checking_users_table: Administrator account already defined, all SQL go through the user_sql");
   }else{
     $admin_defined = 0;
     $apiis->log( 'debug',"Apiis::Auth::checking_users_table: Administrator account not defined, all SQL go through the sys_sql");
   }
 }#EXIT
}
##############################################################################

=head2 insert_record 

  This subroutine insert the records  through the metalayer  

=cut

sub insert_record {
  my ($columns,$values,$table) = @_;
  my $i=0;

  my $record = Apiis::DataBase::Record->new( tablename => $table,);
  $record->check_status;
  foreach my $rec_column (@$columns){
  #print "\n".$rec_column." = ".@$values[$i]."\n";
    if ($rec_column =~ /db_unit/ or $rec_column =~ /db_code/ ){
      $record->column($rec_column)->intdata(@$values[$i]);
      $i++;
    }else{
      $record->column($rec_column)->extdata(@$values[$i]);
      $i++;
    }
  }
  #$apiis->log_priority('');
  $record->insert();
  #$apiis->log_priority('notice');
  if ($record->status ){
    $apiis->errors( $record->errors );   
    $apiis->status(1);
  }
  return;
}
##############################################################################

=head2 insert_codes 

  This subroutine insert the codes for the sql action names  

=cut

sub insert_codes{
  my @codes = qw(insert update delete select);
  my @mycolumns = qw(db_code ext_code class short_name synch);

 EXIT:{
  foreach my $code (@codes){
    my $system_user = $apiis->Model->db_user;
    my $last_change_user= $apiis->os_user;
    my $last_change_dt =scalar $apiis->extdate2iso($apiis->now);
    my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
    my $version=1;
    my $owner=$apiis->node_name;
    my $db_code = $apiis->DataBase->seq_next_val('seq_codes__db_code');
    my @myvalues;

    push @myvalues,"$db_code","$code","SQLACTION","$code","n";
    my $insvalues = "'$myvalues[0]','$myvalues[1]','$myvalues[2]','$myvalues[3]','$myvalues[4]','$last_change_dt','$last_change_user','$guid','$version','$owner'";
    my $sql = "INSERT INTO $system_user.codes (".join (',',@mycolumns).",last_change_dt,last_change_user,guid,version,owner) VALUES ($insvalues)";
    my $sql_ref = query_db($sql);
    $sql_ref->status;
    if ($sql_ref->status){
      $apiis->log( 'debug',"Apiis::Auth::AR_Common::insert_codes: Code $code not added in to the database");  
      $apiis->errors( $sql_ref->errors );
      $apiis->status(1);
      last EXIT;
    }else{
      $apiis->log( 'debug',"Apiis::Auth::AR_Common::insert_codes: Code $code added in to the database");  
    }
  }
 }#EXIT
  return;
} 
##############################################################################

=head2 query_db
  
  This subroutine executs SQL statements through the user_sql or sys_sql.
  The choice is dependend on the admin_defined value status.
=cut
 
 sub query_db {
  my $sql=shift;
  my $sql_ref;
  
   if ($admin_defined){
     #print "User SQL";
     $sql_ref = $apiis->DataBase->user_sql($sql);
   }else{
     #print "Sys SQL";
     $sql_ref = $apiis->DataBase->sys_sql($sql);
  }
  return $sql_ref;
} 
##############################################################################
1;

__END__

=head1 AUTHOR

 Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut
