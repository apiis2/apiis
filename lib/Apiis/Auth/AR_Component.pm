##############################################################################
# $Id: AR_Component.pm,v 1.11 2014/10/17 20:27:46 ulm Exp $
##############################################################################.
#package Apiis::Auth::AR_Component;
$VERSION = '$Revision: 1.11 $';
##############################################################################

=head1 NAME

Apiis::Auth::AR_Component

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

our $apiis;
our $admin_defined;
our $debug;
##############################################################################

=head2 create_role 

  This subroutine crates new role(s).

=cut

sub create_role{
  my $myroles = shift;
  my $system_user = $apiis->Model->db_user;
  my %new_roles;

 EXIT:{
   while ( my ($role,$parameters) =  each %$myroles){
     ### check if the role is existing in the database ###################################
     my $sql_chro = "SELECT role_id FROM $system_user.ar_roles WHERE role_name='$role'";
     my $sql_ref_chro  = $apiis->DataBase->sys_sql($sql_chro);
     if ($sql_ref_chro->status){
       $apiis->errors( $sql_ref_chro->errors );
       $apiis->status(1);
       last EXIT;
     }
     if ($sql_ref_chro->handle->rows){
       my $msg_1 = __("Role '[_1]' is existing in the database",$role);
#        $apiis->errors(
#           Apiis::Errors->new(
#             type      => 'DB',
#             severity  => 'INFO',
#             msg_short => $msg_1,
#           )
#        );
       print "\n!!! $msg_1" if ($debug>0);
       next;
     }
     ### end - check if the role is existing in the database ############################

     my (@mycolumns, @myvalues);
     push @mycolumns, "role_name";
     push @myvalues, $role;
     my ($role_policies,$role_type);
     while ( my ($parameter, $parameter_content) = each %$parameters){
       if ($parameter ne "role_policies"){
         push @mycolumns, $parameter;
         push @myvalues, $parameter_content;
         #$role_type = $parameter_content if ($parameter eq "role_type")
       }else{
         $role_policies = $parameter_content;
       }
     }
     push @mycolumns, "role_id";
     push @myvalues, $apiis->DataBase->seq_next_val('seq_ar_roles__role_id');
     push @mycolumns, "synch";

     if ($admin_defined){
       push @myvalues, "f";
       insert_record(\@mycolumns,\@myvalues,'ar_roles');
       if ($apiis->status){
         my $msg_2 = __("Role '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_role: $msg_2"); 
         print "\nER: $msg_2\n";
         last EXIT;
       }else{
         $new_roles{$myvalues[0]} =  ({TYPE => $myvalues[4], ROLE_POLICIES => $role_policies,});

         my $msg_3 = __("Role '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_role: $msg_3");
         print "\nOK: $msg_3" if ($debug>0); 
       }
     }else{
       push @myvalues, "f";
       my $system_user = $apiis->Model->db_user;
       my $last_change_user= $apiis->os_user;
       my $last_change_dt =scalar $apiis->extdate2iso($apiis->now);
       my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
       my $owner=$apiis->node_name;
       my $version=1;

       my $insvalues = "'$myvalues[0]','$myvalues[1]','$myvalues[2]','$myvalues[3]','$myvalues[4]','$myvalues[5]','$myvalues[6]','$last_change_dt','$last_change_user','$guid','$version','$owner'";
       my $sql = "INSERT INTO $system_user.ar_roles (".join (',',@mycolumns).",last_change_dt,last_change_user,guid,version,owner) VALUES ($insvalues)";
       my $sql_ref = query_db($sql);
       if ($sql_ref->status){
         my $msg_2 = __("Role '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_role: $msg_2"); 
         print "\nER: $msg_2\n";

         $apiis->errors( $sql_ref->errors );
         $apiis->status(1);
         last EXIT;
       }else{
#org         $new_roles{$myvalues[0]} =  ({TYPE => $myvalues[4], ROLE_POLICIES => $role_policies,});
         $new_roles{$myvalues[0]} =  ({TYPE => $parameters->{'role_type'}, ROLE_POLICIES => $parameters->{'role_policies'},});

         my $msg_3 = __("Role '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_role: $msg_3");
         print "\nOK: $msg_3" if ($debug>0); 
       }
     }
   }#while end
  }#EXIT
   if (!$apiis->status){
     my $msg_4 = __("Creating roles successfully finished");
     print "\nOK: $msg_4";
     if (%new_roles){
       my $msg_5 = __("New roles: ");
       print "\n    $msg_5"; 
       foreach (keys %new_roles){ print "$_, ";}
     }
   }else{
     my $msg_6 = __("Groups not created");
     print "\nER: $msg_6";
   }
   return \%new_roles;
}
##############################################################################

=head2 create_stpolicies 

  This subroutine crates new system task policies.

=cut

sub create_stpolicies{
  my ($mystpolicies,$new_roles) = @_;
  my $stp_already_defined=0;
  my @stp_defined;
  my $str_pol_from_nrole;

  foreach my $role (keys %$new_roles){
    if ($new_roles->{$role}{TYPE} eq "ST"){
      if ($str_pol_from_nrole){
        $str_pol_from_nrole = join (",", $str_pol_from_nrole,$new_roles->{$role}{ROLE_POLICIES});
      }else{
        $str_pol_from_nrole = $new_roles->{$role}{ROLE_POLICIES};
      }
    }
  }
  my @arr_pol_from_nrole = split ",",$str_pol_from_nrole if ($str_pol_from_nrole);
  ### get policies form the database ###
  my $sql = "SELECT stpolicy_id FROM ar_stpolicies";
  my $fetched = $apiis->DataBase->sys_sql($sql);
  $fetched->status;
  if ($fetched->status){
    $apiis->errors( $fetched->errors );
    $apiis->status(1);
    #$apiis->check_status;
    last EXIT;
  }
  my @policies_from_db;
  while (my $ret_val = $fetched->handle->fetch){
   push @policies_from_db, $ret_val->[0];
  }
 EXIT:{
   while ( my ($stpolicy_no,$stpolicy) =  each %$mystpolicies){
     next unless (grep /^$stpolicy_no$/, @arr_pol_from_nrole); 
     if (grep /^$stpolicy_no$/, @policies_from_db){ 
       $stp_already_defined=1;
       push @stp_defined, $stpolicy_no;
       my $msg_0 = __("System task policy '[_1]' already defined in the database",$stpolicy_no);
       $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_stpolicies: $msg_0");
       print "\n!!! $msg_0" if ($debug>1);  
       next;
     }
     ### policy not deinned yet ###
     my @stpolicy_element = split '\|',$stpolicy;
     my (@mycolumns, @myvalues);
     push @mycolumns, "stpolicy_id","stpolicy_name","stpolicy_type","synch";

     if ($admin_defined){
       push @myvalues, $stpolicy_no,$stpolicy_element[0],$stpolicy_element[1],"f";
       insert_record(\@mycolumns,\@myvalues,'ar_stpolicies');
       if ($apiis->status){
         my $msg_1 = __("System task policy '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_stpolicies: $msg_1"); 
         print "\nER: $msg_1\n";
         last EXIT;
       }else{
         my $msg_1 = __("System task policy '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_stpolicies: $msg_1");
         print "\nOK: $msg_1" if ($debug>1); 
       }
     }else{
       push @myvalues, $stpolicy_no,"'$stpolicy_element[0]'","'$stpolicy_element[1]'", "'f'";
       my $system_user = $apiis->Model->db_user;
       my $last_change_user= $apiis->os_user;
       my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
       my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
       my $owner=$apiis->node_name;
       my $version=1;

       my $insvalues ="'".$last_change_dt."','".$last_change_user."','".$guid."','".$version."','".$owner."'";
       my $sql = "INSERT INTO $system_user.ar_stpolicies (".join (',',@mycolumns).",last_change_dt,last_change_user,guid,version,owner) VALUES (".join (',',@myvalues).",$insvalues)";
       my $sql_ref = query_db($sql);

       if ($sql_ref->status){
         my $msg_1 = __("System task policy '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_stpolicies: $msg_1"); 
         print "\nER: $msg_1\n";
         $apiis->errors( $sql_ref->errors );
         $apiis->status(1);
         last EXIT;
       }else{
         my $msg_1 = __("System task policy '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_stpolicies: $msg_1");
         print "\nOK: $msg_1" if ($debug>1);
       }
     }
   }#while end
  }#EXIT
   if ($stp_already_defined){
     my $joined = join(',',@stp_defined);
     my $msg_2 = __("These system task polcies are already defined in the database");
     print "\n!!! $msg_2: $joined !!!\n" if ($debug>0);
   }
   if (!$apiis->status){
     if ($debug >0){
       my $msg_3 = __("Creating system task policies successfully finished");
       print "\nOK: $msg_3";
     }
   }else{
     my $msg_4 = __("System task policies not created");
     print "\nER: $msg_4";
   } 
   return;
}
##############################################################################

=head2 create_dbtpolicies 

  This subroutine adds database task policies.

=cut

sub create_dbtpolicies{
  my ($mydbtpolicies,$new_roles) = @_;
  my $dbtp_already_defined=0;
  my @dbtp_defined;
  my $system_user = $apiis->Model->db_user;
  my $last_change_user= $apiis->os_user;
  my $version=1;

 EXIT:{
 ### prepare tables definitions to insert ###
  # get tables form the database ###
  my $sql_t = "SELECT table_id FROM ar_dbttables";
  my $fetched_t = $apiis->DataBase->sys_sql($sql_t);
  $fetched_t->status;
  if ($fetched_t->status){
    $apiis->errors( $fetched_t->errors );
    $apiis->status(1);
    $apiis->check_status;
    last EXIT;
  }
  my @tables_from_db;
  while (my $ret_val = $fetched_t->handle->fetch){
   push @tables_from_db, $ret_val->[0];
  }

  foreach my $mytable (keys %{$mydbtpolicies->{TABLES}}){
    if (grep /^$mytable$/, @tables_from_db){
      my $msg_0 = __("Table '[_1]' already defined in the database",$mytable);
      $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_0");
      print "\n!!! $msg_0" if ($debug>1);  
      next;
    }
    my $dbthash_content = $mydbtpolicies->{TABLES}{$mytable};
    my (@mycolumns, @myvalues);
    my @dbtpolicy_element = split '\|',$dbthash_content;
    my $record_table = "ar_dbttables";
    push @mycolumns, "table_id","table_name","table_columns","synch";

    if ($admin_defined){
      push @myvalues, $mytable,$dbtpolicy_element[0],$dbtpolicy_element[1], "f";
      insert_record(\@mycolumns,\@myvalues,$record_table);
      if ($apiis->status){
         my $msg_1 = __("Database task policy '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_1"); 
         print "\nER: $msg_1\n";
         last EXIT;
       }else{
         my $msg_1 = __("Database task policy '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_1");
         print "\nOK: $msg_1" if ($debug>1); 
       }
    }else{
      push @myvalues, $mytable,"'$dbtpolicy_element[0]'","'$dbtpolicy_element[1]'","'f'";
      my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
      my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
      my $owner=$apiis->node_name;

      my $insvalues = "'$last_change_dt','$last_change_user','$guid','$version','$owner'";
      my $sql_1 = "INSERT INTO $system_user.$record_table (".join (',',@mycolumns).",last_change_dt,last_change_user,guid,version,owner) VALUES (".join (',',@myvalues).",$insvalues)";
      my $sql_ref_1 = query_db($sql_1);

      if ($sql_ref_1->status){
         my $msg_1 = __("Database task policy '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_1"); 
         print "\nER: $msg_1\n";
         $apiis->errors( $sql_ref_1->errors );
         $apiis->status(1);
         last EXIT;
       }else{
         my $msg_1 = __("Database task policy '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_1");
         print "\nOK: $msg_1" if ($debug>1);
       }
    }
  }
 ### end prepare tables definitions to insert ###

 ### prepare descriptor definitions to insert ###
  # get descriptors form the database ###
  my $sql_d = "SELECT descriptor_id FROM ar_dbtdescriptors";
  my $fetched_d = $apiis->DataBase->sys_sql($sql_d);
  $fetched_d->status;
  if ($fetched_d->status){
    $apiis->errors( $fetched_d->errors );
    $apiis->status(1);
    $apiis->check_status;
    last EXIT;
  }
  my @descriptors_from_db;
  while (my $ret_val = $fetched_d->handle->fetch){
   push @descriptors_from_db, $ret_val->[0];
  }

  foreach my $mydesc (keys %{$mydbtpolicies->{DESCRIPTORS}}){
    if (grep /^$mydesc$/, @descriptors_from_db){
      my $msg_0 = __("Descriptor '[_1]' already defined in the database",$mydesc);
      $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_0");
      print "\n!!! $msg_0" if ($debug>1);
      next;
    }
    my $dbthash_content = $mydbtpolicies->{DESCRIPTORS}{$mydesc};
    my (@mycolumns, @myvalues);
    my @dbtpolicy_element = split '\|',$dbthash_content;
    my $record_table = "ar_dbtdescriptors";
    push @mycolumns, "descriptor_id","descriptor_name","descriptor_value","synch";

    if ($admin_defined){
      push @myvalues, $mydesc,$dbtpolicy_element[0],$dbtpolicy_element[1],"f";
      insert_record(\@mycolumns,\@myvalues,$record_table);
      if ($apiis->status){
         my $msg_2 = __("Descriptor '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_2"); 
         print "\nER: $msg_2\n";
         last EXIT;
       }else{
         my $msg_2 = __("Descriptor '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_2");
         print "\nOK: $msg_2" if ($debug>1); 
       }
    }else{
      push @myvalues, $mydesc,"'$dbtpolicy_element[0]'","'$dbtpolicy_element[1]'", "'f'";
      my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
      my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
      my $owner=$apiis->node_name;

      my $insvalues = "'$last_change_dt','$last_change_user','$guid','$version','$owner'";
      my $sql_2 = "INSERT INTO $system_user.$record_table (".join (',',@mycolumns).",last_change_dt,last_change_user,guid,version,owner) VALUES (".join (',',@myvalues).",$insvalues)";
      my $sql_ref_2 = query_db($sql_2);

      if ($sql_ref_2->status){
         my $msg_2 = __("Descriptor '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_2"); 
         print "\nER: $msg_2\n";
         $apiis->errors( $sql_ref_2->errors );
         $apiis->status(1);
         last EXIT;
       }else{
         my $msg_2 = __("Descriptor '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_2");
         print "\nOK: $msg_2" if ($debug>1);
       }
    }
  }
 ### end prepare descriptor definitions to insert ###

 ### prepare policy definitions to insert ###
  #get policy number for the current roles
  my $str_pol_from_nrole;
  foreach my $role (keys %$new_roles){
    if ($new_roles->{$role}{TYPE} eq "DBT"){
      if ($str_pol_from_nrole){
        $str_pol_from_nrole = join (",", $str_pol_from_nrole,$new_roles->{$role}{ROLE_POLICIES});
      }else{
        $str_pol_from_nrole = $new_roles->{$role}{ROLE_POLICIES};
      }
    }
  }
  
  my @arr_pol_from_nrole = split ",",$str_pol_from_nrole if ($str_pol_from_nrole);
  # get policies form the database ###
  my $sql_3 = "SELECT dbtpolicy_id FROM ar_dbtpolicies";
  my $fetched_3 = $apiis->DataBase->sys_sql($sql_3);
  $fetched_3->status;
  if ($fetched_3->status){
    $apiis->errors( $fetched_3->errors );
    $apiis->status(1);
    $apiis->check_status;
    last EXIT;
  }
  my @policies_from_db;
  while (my $ret_val = $fetched_3->handle->fetch){
   push @policies_from_db, $ret_val->[0];
  }

  foreach my $mypoli (keys %{$mydbtpolicies->{POLICIES}}){
    next unless (grep /^$mypoli$/, @arr_pol_from_nrole); 
    if (grep /^$mypoli$/, @policies_from_db){ 
      $dbtp_already_defined=1;
      push @dbtp_defined, $mypoli; 
      my $msg_0 = __("Database task policy '[_1]' already defined in the database",$mypoli);
      $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_0");
      print "\n!!! $msg_0" if ($debug>1);  
      next;
    }
    my $dbthash_content = $mydbtpolicies->{POLICIES}{$mypoli};
    my (@mycolumns, @myvalues);
    my @dbtpolicy_element = split '\|',$dbthash_content;
    my $sql_4 = "SELECT db_code FROM codes WHERE ext_code ='".$dbtpolicy_element[0]."'";
    my $fetched_4 = query_db($sql_4);
    $fetched_4->status;
    if ($fetched_4->status){
      $apiis->errors( $fetched_4->errors );
      $apiis->status(1);
      last EXIT;
    }

    my $db_action = @{$fetched_4->handle->fetch}[0] ;
    my $record_table = "ar_dbtpolicies";
    push @mycolumns, "dbtpolicy_id","action_id","table_id","descriptor_id","synch";

    if ($admin_defined){
      push @myvalues, $mypoli,$dbtpolicy_element[0],$dbtpolicy_element[1],$dbtpolicy_element[2],"f";
      insert_record(\@mycolumns,\@myvalues,$record_table);
      if ($apiis->status){
         my $msg_3 = __("Database task policy '[_1]' not created",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_3"); 
         print "\nER: $msg_3\n";
         last EXIT;
       }else{
         my $msg_3 = __("Database task policy '[_1]' added in to the database",$myvalues[0]);
         $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_3");
         print "\nOK: $msg_3" if ($debug>1); 
       }
    }else{
      push @myvalues, $mypoli,$db_action,$dbtpolicy_element[1],$dbtpolicy_element[2],"f";
      my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
      my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
      my $owner=$apiis->node_name;

      my $insvalues = "'$myvalues[0]','$myvalues[1]','$myvalues[2]','$myvalues[3]','$myvalues[4]','$last_change_dt','$last_change_user','$guid','$version','$owner'";
      my $sql_5 = "INSERT INTO $system_user.$record_table (".join (',',@mycolumns).",last_change_dt,last_change_user,guid,version,owner) VALUES ($insvalues)";
      my $sql_ref_5 = query_db($sql_5);

      if ($sql_ref_5->status){
        my $msg_3 = __("Database task policy '[_1]' not created",$myvalues[0]);
        $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_3"); 
        print "\nER: $msg_3\n";
        $apiis->errors( $sql_ref_5->errors );
        $apiis->status(1);
        last EXIT;
      }else{
        my $msg_3 = __("Database task policy '[_1]' added in to the database",$myvalues[0]);
        $apiis->log( 'debug',"Apiis::Auth::AR_Component::create_dbtpolicies: $msg_3");
        print "\nOK: $msg_3" if ($debug>1);
      }
    }
  }
 ### end prepare descriptor definitions to insert ###
 }#EXIT
  if ($dbtp_already_defined){
     my $joined = join(',',@dbtp_defined);
     my $msg_4 = __("These database task polcies are already defined in the database");
     print "\n!!! $msg_4: $joined !!!\n" if ($debug>0);
   }
   if (!$apiis->status){
     if ($debug >0){
       my $msg_5 = __("Creating database task policies successfully finished");
       print "\nOK: $msg_5";
     }
   }else{
     my $msg_5 = __("Creating database task policies failed");
     print "\nER: $msg_5\n";
   }
   return;
}
##############################################################################

=head2 assign_roles

  This subroutine assigns role to the user.$from_interface parameter is used
  only if you want to call this subroutine from the interface and is needed to
  remove the standard print-outs.

=cut

sub assign_roles{
  my ($user_roles,$user_log,$from_interface)= @_;
  my $user_id;
  my @group_to_insert;
  my @assigned_roles;

 EXIT:{
  ### check user ###
  my $sql = "SELECT user_id FROM ar_users WHERE user_login ='$user_log'";
  my $fetched = $apiis->DataBase->sys_sql($sql);
  $fetched->status;
  if ($fetched->status){
    $apiis->errors( $fetched->errors );
    $apiis->status(1);
    last EXIT;
  }
  my $ret_user=  $fetched->handle->fetch;
  if ($ret_user){
   $user_id = $ret_user->[0];
  }else{
    my $msg = __("User '[_1]' is not existing in the database",$user_log);
    $apiis->status(1);
    $apiis->errors(
       Apiis::Errors->new(
          type      => 'DB',
          severity  => 'ERR',
          from      => 'Apiis::Auth::AR_Component::assign_role',
          msg_short => $msg,
       )
    );
    last EXIT;
  }
  ###check role ###
  foreach my $role_name (@$user_roles){
    my $grsql = "SELECT role_id FROM ar_roles WHERE role_name ='$role_name'";
    my $grfetched = $apiis->DataBase->sys_sql($grsql);
    $grfetched->status;
    if ($grfetched->status){
      $apiis->errors( $grfetched->errors );
      $apiis->status(1);
      last EXIT;
    }
    my $ret_role = $grfetched->handle->fetch;
    
    if ($ret_role){
      my $grussql = "SELECT guid FROM ar_user_roles WHERE role_id ='$ret_role->[0]' and user_id='$user_id'";
      my $grusfetched = $apiis->DataBase->sys_sql($grussql);
      $grusfetched->status;
      if ($grusfetched->status){
        $apiis->errors( $grusfetched->errors );
        $apiis->status(1);
        last EXIT;
      }
      my $ret_role_user = $grusfetched->handle->fetch;
      if ($ret_role_user){
        my $msg_1 = __("Role '[_1]' is already assigned to the user '[_2]'",$role_name,$user_log);
        print "\n!!! $msg_1" if (($debug>0) and (not defined $from_interface));
        next;
      }

      my (@mycolumns,@myvalues);
      push @mycolumns, "user_id","role_id","synch";
      push @myvalues, $user_id, $ret_role->[0];
      push @assigned_roles, $role_name;

      ### assign role to the user ###
      if ($admin_defined){
        push @myvalues, "f";
        insert_record(\@mycolumns,\@myvalues,'ar_user_roles');
        if ($apiis->status){
          my $msg_2 = __("Role '[_1]' not assigned to the user",$role_name);
          $apiis->log( 'debug',"Apiis::Auth::AR_Component::assign_role: $msg_2"); 
          print "\nER: $msg_2\n" if (not defined $from_interface);
          last EXIT;
        }else{
          my $msg_2 = __("Role '[_1]' assigned to the user",$role_name);
          $apiis->log( 'debug',"Apiis::Auth::AR_Component::assign_role: $msg_2");
          print "\nOK: $msg_2" if (($debug>0) and (not defined $from_interface)); 
        } 
      }else{
        push @myvalues, "f";
        my $system_user = $apiis->Model->db_user;
        my $last_change_user= $apiis->os_user;
        my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
        my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
        my $owner=$apiis->node_name;
        my $version=1;

        my $insvalues = "'$myvalues[0]','$myvalues[1]','$myvalues[2]','$last_change_dt','$last_change_user','$guid','$version','$owner'";
        my $sql = "INSERT INTO $system_user.ar_user_roles (".join (',',@mycolumns).",last_change_dt,last_change_user,guid,version,owner) VALUES ($insvalues)";
        my $sql_ref = query_db($sql);

        if ($sql_ref->status){
          my $msg_2 = __("Role '[_1]' not assigned to the user",$role_name);
          $apiis->log( 'debug',"Apiis::Auth::AR_Component::assign_role: $msg_2"); 
          print "\nER: $msg_2\n" if (not defined $from_interface);

          $apiis->errors( $sql_ref->errors );
          $apiis->status(1);
          last EXIT;
        }else{
          my $msg_2 = __("Role '[_1]' assigned to the user",$role_name);
          $apiis->log( 'debug',"Apiis::Auth::AR_Component::assign_role: $msg_2");
          print "\nOK: $msg_2" if (($debug>0) and (not defined $from_interface)); 
        }
      }
    }else{
      my $msg_3 = __("Role '[_1]' is not existing in the database",$role_name);
      $apiis->status(1);
      $apiis->errors(
         Apiis::Errors->new(
            type      => 'DB',
            severity  => 'ERR',
            from      => 'Apiis::Auth::AR_Component::assign_role',
            msg_short => $msg_3,
         )
      );
      last EXIT;
    }
  }
 }#EXIT
  if (!$apiis->status){
    my $msg_4 = __("Roles successfully assigned to the user '[_1]'",$user_log);
    print "\nOK: $msg_4" if (not defined $from_interface);
    if (@assigned_roles){
      if (not defined $from_interface){
        print "\n    Roles: " ;
        foreach (@assigned_roles){ print "$_, ";}
      }
    } 
  }else{
    my $msg_5 = __("Roles not assigned to the user");
    print "\nER: $msg_5: ".join (",",@assigned_roles) if (not defined $from_interface);
  }
  return;
}
##############################################################################

=head2 assign_policy 

  This subroutine assigns policies to the roles.

=cut

sub assign_policy{
  my ($new_roles,$from_interface) = @_;
  #my %roles = %$ret_roles;

 EXIT:{
   foreach my $myrole ( keys %$new_roles){
     my $ins_table;
     my @mycolumns;

     if ($new_roles->{$myrole}{TYPE} eq 'ST'){
           push @mycolumns, "role_id","stpolicy_id","synch"; 
           $ins_table = "ar_role_stpolicies";  
     }elsif ($new_roles->{$myrole}{TYPE} eq 'DBT'){
           push @mycolumns, "role_id","dbtpolicy_id","synch"; 
           $ins_table = "ar_role_dbtpolicies";  
     }else{
       my $msg_0 = __("Wrong role type ([_1]) defined for the role '[_2]'",$new_roles->{$myrole}{TYPE},$myrole);
       $apiis->status(1);
       $apiis->errors(
         Apiis::Errors->new(
           type      => 'DB',
           severity  => 'ERR',
           from      => 'Apiis::Auth::AR_Component::assign_policy',
           msg_short => $msg_0,
         )
       );
       last EXIT;
     }
     my @mypolicies = split ',',$new_roles->{$myrole}{ROLE_POLICIES};
     my $sql_1 = "SELECT role_id FROM ar_roles WHERE role_name ='$myrole'";
     my $fetched_1 = $apiis->DataBase->sys_sql($sql_1);
     $fetched_1->status;
     if ($fetched_1->status){
      $apiis->errors( $fetched_1->errors );
      $apiis->status(1);
      last EXIT;
     }
 
     my $ret_role = $fetched_1->handle->fetch;
     if ($ret_role){
       foreach my $policy_no (@mypolicies){
         my @myvalues;
         push @myvalues,$ret_role->[0],$policy_no;
         if ($admin_defined){
           push @myvalues, "f";
           insert_record(\@mycolumns,\@myvalues,$ins_table);
           if ($apiis->status){
             my $msg_1 = __("Policy '[_1]' not assigned to the role '[_2]'",$policy_no,$myrole);
             $apiis->log( 'debug',"Apiis::Auth::AR_Component::assign_policy: $msg_1"); 
             print "\nER: $msg_1\n" if (not defined $from_interface);
             last EXIT;
           }else{
             my $msg_1 = __("Policy '[_1]' assigned to the role '[_2]'",$policy_no,$myrole);
             $apiis->log( 'debug',"Apiis::Auth::AR_Component::assign_policy: $msg_1");
             print "\nOK: $msg_1" if ($debug>1 and not defined $from_interface); 
           }
         }else{
           push @myvalues, "f";
           my $system_user = $apiis->Model->db_user;
           my $last_change_user= $apiis->os_user;
           my $last_change_dt = scalar $apiis->extdate2iso($apiis->now);
           my $guid=$apiis->DataBase->seq_next_val('seq_database__guid');
           my $owner=$apiis->node_name;
           my $version=1;

           my $insvalues = "'$myvalues[0]','$myvalues[1]','$myvalues[2]','$last_change_dt','$last_change_user','$guid','$version','$owner'";
           my $sql = "INSERT INTO $system_user.$ins_table (".join (',',@mycolumns).",last_change_dt,last_change_user,guid,version,owner) VALUES ($insvalues)";
           my $sql_ref = query_db($sql);
           
           if ($sql_ref->status){
             my $msg_1 = __("Policy '[_1]' not assigned to the role '[_2]'",$policy_no,$myrole);
             $apiis->log( 'debug',"Apiis::Auth::AR_Component::assign_policy: $msg_1"); 
             print "\nER: $msg_1\n" if (not defined $from_interface);

             $apiis->errors( $sql_ref->errors );
             $apiis->status(1);
             last EXIT;
           }else{
             my $msg_1 = __("Policy '[_1]' assigned to the role '[_2]'",$policy_no,$myrole);
             $apiis->log( 'debug',"Apiis::Auth::AR_Component::assign_policy: $msg_1");
             print "\nOK: $msg_1" if ($debug>1 and not defined $from_interface); 
           }
         }
       }
     }else{
       my $msg_2 = __("Role '[_1]' is not existing in the database",$myrole);
       $apiis->status(1);
       $apiis->errors(
         Apiis::Errors->new(
           type      => 'DB',
           severity  => 'ERR',
           from      => 'Apiis::Auth::AR_Component::assign_policy',
           msg_short => $msg_2,
         )
       );
       last EXIT;
     }
   }##foreach role
 }#EXIT
  if (!$apiis->status){
    if ($debug>0){
      my $msg_3 = __("The policies successfully assigned to the roles: ");
      print "\nOK: $msg_3" if (not defined $from_interface);
    }
  }else{
    my $msg_4 = __("The policies not assigned to the roles");
    print "\nER: $msg_4" if (not defined $from_interface);
  }
  return;
}
##############################################################################
=head2 read_info_about_user_or_roles 

  this subroutine print information about users and roles which are curently defined in the system.

=cut

sub read_info_about_user_or_roles{
  my $call = shift;
  my $no_users=1;
  my $no_roles=1;
  my $system_user = $apiis->Model->db_user;

  if ($call eq 'users'){
    my $sql ="SELECT ar_users.user_id, user_login,user_language_id,user_marker,user_first_name,user_second_name,
              user_email,user_institution,user_country,user_street,user_town,user_zip,user_other_info 
              FROM ar_users,ar_users_data WHERE ar_users.user_id=ar_users_data.user_id";
    my $fetched_0  = query_db($sql);
    $fetched_0->status;
    if ($fetched_0->status){
      $apiis->errors( $fetched_0->errors );
      $apiis->status(1);
      last EXIT;
    }
    while(my @value = $fetched_0->handle->fetchrow_array()){
      $no_users=0;
      print "\n";
      print __("LOGIN:          [_1]",$value[1]);
      print "\n";
      print __("USER NAME:      [_1] [_2]",$value[4],$value[5]);
      print "\n";
      print __("USER MARKER:    [_1]",$value[3]);
      print "\n";
      print __("USER LANGUAGE:  [_1]",$value[2]);
      print "\n";
      if ($value[6]){
        print __("USER EMAIL:     [_1]",$value[6]);
        print "\n";}
      if ($value[7]){
        print __("INSTITUTION:    [_1]",$value[7]);
        print "\n";}
      if ($value[8]){
        print __("ADDRESS");
        if ($value[9]){
          print "\n";
          print __("  Street:         [_1]",$value[9]);
        }
        if ($value[10]){
          print "\n";
          print __("  Town:           [_1]",$value[10]);
        }
        if ($value[11]){
          print "\n";
          print __("  Zip:            [_1]",$value[11]);
        }
        if ($value[8]){
          print "\n";
          print __("  Country:        [_1]",$value[8]);
        }
        if ($value[6]){
          print "\n";
          print __("  Email:          [_1]",$value[6]);
          print "\n";
        }
      }
      print __("ASSIGNED ROLES:");
      my $sql_1 ="select role_id from ar_user_roles WHERE user_id=$value[0]";
      my $fetched_1  = query_db($sql_1);
      $fetched_1->status;
      if ($fetched_1->status){
         $apiis->errors( $fetched_1->errors );
         $apiis->status(1);
         last EXIT;
      }
      while(my @second_value = $fetched_1->handle->fetchrow_array()){
	my $sql_2 ="SELECT role_name FROM ar_roles WHERE role_id=$second_value[0]";
        my $fetched_2  = query_db($sql_2);
        $fetched_2->status;
        if ($fetched_2->status){
          $apiis->errors( $fetched_2->errors );
          $apiis->status(1);
          last EXIT;
        }
	
	while(my @third_value = $fetched_2->handle->fetchrow_array()){
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
    my $sql ="SELECT role_name,role_type,role_descr,role_subset FROM ar_roles";
    my $fetched_1  = query_db($sql);
      $fetched_1->status;
      if ($fetched_1->status){
         $apiis->errors( $fetched_1->errors );
         $apiis->status(1);
         last EXIT;
      }   
    while(my @value = $fetched_1->handle->fetchrow_array()){
      $no_roles=0;
      print "\n";
      print __("ROLE NAME:       [_1]",$value[0]);
      print "\n";
      print __("ROLE TYPE:       [_1]",$value[1]);
      print "\n";
      print __("ROLE DESCRIPTION:[_1]",$value[2]);
      print "\n";
      print __("ROLE SUBSET:     [_1]",$value[3]);
      print "\n\n";
    }
    if ($no_roles){
      print "\n!!! ";
      print __("No role definitions in the system");
      print "\n"; 
    }
  }
}


1;

__END__

=head1 AUTHOR

 Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut
