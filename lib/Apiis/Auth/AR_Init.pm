##############################################################################
# $Id: AR_Init.pm,v 1.3 2014/10/17 20:27:46 ulm Exp $
 $VERSION = '$Revision: 1.3 $';
##############################################################################

=head1 NAME

AR_Init

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
use Data::Dumper;
use Apiis::Auth::AR_Common;
##############################################################################

sub create_other_accounts{
  my $user_language = $apiis->language;
  my $user_marker = $apiis->node_name;
  my @groups_an = qw (anonymous_dbt);
  access_rights('anonymous',\@groups_an,'Gemrman','anonymous user',$user_language,"$user_marker","pass");

  my @demo_groups = qw (coordinator_dbt);
  access_rights('coordinator',\@demo_groups,'Breeds', 'Coordinator',$user_language,"$user_marker","pass");
  
  print "\n*************************************************************************\n"
}
##############################################################################

=head2 access_rights_ar_batch

  This subroutine creates configuration file with the initial access rights 
  definition which is used in the runall proccess. Created file is also used by
  the access_control.pl.
=cut

sub access_rights_ar_batch{

   ### CONFIGURATION SECTION ### 
   #Definition of the system tables# 
   my @system_tables = qw/ar_constraints ar_dbtdescriptors ar_dbtpolicies ar_dbttables 
                       ar_role_constraints ar_role_dbtpolicies ar_user_roles ar_role_stpolicies ar_roles 
                       ar_stpolicies ar_users ar_users_data nodes sources 
                       targets/;

  #Definition of Roles#
  my @roles;
  #         ="ROLE ROLE NAME|ROLE LONG NAME|ROLE_TYPE(ST or DBT)|ROLE_SUBSET (OTHER ROLE NAMES)|ROLE DESCRIPTION"
  $roles[0]="ROLE administrator_scripts|executing administrator scripts|ST||This role gives a possibility to execute access control scripts";
  $roles[1]="ROLE insert_breed_data|inserting breed data|DBT|update_breed_data|The role gives a permissions for inserting data into the breed tables.";
  $roles[2]="ROLE update_breed_data|updating breed data|DBT|delete_breed_data|The role gives a permissions for updating data in the breed tables.";
  $roles[3]="ROLE delete_breed_data|deleting breed data|DBT|delete_sys_data|The role gives a permissions for inserting data from the breed tables.";
  $roles[4]="ROLE select_breed_data|selecting breed data|DBT||The role gives a permissions for selecting data from the breed tables.";
  $roles[5]="ROLE insert_sys_data|inserting sys data|DBT||The role gives a permissions for inserting data into the system tables (access rights and synchronization table).";
  $roles[6]="ROLE update_sys_data|updating sys data|DBT||The role gives a permissions for updating data in the system tables (access rights and synchronization table).";
  $roles[7]="ROLE delete_sys_data|deleting sys data|DBT|delete_breed_data|The role gives a permissions for deleting data from the system tables (access rights and synchronization table).";
  $roles[8]="ROLE select_sys_data|selecting sys data|DBT||The role gives a permissions for selecting data from the system tables (access rights and synchronization table).";
  $roles[9]="ROLE administrator_dbt|database administrator|DBT|insert_breed_data,update_breed_data,delete_breed_data,select_breed_data,insert_sys_data,update_sys_data,delete_sys_data,select_sys_data|The role gives a permissions for executing all sql actions on the all tables.";
  $roles[10]="ROLE coordinator_dbt|database coordinator|DBT|insert_breed_data,update_breed_data,delete_breed_data,select_breed_data|The role gives a permissions for executing all sql actions on the breed tables.";
  $roles[11]="ROLE anonymous_dbt|database anonymous user|DBT|select_breed_data,insert_breed_data|The role gives a permissions for selecting all breed data from the database.";
  $roles[12]="ROLE arm_anonymous|arm anonymous|ST||anonymous actions for the web access rights manager";
  $roles[13]="ROLE arm_admin|arm admin|ST||admin actions for the web access rights manager";
  #Descriptor definitions#
  my $user_marker = $apiis->node_name;
  my @descriptors;
  #              ="COLUMN_NAME|COLUMN VALUES"
  $descriptors[0]="owner|(=)$user_marker";

  #System Task definitions#
  my @system_task_policies;
  $system_task_policies[0]="access_rights_manager.pl|program";
  $system_task_policies[1]="show info about users or roles|action";
  $system_task_policies[2]="create public views|action";
  $system_task_policies[3]="add new user|action";
  $system_task_policies[4]="add new role|action";
  $system_task_policies[5]="grant role to the user|action";
  $system_task_policies[6]="delete role|action";
  $system_task_policies[7]="delete user|action";
  $system_task_policies[8]="revoke role from the user|action";
  $system_task_policies[9]="documentation|www";
  $system_task_policies[10]="logout|www";
  $system_task_policies[11]="help|www";
  $system_task_policies[12]="access_rights_manager tool|form";
  $system_task_policies[13]="arm|www";

  #Policy definitions for the system task roles#
  my %st_policy_no_hash = (
           administrator_scripts => "1,2,3,4,5,6,7,8,9",
           arm_anonymous         => "10,12",
           arm_admin             => "10,11,12,13,14",
  );
  ### CONFIGURATION SECTION END ### 

  ### OPENING FILE ###
  my $APIIS_LOCAL=$apiis->APIIS_LOCAL;
  if ( -e "$APIIS_LOCAL/etc/AR_Batch.conf") {
    `mv $APIIS_LOCAL/etc/AR_Batch.conf $APIIS_LOCAL/etc/AR_Batch.conf.bak`;
    print "$APIIS_LOCAL/etc/AR_Batch.conf moved to $APIIS_LOCAL/etc/AR_Batch.conf.bak \n";
  }
  open(LOG, ">$APIIS_LOCAL/etc/AR_Batch.conf") or
  die "cannot write to $APIIS_LOCAL/AR_Batch.conf $!\n";
  ### OPENING FILE ###

  my ($policies_to_printout,$dbt_policy_no_hash) = ar_batch_define_dbtpolicies(\@descriptors,\@system_tables);

  print LOG "################################################\n";
  print LOG "######## ROLE DEFINITIONS ######################\n";
  print LOG "################################################\n"; 
  ar_batch_define_role(\@roles,\%$dbt_policy_no_hash,\%st_policy_no_hash);

  print LOG "################################################\n";
  print LOG "######## SYSTM TASK DEFINITIONS ################\n";
  print LOG "################################################\n";
  ar_batch_print_stpolicies(\@system_task_policies);

  print LOG "################################################\n";
  print LOG "######## DATABASE TASK DEFINITIONS #############\n";
  print LOG "################################################\n";
  ar_batch_print_dbtpolicies(\@$policies_to_printout);

}
##############################################################################

=head2 ar_batch_define_role

  This subroutine define all roles which are specified in the configuration
  section.

=cut

sub ar_batch_define_role{
   my ($roles,$dbt_hash,$st_hash) = @_;

   foreach my $role_def (@$roles){
     my @single_role = split /\|/, $role_def;
     my $lab=$single_role[0];
     my $role_ln = $single_role[1];
     my $role_type = $single_role[2];
     my $role_subset = $single_role[3];
     my $role_descr = $single_role[4];
     ar_batch_print_roles($lab,$role_ln,$role_type,$role_descr,$role_subset,\%$dbt_hash,\%$st_hash);
   }
}
##############################################################################

=head2 ar_batch_print_roles

  This subroutine prints role definitions to the file.

=cut

sub ar_batch_print_roles{
   my ($label,$long_name,$role_type,$role_desc,$role_subset,$dbt_hash,$st_hash) = @_;
  
   print LOG "[$label]\n";
   print LOG "ROLE_LONG_NAME=$long_name\n";
   print LOG "ROLE_TYPE=$role_type\n";
   print LOG "ROLE_DESCR=$role_desc\n";
   print LOG "ROLE_SUBSET=$role_subset\n";
   print LOG "ROLE_POLICIES=";
   $label =~ s/(.*ROLE )(.*)$/$2/;

   if ($role_type eq 'DBT'){
     print LOG join(',',@{$dbt_hash->{$label}}) if (defined $dbt_hash->{$label});
   
   }else{
     print LOG join(',',$st_hash->{$label}) if (defined $st_hash->{$label});
   }
   print LOG "\n\n";
}
##############################################################################

=head2 ar_batch_print_stpolicies

  This subroutine prints policies for the system tasks

=cut

sub ar_batch_print_stpolicies{
   my $system_task_policies = shift;
   my $l=1;

   print LOG "[SYSTEM_TASK POLICIES]\n";
   foreach (@$system_task_policies){
     my @single_stpolicy = split /\|/, $_;
     print LOG "$l=$single_stpolicy[0]|$single_stpolicy[1]\n";
     $l++; 
   }
   print LOG "\n";
}
##############################################################################

=head2 ar_batch_define_dbtpolicies

  This subroutine define policies for the database tasks

=cut

sub ar_batch_define_dbtpolicies{
   my ($descriptors,$system_tables) = @_;
   my $dbtpolicies;
   my @policies_to_printout;
   my ($role_hash,$ret_policies_to_printout);
   
   my $tabhead = "[DATABASE_TASK TABLES]\n\n";
   push @policies_to_printout,$tabhead; 

      my $temp_pol_no;
      my @actions = qw( select modify );
      my @tab = @{$apiis->Model->tables};
      ($temp_pol_no,$dbtpolicies,$role_hash,$ret_policies_to_printout)=ar_batch_print_tables(\@tab,\@actions,\@policies_to_printout,\@$descriptors,\@$system_tables);

    my $k=1;
    my $deschead = "\n[DATABASE_TASK DESCRIPTORS]\n#The format: descriptor_id=descriptor_name|(descriptor_operator which can be defined as:=,>,<,<>)descriptor_value\n";
    push @policies_to_printout,$deschead;
    foreach my $descriptor (@$descriptors){
      my $print_desc = "$k=$descriptor\n";
      push @policies_to_printout,$print_desc;
      $k++; 
    }
    my $dbpolhead ="\n[DATABASE_TASK POLICIES]\n#The format: dbtpolicy_id=db_actions|db_table|db_descriptor\n";
    push @policies_to_printout,$dbpolhead;
    foreach my $row (@{$dbtpolicies}){
      my $print_dbtpolicies = "$row";
      push @policies_to_printout,$print_dbtpolicies;
    }
  #}

  return \@$ret_policies_to_printout,\%$role_hash;
}
##############################################################################

=head2 ar_batch_print_tables

  This subroutine crerates definition for all tables which ar deined in the modelfile.

=cut

sub ar_batch_print_tables {

   my ($tables,$actions,$policies_to_printout,$descriptors,$system_tables) = @_;
   my @basic_policies;
   my @table_names;
   my $policies_no;
   my $counter=0;
   my $counter1;
   my @dbt_policies;
   my $dbtpolicy_counter=1;
   my $i=1;

   #Arrays where the policies for the corespondend roles are stored#
   my (@insert_sys_data,@update_sys_data,@delete_sys_data,@select_sys_data,
       @insert_breed_data,@update_breed_data,@delete_breed_data,@select_breed_data);

   foreach my $artable (@{$tables} ){ 
      my $table = $apiis->Model->table($artable );
      my $tabname = $table->name;
      $counter1=0;

      foreach my $action (@{$actions}){
	 my $column_names;
	 if ($apiis->DataBase->rowid eq "oid" and $action eq 'select'){
	   $column_names='|oid';
	 }else{  
	   $column_names='';
	 }

	 foreach my $column (@{$table->cols}){
	   if($column eq 'last_change_dt' or $column eq 'last_change_user'
	      or $column eq 'dirty' or $column eq 'chk_lvl' or $column eq 'guid'
	      or $column eq 'owner' or $column eq 'version' or $column eq 'creation_dt'
              or $column eq 'creation_user' or $column eq 'end_dt' or $column eq 'end_user'){
	
 	      $column_names= join('|',$column_names,$column) if ($action eq 'select');
	   }else{
              $column_names= join('|',$column_names,$column); 
           }
	 }

	 $column_names= join('',$column_names,'|');
	 my %tmp_hash =(
                        ACTION  => $action,
			TABLE   => $tabname,
			COLUMNS => $column_names,
		       );
	 push @basic_policies, \%tmp_hash;
	 $counter1++;
     }
     $counter++;
   }
 foreach my $insert(@basic_policies){


       my $act = $insert->{ACTION};
       my $tab = $insert->{TABLE};
       my $col = $insert->{COLUMNS};
       unless  (grep /^$tab$/, @table_names){
	 push @table_names, $tab;
         my $dbt_policy_header = "##### TABLE \"$tab\" #####\n";		
         push @dbt_policies,$dbt_policy_header;
         push @$policies_to_printout,$dbt_policy_header; 
       }

       ### preaparing the policy combinations #######
       my $table_id; 
       my $m=1;
       foreach (@$descriptors){
         my $mydescriptor=$_;
         $mydescriptor =~ s/(.*\|\(=\))(.*)$/$2/; 
         if ($act eq 'select'){
           my $dbtpolicy="$dbtpolicy_counter=$act|$i|$m\n";
           if (grep /^$tab$/,@$system_tables){
             push @select_sys_data,$dbtpolicy_counter;
             push @dbt_policies, $dbtpolicy;
             $dbtpolicy_counter++;
           }else{
             push @select_breed_data,$dbtpolicy_counter;
             push @dbt_policies, $dbtpolicy;
             $dbtpolicy_counter++;
           }
         }else{
           #INSERT#
           my $dbtpolicy_1="$dbtpolicy_counter=insert|$i|$m\n";
           if (grep /^$tab$/,@$system_tables){
             push @insert_sys_data,$dbtpolicy_counter;
             push @dbt_policies, $dbtpolicy_1;
             $dbtpolicy_counter++;
           }else{
             push @insert_breed_data,$dbtpolicy_counter;
             push @dbt_policies, $dbtpolicy_1;
             $dbtpolicy_counter++;
           }
           #UPDATE#
           my $dbtpolicy_2="$dbtpolicy_counter=update|$i|$m\n";
           if (grep /^$tab$/,@$system_tables){
             push @update_sys_data,$dbtpolicy_counter;
             push @dbt_policies, $dbtpolicy_2;
             $dbtpolicy_counter++;
           }else{
             push @update_breed_data,$dbtpolicy_counter;
             push @dbt_policies, $dbtpolicy_2;
             $dbtpolicy_counter++;
           }
           #DELETE#
           my $dbtpolicy_3="$dbtpolicy_counter=delete|$i|$m\n";
           if (grep /^$tab$/,@$system_tables){
             push @delete_sys_data,$dbtpolicy_counter;
             push @dbt_policies, $dbtpolicy_3;
             $dbtpolicy_counter++; 
           }else{
             push @delete_breed_data,$dbtpolicy_counter;
             push @dbt_policies, $dbtpolicy_3;
             $dbtpolicy_counter++; 
           }
         } 
         $m++;
       }
       #PRINT TABLE AND THEIR COLUMNS#
       my @printab = split /\|/, $col;
       my $printcol = join (',',@printab);
       $printcol =~ s/^,(.*)/$1/;
       my $finallpolicy = "$i=$tab|$printcol\n";
       push @$policies_to_printout,$finallpolicy; 
       $i++;
     }
  #our $i;
#}
  my %hash= (
      insert_sys_data => \@insert_sys_data,
      update_sys_data => \@update_sys_data,
      delete_sys_data => \@delete_sys_data,
      select_sys_data => \@select_sys_data,
      insert_breed_data => \@insert_breed_data,
      update_breed_data => \@update_breed_data,
      delete_breed_data => \@delete_breed_data,
      select_breed_data => \@select_breed_data,
  );
 
return $policies_no, \@dbt_policies, \%hash, \@$policies_to_printout;
}
##############################################################################

=head2 ar_batch_print_dbtpolicies

  This subroutine prints policies for the system tasks

=cut


sub ar_batch_print_dbtpolicies{
  my $policies_to_printout = shift;
  
  foreach (@$policies_to_printout){
    print LOG $_;
  }
  return;
}
##############################################################################
1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

__END__
