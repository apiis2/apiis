##############################################################################
# $Id: DatabaseTask.pm,v 1.10 2007-12-04 10:43:54 duchev Exp $
##############################################################################
package Apiis::Auth::AR_Auth::DatabaseTask;
$VERSION = '$Revision ';
##############################################################################

=head1 NAME

Apiis::Auth::Auth::DatabaseTask -- 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut

##############################################################################
use strict;
use warnings;
use Carp;
use Apiis::Init;
use Data::Dumper;
##############################################################################

=head2 _check_tables 

  execution: 
             1: $apiis->Auth->check_tables
             2: $apiis->Auth->check_tables('sql_action_name')
             3: $apiis->Auth->check_tables('sql_action_name','table_name') 		 
		  
=cut

sub _check_tables{
  my ($self,@args) = @_;
  my @dbt_list;

 EXIT:{
  unless ($self->_exists_dbt) {
    my $msg = __("Method can not be executed.");
    my $msg_long = __("Object Auth was not initialized for the database tasks.");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_check_tables',
        msg_short => $msg,
        msg_long  => $msg_long,
      )
    );
    last EXIT;
  }

  if ((not defined $args[0]) and (not defined $args[1])){
    my %tmp_list;
    while ( my ($dbt_action,$dbt_tables) =  each %{$self->{'_dbt_ar'}}){
      foreach (keys %{$dbt_tables}){
        push @{$tmp_list{$_}}, $dbt_action;
      }
    }
    push @dbt_list, \%tmp_list;
  }elsif ((defined $args[0]) and (not defined $args[1])){
    if ($self->{'_dbt_ar'}{$args[0]}){ 
      my @tmp_list;
      foreach (keys %{$self->{'_dbt_ar'}{$args[0]}}){
        push @dbt_list, $_;
      }
    }else{
      my $msg_sh = __("NO ACCESS RIGHTS");
      my $msg_ln = __("User '[_1]' can not execute sql action '[_2]' on any table.",$self->{'_object_user'},$args[0]);
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::Auth::DatabaseTask::_check_tables',
          msg_short => $msg_sh,
          msg_long  => $msg_ln,
        )
      );
      last EXIT; 
    }
  }elsif ((defined $args[0]) and (defined $args[1])){
    if ($self->{'_dbt_ar'}{$args[0]}{$args[1]}){ 
      @dbt_list = 1;
    }else{
      @dbt_list = 0;
      my $msg_sh = __("NO ACCESS RIGHTS");
      my $msg_ln = __("User '[_1]' can not execute sql action '[_2]' on table '[_3]'.",$self->{'_object_user'},$args[0],$args[1]);
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::Auth::DatabaseTask::_check_tables',
          msg_short => $msg_sh,
          msg_long  => $msg_ln,
        )
      );
      last EXIT; 
    }
  }
 }#EXIT
  return \@dbt_list;
}
##############################################################################

=head2 _check_columns 

  execution: 
             1: $apiis->Auth->check_columns
             2: $apiis->Auth->check_columns('sql_action_name')
             3: $apiis->Auth->check_columns('sql_action_name','table_name') 		 
		  
=cut

sub _check_columns{
  my ($self,@args) = @_;
  my @setofcolumns_list;
  my $column_status=1;

 EXIT:{
  unless ($self->_exists_dbt) {
    my $msg = __("Method can not be executed.");
    my $msg_long = __("Object Auth was not initialized for the database tasks.");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_check_columns',
        msg_short => $msg,
        msg_long  => $msg_long,
      )
    );
    last EXIT;
  }

  if ((not defined $args[0]) and (not defined $args[1])){
    my $msg_sh = __("MISSING PARAMETERS FOR THE METHOD");
    my $msg_ln = __("You have to set at list two parameters for this method: (SQL action and table name)");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_check_columns',
        msg_short => $msg_sh,
        msg_long  => $msg_ln,
      )
    );
    last EXIT; 
  }elsif ((defined $args[0]) and (defined $args[1]) and (not defined $args[2]) ){
    if ($self->{'_dbt_ar'}{$args[0]}{$args[1]}){ 
      foreach (keys %{$self->{'_dbt_ar'}{$args[0]}{$args[1]}}){
        push @setofcolumns_list, $_;
        $column_status=0;
      }
      if ($column_status){
        my $msg_sh = __("NO ACCESS RIGHTS");
        my $msg_ln = __("User '[_1]' has not access rights to any column from table '[_2]' for the action '[_3]'.",$self->{'_object_user'},$args[1],$args[0]);
        $self->status(1);
        $self->errors(
          Apiis::Errors->new(
            type      => 'AUTH',
            severity  => 'CRIT',
            from      => 'Apiis::Auth::Auth::DatabaseTask::_check_columns',
            msg_short => $msg_sh,
            msg_long  => $msg_ln,
          )
        );
        last EXIT; 
      }
    }else{
      my $msg_sh = __("NO ACCESS RIGHTS");
      my $msg_ln = __("User '[_1]' has not access rights to execute '[_2]' on table '[_3]'.",$self->{'_object_user'},$args[0],$args[1]);
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::Auth::check_columns',
          msg_short => $msg_sh,
          msg_long  => $msg_ln,
        )
      );
      last EXIT; 
    }
  }elsif ((defined $args[0]) and (defined $args[1]) and (defined $args[2]) ){
    if ($self->{'_dbt_ar'}{$args[0]}{$args[1]}){
      my $columns_to_check = $args[2];
      my @all_setofcolumns_list;
      foreach my $setofcolumns (keys %{$self->{'_dbt_ar'}{$args[0]}{$args[1]}}){ 
        my $setofcolumns_accepted = 1;
        EXIT_MYCOLUMN:{ 
          foreach my $mycolumn (@$columns_to_check){
            if (!($setofcolumns =~ /$mycolumn/)){
              $setofcolumns_accepted = 0;
              last EXIT_MYCOLUMN;
            }
          }
          push @setofcolumns_list, $setofcolumns;
        }#EXIT_MYCOLUMN
        push @all_setofcolumns_list, $setofcolumns;
      }
      if (not @setofcolumns_list){
        @setofcolumns_list = 0;
        my $error_columns = join (', ',@$columns_to_check);
        my $all_sets="";
        my $i=1;
        foreach (@all_setofcolumns_list){
          my $temp = "($i)".$_."\n"; 
          $all_sets = join("",$all_sets,$temp); 
          $i++;
        }
        my $msg_sh = __("NO ACCESS RIGHTS");
        my $msg_ln = __("User '[_1]' has not defined any set of columns for table '[_2]' 
                        and action '[_3]' which contains all this columns:
                        [_4]
                        For this table and action following sets of columns
                        are allowed:
                        [_5]",$self->{'_object_user'},$args[1],$args[0],$error_columns,$all_sets);
        $self->status(1);
        $self->errors(
          Apiis::Errors->new(
            type      => 'AUTH',
            severity  => 'CRIT',
            from      => 'Apiis::Auth::Auth::DatabaseTask::_check_columns',
            msg_short => $msg_sh,
            msg_long  => $msg_ln,
          )
        );
        last EXIT; 
      }
    }else{
      @setofcolumns_list = 0;
      my $msg_sh = __("NO ACCESS RIGHTS");
      my $msg_ln = __("User '[_1]' has not access rights to execute '[_2]' on table '[_3]'.",$self->{'_object_user'},$args[0],$args[1]);
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::Auth::check_columns',
          msg_short => $msg_sh,
          msg_long  => $msg_ln,
        )
      );
      last EXIT; 
    }
  } 
 }#EXIT
  return \@setofcolumns_list;
}
##############################################################################

=head2 _check_descriptors 

  execution: 
             1: $apiis->Auth->check_tables('sql_action_name','table_name','columns_set') 		 
		  
=cut

sub _check_descriptors{
  my ($self,@args) = @_;
  my @descriptor_list;
  my %descriptor_hash;

 EXIT:{
  unless ($self->_exists_dbt) {
    my $msg = __("Method can not be executed.");
    my $msg_long = __("Object Auth was not initialized for the database tasks.");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_check_descriptors',
        msg_short => $msg,
        msg_long  => $msg_long,
      )
    );
    last EXIT;
  }

  if ((defined $args[0]) and (defined $args[1]) and (defined $args[2])){
    if (lc $args[0] eq 'delete') {
      #special case DELETE - columns are not important
      if (exists $self->{'_dbt_ar'}{$args[0]} and 
	  exists $self->{'_dbt_ar'}{$args[0]}{$args[1]}
	 ) {
	foreach my $col_list (%{$self->{'_dbt_ar'}{$args[0]}{$args[1]}}) {
	  my @loc_descriptor_list = $self->{'_dbt_ar'}{$args[0]}{$args[1]}{$col_list};
	  push @descriptor_list, @loc_descriptor_list;
	}
      }
    } else {
      # all other actions
      if ($self->{'_dbt_ar'}{$args[0]}{$args[1]}{$args[2]}){
	@descriptor_list = $self->{'_dbt_ar'}{$args[0]}{$args[1]}{$args[2]};
      }
    }
    if (not @descriptor_list){
      @descriptor_list = 0;
      my $msg_sh = __("NO ACCESS RIGHTS");
      my $msg_ln = __("User '[_1]' has not defined any descriptor for action '[_2]', 
                         table '[_3]' and columns:
                         [_4]",$self->{'_object_user'},$args[0],$args[1],$args[2]);
      $self->status(1);
      $self->errors(
		    Apiis::Errors->new(
				       type      => 'AUTH',
				       severity  => 'CRIT',
				       from      => 'Apiis::Auth::Auth::DatabaseTask::_check_descriptors',
				       msg_short => $msg_sh,
				       msg_long  => $msg_ln,
				      )
		   );
      last EXIT; 
    }
    #order descriptors; if there are two the same descriptors then create one descriptor and value from these 
    #descriptors are put on the one list and assign to it in the hash. The value of each decriptor is always 
    #split by coma because it can be that the descriptor has defined list of values.  
    foreach my $single_list (@descriptor_list){
      foreach my $mydescriptor (@$single_list){
	my $myname = $mydescriptor->{'descriptor_name'};
	my $myvalue = $mydescriptor->{'descriptor_value'};
	my @myvalue_splitedby_coma = split ",",$myvalue;
	foreach my $finall_single_value (@myvalue_splitedby_coma){
	  push @{$descriptor_hash{$myname}},$finall_single_value unless (grep /^$finall_single_value$/, @{$descriptor_hash{$myname}});
	}
      }
    }
  }else{
    @descriptor_list = 0;
    my $msg_sh = __("MISSING PARAMETERS FOR THE METHOD");
    my $msg_ln = __("You have to set following parameters for this method: SQL action, table name and set of columns");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_check_descriptors',
        msg_short => $msg_sh,
        msg_long  => $msg_ln,
      )
    );
    last EXIT;
  }
 }#EXIT 
  return \%descriptor_hash;
}

##############################################################################

=head2 _descriptor_fulfiled 

  execution: 
             1: $apiis->Auth->_descriptor_fulfiled('sql_action_name','descriptor','array of descriptor values') 		 
		  
=cut

sub _descriptor_fulfiled{
  my ($self,@args) = @_;
  my $mystatus=0;
  my @broken_rules; 

  EXIT:{
  unless ($self->_exists_dbt) {
    my $msg = __("Method can not be executed.");
    my $msg_long = __("Object Auth was not initialized for the database tasks.");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_descriptor_fulfiled',
        msg_short => $msg,
        msg_long  => $msg_long,
      )
    );
    last EXIT;
  }

  if ((defined $args[0]) and (defined $args[1]) and (defined $args[2])){
    my $record_obj = $args[0];
    my $desc_name    = $args[1];
    my $desc_values  = $args[2];
    #my @record_seq = $record_obj->sequences;
    my @system_columns = qw / guid oid last_change_user last_change_dt version creation_dt creation_user opening_dt owner version/;

    if ($record_obj->action eq "insert"){
      if ((grep /^$desc_name$/, @system_columns) or ($desc_name eq $apiis->DataBase->rowid)){ # or (grep /^$desc_name$/, @record_seq) ){
        my $temp_rules = _check_system_columns($desc_name,\@{$desc_values});
        @broken_rules =@{$temp_rules};
      }else{#normal column
        my @inserted_value;
        if (defined $record_obj->column($desc_name)->extdata){
          @inserted_value = $record_obj->column($desc_name)->extdata;
        }else{
          my $msg = __("The value for the column '[_1]' is not defined in the sql statement 
                       (this column is also not defined on the system column list).",$desc_name);
          my $msg_long = __("This [_1] can be executed on table '[_2]' only if the column 
                            '[_3]' is also introduced through this statement. 
                            There are the following rules defined for the value of 
                            this column: [_4]",
                            $record_obj->action,$record_obj->name,$desc_name,join ',',@{$desc_values});
          $self->status(1);
          $self->errors(
            Apiis::Errors->new(
              type      => 'AUTH',
              severity  => 'CRIT',
              from      => 'Apiis::Auth::Auth::DatabaseTask::_descriptor_fulfiled',
              msg_short => $msg,
              msg_long  => $msg_long,
            )
          );
          last EXIT;
        }
        my ($rule_ok,$tmp_rules) = _check_broken_rules($inserted_value[0],\@{$desc_values});
        unless ($rule_ok){
          @broken_rules = @{$tmp_rules};
          my $msg = __("\nThe value which you want to insert into the column 
                       '[_1]' is -> [_2] ",$desc_name, $inserted_value[0] );
          push @broken_rules,$msg;
        } 
      }
    }elsif ($record_obj->action eq "update"){
      my @existing_value;
      if (defined $record_obj->column($desc_name)->intdata){
        @existing_value = $record_obj->column($desc_name)->intdata;
      }else{
        my $msg = __("There is no value for the column '[_1]' in the record which you want
                     to update.",$desc_name);
        my $msg_long = __("This [_1] can be executed on table '[_2]' only if the column 
                          '[_3]' has one of the following values:
                          [_4]",
                          $record_obj->action,$record_obj->name,$desc_name,join ',',@{$desc_values});
        $self->status(1);
        $self->errors(
          Apiis::Errors->new(
            type      => 'AUTH',
            severity  => 'CRIT',
            from      => 'Apiis::Auth::Auth::DatabaseTask::_descriptor_fulfiled',
            msg_short => $msg,
            msg_long  => $msg_long,
          )
        );
        last EXIT;
      }
      if ($desc_name eq "owner" and (grep /^\(=\)SELF_FILLER$/,@$desc_values)){ 
        unless ($existing_value[0] eq $apiis->User->user_marker){
          my ($rule_ok,$tmp_rules) = _check_broken_rules($existing_value[0],\@{$desc_values});
          unless ($rule_ok){
            @broken_rules = @{$tmp_rules};
            my $msg = __("\nThe current value which is existing in the column 
                         '[_1]' is -> [_2] ",$desc_name, $existing_value[0] );
            push @broken_rules,$msg;
          }
        }
      }else{
        my ($rule_ok,$tmp_rules) = _check_broken_rules($existing_value[0],\@{$desc_values});
        unless ($rule_ok){
          @broken_rules = @{$tmp_rules};
          my $msg = __("\nThe current value which is existing in the column 
                       '[_1]' is -> [_2] ",$desc_name, $existing_value[0] );
          push @broken_rules,$msg;
        }
      }   
    }elsif ($record_obj->action eq "delete"){
      my @existing_value;
      if (defined $record_obj->column($desc_name)->intdata){
        @existing_value = $record_obj->column($desc_name)->intdata;
      }else{
        my $msg = __("There is no value for the column '[_1]' in the record which you want
                     to delete.",$desc_name);
        my $msg_long = __("This [_1] can be executed on table '[_2]' only if the column 
                          '[_3]' has one of the following values:
                          [_4]",
                          $record_obj->action,$record_obj->name,$desc_name,join ',',@{$desc_values});
        $self->status(1);
        $self->errors(
          Apiis::Errors->new(
            type      => 'AUTH',
            severity  => 'CRIT',
            from      => 'Apiis::Auth::Auth::DatabaseTask::_descriptor_fulfiled',
            msg_short => $msg,
            msg_long  => $msg_long,
          )
        );
        last EXIT;
      }
      if ($desc_name eq "owner" and (grep /^\(=\)SELF_FILLER$/,@$desc_values)){ 
        unless ($existing_value[0] eq $apiis->User->user_marker){
          my ($rule_ok,$tmp_rules) = _check_broken_rules($existing_value[0],\@{$desc_values});
          unless ($rule_ok){
            @broken_rules = @{$tmp_rules};
            my $msg = __("\nThe current value which is existing in the column 
                         '[_1]' is -> [_2] ",$desc_name, $existing_value[0] );
            push @broken_rules,$msg;
          }
        }
      }else{
        my ($rule_ok,$tmp_rules) = _check_broken_rules($existing_value[0],\@{$desc_values});
        unless ($rule_ok){
          @broken_rules = @{$tmp_rules};
          my $msg = __("\nThe current value which is existing in the column 
                       '[_1]' is -> [_2] ",$desc_name, $existing_value[0] );
          push @broken_rules,$msg;
        }
      }   
    }else{
      my $msg = __("Comparision of the descriptor values with the record values can be executed for the insert, update and delete only.Current sql action is: '[_1]'",$record_obj->action);
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::Auth::DatabaseTask::_descriptor_fulfiled',
          msg_short => $msg,
        )
      );
      last EXIT;
    }

# print "sequence column\n",$apiis->DataBase->seq_next_val($sequence);

  }else{
    my $msg_sh = __("MISSING PARAMETERS FOR THE METHOD");
    my $msg_ln = __("You have to set following parameters for this method: SQL action, descriptor name and array of descriptor values");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_descriptor_fufiled',
        msg_short => $msg_sh,
        msg_long  => $msg_ln,
      )
    );
    last EXIT;
  }
 }#EXIT
 $mystatus=1 unless (@broken_rules); #descriptors not broken (fulfiled) if there is no any broken rule 
 return $mystatus,\@broken_rules;
}

##############################################################################


=head2 _check_broken_rules 

  execution: 
             1: $apiis->Auth->_check_broken_rules('introduced_value','array of column rules')
		  
=cut

sub _check_broken_rules{
  my @args = @_;
  my $introduced_value = $args[0];
  my @column_rules = @{$args[1]};
  my @br_rules;
  my $rule_founded=0;

EXIT:{
  foreach my $column_rule (@column_rules){
    $column_rule =~ m/(.*)\((.*)\)(.*)/;
    my $rule_value_1 = $1;
    my $rule_operator = $2;
    my $rule_value_2 = $3;
    if ($rule_operator eq "="){
      if ($rule_value_2 eq $introduced_value){
        $rule_founded=1;
        last EXIT;
      }else{
        push @br_rules, $column_rule;
      }  
    }elsif ($rule_operator eq ">"){
      if ($introduced_value > $rule_value_2 ){
        $rule_founded=1;
        last EXIT;
      }else{
        push @br_rules, $column_rule;
      }
    }elsif ($rule_operator eq "<"){
      if ($introduced_value < $rule_value_2 ){
        $rule_founded=1;
        last EXIT;
      }else{
        push @br_rules, $column_rule;
      }
    }elsif ($rule_operator eq "><"){
      if (($introduced_value > $rule_value_1) and ($introduced_value < $rule_value_2)){
        $rule_founded=1;
        last EXIT;
      }else{
        push @br_rules, $column_rule;
      } 
    }else{
      my $msg = __("Operator for the descriptor value '[_1]' wrong defined.",$column_rule);
      $apiis->Auth->status(1);
      $apiis->Auth->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::Auth::DatabaseTask::_check_broken_rules',
          msg_short => $msg,
        )
      );
      last EXIT;
    }
  }
 }#EXIT
 return $rule_founded,\@br_rules;
}
##############################################################################


=head2 _check_system_columns 

  execution: 
             1: $apiis->Auth->check_system_columns('column_name','array of column rules')
  
  TO DO: dates checking, sequnces checking 
		  		  		  		  
=cut

sub _check_system_columns{
  my @args = @_;
  my @system_column_rules;

 EXIT:{
   if ((defined $args[0]) and (defined $args[1])){
     my $mycolumn = $args[0];
     my $myrules  = $args[1];

     if ($mycolumn eq "owner"){
       #if we find SELF_FILLER string which is defined as one of the descriptor value, then the access rights
       #for this descriptor are not cheked. SELF_FILLER means that user has always access rights to insert data
       #with his user marker which is defined in ar_users table. In case of insert the owner column is always 
       #fill in with the user_marker value which is defined in ar_users table 

       if (!(grep /^\(=\)SELF_FILLER$/,@$myrules)){
         #value which will be inserted in to the owner column
         my $insert_owner = $apiis->User->user_marker;
         my ($rule_ok,$sys_rules) = _check_broken_rules($insert_owner,\@$myrules);
         unless ($rule_ok){
           @system_column_rules = @{$sys_rules};
           my $msg = __("\nThe value which will be insert into the column 
                       owner is -> [_1] ",$insert_owner );
           push @system_column_rules,$msg;
         }
       }
     }
     elsif ($mycolumn eq "last_change_user" or $mycolumn eq "creation_user" ){
       #value which will be inserted in to the last_change_user column
       my $insert_lchu = $apiis->User->id;
       my ($rule_ok,$sys_rules) = _check_broken_rules($insert_lchu,\@$myrules);
       unless ($rule_ok){
          @system_column_rules = @{$sys_rules};
          my $msg = __("\nThe value which will be insert into the column 
                       last_change_user is -> [_1] ",$insert_lchu );
          push @system_column_rules,$msg;
        }
     }
     elsif ($mycolumn eq $apiis->DataBase->rowid or $mycolumn eq "oid" or $mycolumn eq "guid" ){
       #value which will be inserted in to the rowid column (guid,oid)
       my $sql = "select last_value from seq_database__$mycolumn";
       my $sql_ref = $apiis->DataBase->sys_sql($sql);
       if ($sql_ref->status){
         $apiis->Auth->errors( $sql_ref->errors );
         $apiis->Auth->status(1);
         last EXIT;
       }
       my $ret_value = $sql_ref->handle->fetch;
       my $last_rowid = @{$ret_value}[0]; #new rowid will be always plus one
       my ($rule_ok,$sys_rules) = _check_broken_rules($last_rowid+1,\@$myrules);
       unless ($rule_ok){
          @system_column_rules = @{$sys_rules};
          my $msg = __("\nThe value which will be insert into the column 
                       rowid is -> [_1] ",$last_rowid+1 );
          push @system_column_rules,$msg;
        }
     }
     else{
       my $msg_sh = __("There are no procedures defined for the column '[_1]'. 
                       Ask implementer about new procedure for this column.",$mycolumn);
       $apiis->Auth->status(1);
       $apiis->Auth->errors(
         Apiis::Errors->new(
           type      => 'AUTH',
           severity  => 'CRIT',
           from      => 'Apiis::Auth::Auth::DatabaseTask::_check_system_columns',
           msg_short => $msg_sh,
         )
       );
       last EXIT;
     }
   }else{
     my $msg_sh = __("MISSING PARAMETERS FOR THE SUBROUTINE");
     my $msg_ln = __("You have to set following parameters for this subroutine: column name, array of column rules");
     $apiis->Auth->status(1);
     $apiis->Auth->errors(
       Apiis::Errors->new(
         type      => 'AUTH',
         severity  => 'CRIT',
         from      => 'Apiis::Auth::Auth::DatabaseTask::_check_system_columns',
         msg_short => $msg_sh,
         msg_long  => $msg_ln,
       )
     );
     last EXIT;
   }
 }#EXIT
 return \@system_column_rules;
} 
##############################################################################


=head2 _check_sql_statement 

  execution: 
             1: $apiis->Auth->check_sql_statement('sql_statement')
             2: $apiis->Auth->check_sql_statement()
		  
=cut

sub _check_sql_statement{
  my ($self,@args) = @_;
  my $access_rights=0;
  my @not_fulfiled_descriptors;

 EXIT:{
  unless ($self->_exists_dbt) {
    my $msg = __("Method can not be executed.");
    my $msg_long = __("Object Auth was not initialized for the database tasks.");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_check_sql_statement',
        msg_short => $msg,
        msg_long  => $msg_long,
      )
    );
    last EXIT;
  }

  if (not defined $args[0]){
    my $msg_sh = __("MISSING PARAMETER FOR THE METHOD");
    my $msg_ln = __("You have to set a parameter for this method (SQL statement).");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::DatabaseTask::_check_sql_statement',
        msg_short => $msg_sh,
        msg_long  => $msg_ln,
      )
    );
    last EXIT; 
  }elsif (defined $args[0]){
    my $record_obj = $args[0]; 
    my @system_columns = qw / guid oid last_change_user last_change_dt version 
                              creation_dt creation_user opening_dt owner version/;

    #### Get sql data from the record object ####
    my $sql_action = $record_obj->action;
    my $sql_table  = $record_obj->name;

    #### Check action and table ####
    $apiis->Auth->check_tables($sql_action,$sql_table); 
    last EXIT if $self->status;

    #### Creates array with columns from sql statement ####
    my (@sql_columns,@sql_column_values);
    foreach my $sql_column ($record_obj->columns){
      if ($sql_action eq 'update'){
        if (( $record_obj->column($sql_column)->updated()) and !(grep /^$sql_column$/, @system_columns)){
	  push @sql_columns, $sql_column;
        }
      }elsif (($sql_action eq 'insert')){ #or ($sql_action eq 'select')
        if (( (defined $record_obj->column($sql_column)->extdata) 
               or (defined $record_obj->column($sql_column)->intdata)
            ) and !(grep /^$sql_column$/, @system_columns)
           ){
	  push @sql_columns, $sql_column;
        } 
      }
    }

    if (@sql_columns){
      #### Check sql columns  ####
      my $allowed_setofcolumns = $apiis->Auth->check_columns($sql_action,$sql_table,\@sql_columns); 
      last EXIT if $self->status;
      #### Get descriptors for each set of columns  ####
      foreach (@$allowed_setofcolumns) {
        my $ret_tab = $apiis->Auth->check_descriptors($sql_action,$sql_table,$_);
	my $temp_rec=Apiis::DataBase::Record->new( tablename => $sql_table );
	if ($sql_action eq 'update') {
	  # special treatment - reading required values from the database
	  my @descriptor_names = keys %$ret_tab;
	  $temp_rec->column('guid')->extdata($record_obj->column('guid')->extdata());
	  $temp_rec->column('guid')->intdata($record_obj->column('guid')->intdata());
	  $temp_rec->action($sql_action);

	  my @query_records = $temp_rec->fetch(
					       expect_rows    => 'one',
					       expect_columns => @descriptor_names,
					      );
	  foreach my $rec (@query_records) {
	    $rec->decode_record;
	    foreach (@descriptor_names) {
	      $temp_rec->column($_)->extdata($rec->column($_)->extdata());
	      $temp_rec->column($_)->intdata($rec->column($_)->intdata());
	    }
	  }
	  $temp_rec->action($sql_action); #set back the action to delete
	}

        foreach my $descriptor_name (keys %$ret_tab){
          my @descriptor_values = @{$ret_tab->{$descriptor_name}};
          #### Check if the value of each returned descriptor 
          #### (for this set of columns) is fulifiled for the record
          my ($descriptor_status,$broken_rules);
	  if ($sql_action eq 'update') {
	    ($descriptor_status,$broken_rules) = 
	      $apiis->Auth->descriptor_fulfiled($temp_rec,$descriptor_name,\@descriptor_values);
	  } else {
	    ($descriptor_status,$broken_rules) = 
              $apiis->Auth->descriptor_fulfiled($record_obj,$descriptor_name,\@descriptor_values);
	  }
          last EXIT if $self->status;
	  if ($descriptor_status) {
	    #exit with success on first fulfilled descriptor (one policy match )
	    $access_rights=1;
	    $apiis->log('debug','Checking of access rights for the sql statement successfully finished');
	    last EXIT;
	  } else {
	    my $myrules = join ',',@{$broken_rules};
            push @not_fulfiled_descriptors," ".$descriptor_name.": ->$myrules<- ";
          }
        }
      }
    } else {
      #special case for Delete - no columns, but the descriptors have to be checked
      #in this case have to retrieve the descriptor columns from the database if they are not in the record already
      if ($sql_action eq 'delete'){
	my $ret_tab = $apiis->Auth->check_descriptors($sql_action,$sql_table,"");
	my @descriptor_names = keys %$ret_tab;
	
	if ($descriptor_names[0]) {
	  #at least one descriptor should be defined
	  
	  #do not trust what comes with the record object, but query the database
	  #and fill the values in temporary record

	  my $temp_rec=Apiis::DataBase::Record->new( tablename => $sql_table );
	  $temp_rec->column('guid')->extdata($record_obj->column('guid')->extdata());
	  $temp_rec->column('guid')->intdata($record_obj->column('guid')->intdata());
	  $temp_rec->action('delete');

	  my @query_records = $record_obj->fetch(
		 				 expect_rows    => 'one',
						 expect_columns => @descriptor_names,
						);
	  foreach my $rec (@query_records) {
	    $rec->decode_record;
	    foreach (@descriptor_names) {
	      $temp_rec->column($_)->extdata($rec->column($_)->extdata());
	      $temp_rec->column($_)->intdata($rec->column($_)->intdata());
	    }
	  }
	  
	  $record_obj->action('delete'); #set back the action to delete
	  foreach my $descriptor_name (@descriptor_names){
	    my @descriptor_values = @{$ret_tab->{$descriptor_name}};
	    #### Check if the value of each returned descriptor 
	    #### (for this set of columns) is fulfilled for the record
	    my ($descriptor_status,$broken_rules) = 
	      $apiis->Auth->descriptor_fulfiled($temp_rec,$descriptor_name,\@descriptor_values);
	    last EXIT if $self->status;
	    if ($descriptor_status) {
	      #exit with success on first fulfilled descriptor (one policy match )
	      $access_rights=1;
	      $apiis->log('debug','Checking of access rights for the sql statement successfully finished');
	      last EXIT;
	    } else {
	      my $myrules = join ',',@{$broken_rules};
	      push @not_fulfiled_descriptors," ".$descriptor_name.": ->$myrules<- ";
	    }
	  };
	} else {
	  $access_rights=0;
	  my $msg_sh = __("There are no descriptors to check. There should be at least one descriptor in delete policy");
	  $self->status(1);
	  $self->errors(
			Apiis::Errors->new(
					   type      => 'AUTH',
					   severity  => 'WARNING',
					   from      => 'Apiis::Auth::Auth::DatabaseTask::_check_sql_statement',
					   msg_short => $msg_sh,
					  )
		       );
	  last EXIT;
	}
      };
      #if sql_columns
      #$access_rights=0;
      # my $msg_sh = __("There are no sql columns to check (in case of update
      #              it can be that the value which you are introducing 
      #              are exactly the same like the values existing 
      #              in the database).");
      # $self->status(1);
      # $self->errors(
      #   Apiis::Errors->new(
      #     type      => 'AUTH',
      #     severity  => 'WARNING',
      #     from      => 'Apiis::Auth::Auth::DatabaseTask::_check_sql_statement',
      #     msg_short => $msg_sh,
      #   )
      # );
      #last EXIT;
    }

    if (@not_fulfiled_descriptors){
      $access_rights=0;
      my $desc_list = join ", \n",@not_fulfiled_descriptors;
      my $msg_sh = __("NO ACCESS RIGHTS");
      my $msg_ln = __("[_1] can not be executed because one of the following 
                      rules is not fulfiled for the column: 
                      [_2]",$sql_action,$desc_list);
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::Auth::DatabaseTask::_check_sql_statement',
          msg_short => $msg_sh,
          msg_long  => $msg_ln,
        )
      );
      last EXIT;
    }else{
      $access_rights=1;
      $apiis->log('debug','Checking of access rights for the sql statement successfully finished');
    }
  }#if args defined
 }#EXIT
  return $access_rights;
}
##############################################################################

1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

__END__

