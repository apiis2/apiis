=head1 NAME

apiis_alib_new

=head1 DESCRIPTION

Keeps the subroutines used in loading the data in the meta-level

=cut

=head2 meta_db

   meta_db is a wrapper which gets as

   input:
           1. a reference to an array of pseudo sql statements which must be strings
              without (!) variable interpolation!
           2. a reference to a hash with the data as values and the variable names
              (without dollar char $) as key

   This input is sql is parsed via PseudoStatement object where the parameters are extracted
   and a data structure is built.
   If no errors occur, the  PseudoStatement object is passed for execution to one of the four subroutines: ExecutePseudoSelect, ExecutePseudoInsert, ExecutePseudoUpdate and ExecutePseudoDelete

   output: hash_reference with fix keys 'err_status', 'err_ref', 'data_ret', 'records_affected'
           1. status (0 in case of success, >0 in case of trouble - the number of error objects)
           2. reference to an array of error objects, if any.
           3. reference to an hash with the returns of select statements
                                     column_name => value  (see LO_DS03)
           4. reference to an hash with the number of affected records
                                     pseudosql_statement=>number_of_affected_records

=cut
use Apiis::Misc qw( mychomp );


sub meta_db {
  use Apiis::DataBase::SQL::PseudoStatement;

  my ( $pseudo_sql_ref, $data_hash_ref ) = @_;
  my @all_errors;
  my %data_hash_ret=();
  my $data_ret;
  my %affected_records=();
 LOOP: {
  foreach  $pseudosql (@{$pseudo_sql_ref}) {
    my $affected_rows;
    $apiis->log('debug','meta_db: Current SQL: '.$pseudosql);
    next unless (defined $pseudosql); #allows inconsecutive PseudoSQL numbering in LO
    next if ($pseudosql eq '');
    my  $statement = Apiis::DataBase::SQL::PseudoStatement->new(
							pseudosql     => $pseudosql,
							data_hash     => $data_hash_ref
							     );
    if ($statement->status) {
      foreach ($statement->errors) {
	push @all_errors, $_;
      }
      last LOOP;
    };
    $apiis->log( 'debug', sprintf 'meta_db: statement object created for statement %s.',$pseudosql );
    if ($statement->actionname eq "SELECT") {
      ($data_ret,$affected_rows)=ExecutePseudoSelect($statement);
    } elsif ($statement->actionname eq "INSERT") {
      $affected_rows=ExecutePseudoInsert($statement);
    } elsif ($statement->actionname eq "UPDATE") {
      $affected_rows=ExecutePseudoUpdate($statement);
    } elsif ($statement->actionname eq "DELETE") {
      $affected_rows=ExecutePseudoDelete($statement);
    }
    $affected_records{$pseudosql}=$affected_rows;
    if ($statement->status) {
      foreach ($statement->errors) {
	push @all_errors, $_;
      }
      last LOOP;
    };
    $apiis->log( 'debug', sprintf 'meta_db: statement %s successfully executed %s records affected.',$pseudosql, $affected_rows );
    %data_hash_ret = ( %data_hash_ret, %{$data_ret} );
  }
}
  $hash_ref{ err_status } = scalar @all_errors;
  $hash_ref{ err_ref } = \@all_errors;
  $hash_ref{ data_ret } = \%data_hash_ret;
  $hash_ref{ records_affected} = \%affected_records;
  return ( \%hash_ref );
}


=head2 ExecutePseudoInsert

   ExecutePseudoInsert - inserts a record in the database

   input: PseudoStatement object

   output: inserted records count

=cut

sub ExecutePseudoInsert {
  use Apiis::DataBase::Record;
  my $statement=shift;
  my $record = Apiis::DataBase::Record->new(
					    tablename => $statement->tablename,
					   );
  if ($record->status) {
    foreach ($record->errors) {
      $statement->status(1);
      $statement->errors($_);
    }
    return;
  }
  $apiis->log( 'debug', sprintf 'ExecutePseudoInsert: record object created for table %s.',$record->tablename );
  my @column_names=$statement->columns();
  $apiis->log( 'debug', sprintf 'ExecutePseudoInsert: column names parsed from the statement %s.',join(',',@column_names) );
  my @column_values=$statement->values();
  eval {
    for($i=0;$i<@column_names;$i++) {
      if((defined $column_values[$i]) and ($column_values[$i] ne 'NULL')) {
	$record->column($column_names[$i])->extdata($column_values[$i]);
	my $sep=${ $apiis->reserved_strings }{v_concat};
	$record->column($column_names[$i])->extdata(split($sep,$column_values[$i])) if ($column_values[$i]=~/$sep/);
      } else {
	$record->column($column_names[$i])->extdata(undef);
      }
      if ( $apiis->Model->table($statement->tablename)->primarykey('ref_col') eq $column_names[$i]) {
	$record->column($column_names[$i])->intdata($column_values[$i]);
	$record->column($column_names[$i])->encoded(1);
      }
    }
  };
  if ($@) {
    $apiis->log( 'debug', sprintf 'ExecutePseudoInsert: code error for column %s %s.', $column_names[$i],$@ );
    $statement->status(1);
    $statement->errors(Apiis::Errors->new( type        => 'CODE',
					   severity    => 'ERR',
					   from        => 'ExecutePseudoInsert',
					   msg_short   => "$@",
					   msg_long    => "$@"
                                    )
		      );
    return;
  }
  $record->insert();
  if ($record->status) {
    foreach ($record->errors) {
      next unless (defined $_);
      $statement->status(1);
      $_->ext_fields($statement->column_extfields($_->db_column)) if (defined $_->db_column);
      $statement->errors($_);
    }
    return;
  }
  my $inserted_rows=$record->rows;
  return $inserted_rows;
}


=head2 ExecutePseudoUpdate

   ExecutePseudoUpdate - updates zero, one or more  records in the database

   input: PseudoStatement object

   output: updated records count

=cut

sub ExecutePseudoUpdate {
  use Apiis::DataBase::Record;
  my $statement=shift;
  my $updated_rows=0;

  my  $record_fake = Apiis::DataBase::Record->new(
						  tablename => $statement->tablename
						 );
  if ($record_fake->status) {
    foreach ($record_fake->errors) {
      $statement->status(1);
      $statement->errors($_);
    }
    return;
  }
  $apiis->log( 'debug', sprintf 'ExecutePseudoUpdate: record object created for table %s.',$record_fake->tablename );
  my $retrieve_cols = join(',', $record_fake->columns);
  my $sqlselect=sprintf "SELECT %s,%s FROM %s  WHERE %s",$apiis->DataBase->rowid,$retrieve_cols,$statement->tablename,$statement->whereclause;

  my $sql_ref=$apiis->DataBase->sys_sql($sqlselect);

  if ($sql_ref->status) {
    foreach ($sql_ref->errors) {
      $statement->status(1);
      $statement->errors($_);
    }
    return;
  }
  my @data_array=();
  my $count=0;
  while (my $arr_ref = $sql_ref->handle->fetch) {
    my @tmp=@{$arr_ref};
    push  @data_array, \@tmp;
    $count++;
  }
  unless($count==1) {
    #$statement->status(1);
      $apiis->log( 'info', sprintf 'ExecutePseudoUpdate: %s does not return any records',$sqlselect ) if ($count==0);
      $apiis->log( 'info', sprintf 'ExecutePseudoUpdate: %s does return more than one record',$sqlselect ) if ($count!=1);
      if ($count==0) {
	$statement->errors(Apiis::Errors->new( type        => 'DATA',
					       severity    => 'INFO',
					       action      => 'SELECT',
					       from        => 'ExecutePseudoUpdate',
					       msg_short   => "No matching records found",
					       msg_long    => "This statement return no records: ($sqlselect)"
					     )
			  );
      } else {
	$statement->errors(Apiis::Errors->new( type        => 'DATA',
					       severity    => 'INFO',
					       action      => 'SELECT',
					       from        => 'ExecutePseudoUpdate',
					       msg_short   => "More than one record match",
					       msg_long    => "This statement return more than one record: ($sqlselect)"
					     )
			  );
      }
  };
  foreach my $data_array (@data_array) {
    my  $record = Apiis::DataBase::Record->new(
					       tablename => $statement->tablename
					      );
    if ($record->status) {
      foreach ($record->errors) {
	$statement->status(1);
	$statement->errors($_);
      }
      return;
    }
    $apiis->log( 'debug', sprintf 'ExecutePseudoInsert: record object created for table %s from the statements tablename.',$statement->tablename );
    $record->column($apiis->DataBase->rowid)->extdata($$data_array[0]);
    my @record_column_names=$record->columns;
    my $i=1;
    foreach (@record_column_names) {
      if (defined $$data_array[$i]) { 
	$record->column($_)->intdata($$data_array[$i]);
      } else {
	$record->column($_)->intdata(undef);
      }
      $record->column($_)->encoded(1);					   
      $i++;
    }
    my @column_names=$statement->columns();
    $apiis->log( 'debug', sprintf 'ExecutePseudoUpdate: column names parsed from the statement %s.',join(',',@column_names) );
    my @column_values=$statement->values();
    eval {
      for($i=0;$i<@column_names;$i++) {
	if ((defined $column_values[$i]) and ($column_values[$i] ne 'NULL')) {
	  $record->column($column_names[$i])->extdata($column_values[$i]);
	  my $sep=${ $apiis->reserved_strings }{v_concat};
	  $record->column($column_names[$i])->extdata(split($sep,$column_values[$i])) if ($column_values[$i]=~/$sep/);
	} else {
	  $record->column($column_names[$i])->extdata(undef);
	}
	$record->column($column_names[$i])->updated(1);
	$record->column($column_names[$i])->encoded(0);
      }
    };
    if ($@) {
      $apiis->log( 'debug', sprintf 'ExecutePseudoUpdate: code error %s.',$@ );
      $statement->status(1);
      $statement->errors(Apiis::Errors->new( type        => 'CODE',
					     severity    => 'ERR',
					     from        => 'ExecutePseudoUpdate',
					     msg_short   => "$@",
					     msg_long    => "$@"
					   )
			);
      return;
    }
    $record->update();
    if ($record->status) {
      foreach ($record->errors) {
	next unless (defined $_);
	$statement->status(1);
	#print STDERR $_->sprint;
	$_->ext_fields($statement->column_extfields($_->db_column)) if (defined $_->db_column);
	$statement->errors($_);
      }
      return;
    }
    $updated_rows+=$record->rows;
  }
  return $updated_rows;
}


=head2 ExecutePseudoDelete

   ExecutePseudoDelete - deletes zero, one or more  records in the database

   input: PseudoStatement object

   output: deleted records count

=cut

sub ExecutePseudoDelete {
  use Apiis::DataBase::Record;
  my $statement=shift;
 
  my  $record = Apiis::DataBase::Record->new(
					     tablename => $statement->tablename
					    );

  if ($record->status) {
    foreach ($record->errors) {
      $statement->status(1);
      $statement->errors($_);
    }
    return;
  }
  $apiis->log( 'debug', sprintf 'ExecutePseudoDelete: record object created for table %s.',$record->tablename );
 my $sqlselect=sprintf "SELECT %s FROM %s  WHERE %s",$apiis->DataBase->rowid,$statement->tablename,$statement->whereclause;

  my $sql_ref=$apiis->DataBase->sys_sql($sqlselect);

  if ($sql_ref->status) {
    foreach ($sql_ref->errors) {
      $statement->status(1);
      $statement->errors($_);
    }
    return;
  }
  my @data_array=();
  while (my $arr_ref = $sql_ref->handle->fetch) {
    push @data_array,${$arr_ref}[0];
  }
  if(@data_array>1) {
#    $statement->status(1);
    $statement->errors(Apiis::Errors->new( type        => 'DATA',
					   severity    => 'INFO',
					   action      => 'SELECT',
					   from        => 'ExecutePseudoDelete',
					   msg_short   => "More than one record match",
					   msg_long    => "This statement return more than one record: ($sqlselect)"
                                    )
		      );
  };
  my $deleted_rows=0;
  foreach $oid (@data_array) {
    $record->column($apiis->DataBase->rowid)->extdata($oid);
    $record->column($apiis->DataBase->rowid)->intdata($oid);
    $record->delete();
    if ($record->status) {
      foreach ($record->errors) {
	next unless (defined $_);
	$statement->status(1);
	$_->ext_fields($statement->column_extfields($_->db_column)) if (defined $_->db_column);
	$statement->errors($_);
      }
      return;
    }
    $deleted_rows+=$record->rows;
  }
  return $deleted_rows;
}


=head2 ExecutePseudoSelect

   ExecutePseudoSelect - selects columns from only one! record in the database

   input: PseudoStatement object

   output: reference to hash with returned data, selected records count (should be 1)

=cut

sub ExecutePseudoSelect {
  use Apiis::DataBase::Record;
  my %ret_data;
  my $statement=shift;
  
  my $retrieve_cols = join(',', $statement->columns);
  my $sqlselect=sprintf "SELECT %s,%s FROM %s  WHERE %s",$apiis->DataBase->rowid,$retrieve_cols,$statement->tablename,$statement->whereclause;
  my $sql_ref=$apiis->DataBase->sys_sql($sqlselect);

  if ($sql_ref->status) {
      $statement->status(1);
      $statement->errors($sql_ref->errors);
      return;
  }
  my $arr_ref;
  my @data_array=();
  my $count=0;
  while ($arr_ref = $sql_ref->handle->fetch) {
    push  @data_array,@{$arr_ref} unless ($count);
    $count++;
  }
  unless($count==1) {
    $statement->status(1);
    if ($count==0) {
      $statement->errors(Apiis::Errors->new( type        => 'DATA',
					     severity    => 'ERR',
					     action      => 'SELECT',
					     from        => 'ExecutePseudoSelect',
					     msg_short   => "No matching records found",
					     msg_long    => "This statement return no records: ($sqlselect)"
					   )
			);
    } else {
      $statement->errors(Apiis::Errors->new( type        => 'DATA',
					     severity    => 'ERR',
					     action      => 'SELECT',
					     from        => 'ExecutePseudoSelect',
					     msg_short   => "More than one record match",
					     msg_long    => "This statement return more than one record: ($sqlselect)"
					   )
			);      
    }
    return;
  };
  my $i=1;
  my @column_names=$statement->columns;
  foreach (@column_names) {
      $ret_data{$_}=$data_array[$i];
      $i++;
    }
  return (\%ret_data, $count);
}



=head2 Process_LO_Batch

   Process_LO_Batch is invoked from DS0x.pm. It:

       - creates the input hash for the LoadObject
       - calls the LO
       - does the post processing of the errors (INSPOOL_ERR)

   input: DataStream object

=cut

sub Process_LO_Batch {
   my $ds = shift;

   my @data     = @{ $ds->data };
   my @LO_keys  = @{ $ds->LO_keys };
   my $ext_unit = $ds->ext_unit;
   my ( $err_status, $err_ref, $tnow );

   $ds->records_total($ds->records_total+1);

   # build the hash for parameter passing:
   my %data_hash;
   for ( my $i = 0 ; $i <= $#data ; $i++ ) {
      $data_hash{ $LO_keys[$i] } = $data[$i];
   }

   # ext_unit should be part of the data hash:
   $data_hash{ext_unit} = $ds->ext_unit;

   # call load object:
   my $load_object = 'LO_' . $ds->ds;
   my $load_string = "use $load_object";
   eval $load_string;
   if ($@) {
     $ds->status(1);
     $ds->errors(
		   Apiis::Errors->new(
				      type      => 'CODE',
				      severity  => 'ERR',
				      from      => 'Process_LO_Batch',
				      msg_short => 'Cannot find/load LoadObject $load_object',
				      msg_long  => $@,
				     )
		);
     $ds->records_error($ds->records_error+1);
     $err_status++;
     last DS_EXIT;
   }

   ( $err_status, $err_ref ) = &$load_object( \%data_hash )
     unless $err_status;

   # error handling
   if ($err_status) {
     $ds->records_error($ds->records_error+1);
      # first catch ERR errors which don't depend on one record:
      foreach my $this_err_obj ( @{$err_ref} ) {
         if ( $this_err_obj->type eq 'CODE'
            and $this_err_obj->severity eq 'ERR' )
         {
            $this_err_obj->from( 'Process_LO_Batch::' . $this_err_obj->from );
            $this_err_obj->print('STDERR') if $ds->debug > 0;
	    $ds->status(1);
	    $ds->errors($this_err_obj);
            last DS_EXIT;
         } else {
            $this_err_obj->record_id( $ds->record_seq )
              unless $this_err_obj->record_id;
            $this_err_obj->misc1( $ds->target_column )
              if defined $ds->target_column
              and not $this_err_obj->misc1;
            $this_err_obj->ds( $ds->ds )
              if defined $ds->ds
              and not $this_err_obj->ds;
            $this_err_obj->unit( $ds->ext_unit )
              if defined $ds->ext_unit
              and not $this_err_obj->unit;
#            $this_err_obj->ext_fields(  @{ $ds_conf_ref->{ext_cols} } ) )
#	      if $ds_conf_ref->{ext_cols} and not $this_err_obj->ext_cols;
         }
      }

      # flag inspool record as erroneous:
      $tnow=$apiis->extdate2iso($apiis->now);
      $ds->sth_update_inspool->execute( 'ERR',
         $ds->job_start, $tnow, $apiis->User->id, $ds->record_seq );

      $ds->dbh->commit unless $ds->debug > 4;

      foreach my $this_err_obj ( @{$err_ref} ) {
         $this_err_obj->print if $ds->debug > 0;

         # record_seq, err_type, action, dbtable, dbcol, err_source, short_msg,
         # long_msg, ext_col, ext_val, mod_val, comp_val, target_col, ds,
         # ext_unit, status, err_dt, last_change_dt, last_change_user, dirty
         my $this_ext_cols = join ( ' ', @{ $this_err_obj->ext_fields } )
           if $this_err_obj->ext_fields;
	 $tnow=$apiis->extdate2iso($apiis->now);
         $ds->sth_inspool_err->execute(
            $this_err_obj->record_id,
            $this_err_obj->type,
            $this_err_obj->action,
            $this_err_obj->db_table,
            $this_err_obj->db_column,
            $this_err_obj->from,
            $this_err_obj->msg_short,
            $this_err_obj->msg_long,
            $this_ext_cols,
            undef,    # before: $data[$i],
            $this_err_obj->data,
            undef,
            $this_err_obj->misc1,
            $ds->ds,
            $ds->ext_unit,
            'A', $tnow, $tnow, $apiis->User->id, undef,$apiis->DataBase->seq_next_val('seq_database__guid')
         );
         $ds->dbh->commit unless $ds->debug > 4;
         undef $this_err_obj;
      }
   } else {
      $ds->records_ok($ds->records_ok+1);
      local $ds->dbh->{RaiseError} = 1
        unless $ds->dbh->{RaiseError};
      eval {
	 $tnow=$apiis->extdate2iso($apiis->now);
         $ds->sth_update_inspool->execute( 'OK',
            $ds->job_start, $tnow, $apiis->User->id,
            $ds->record_seq );
         $ds->dbh->commit unless $ds->debug > 4;
      };
      if ($@) {
	$ds->status(1);
	$ds->errors( 
		    Apiis::Errors->new(
				       type      => 'DB',
				       severity  => 'ERR',
				       from      => 'Process_LO_Batch',
				       msg_short => $@,
				       msg_long  => $@
				      )
		)
       #probably this will duplicate some errors 
      }
   }
}


=head2 CheckLO

   CheckLO checks if passed hash has all keys from @LO_keys:

   input: hash reference to data, array of LO_keys

   output: status (0 in case of success, >0 in case of trouble - the number of error objects)
           reference to array of error objects

=cut

sub CheckLO {
   my ( $hash_ref, $names_ref ) = @_;
   my @error_objects=();
   # check if passed hash has all keys from @LO_keys:
   foreach my $thiskey ( @$names_ref ){
      unless ( exists $hash_ref->{$thiskey} ) {
         my $err = Apiis::Errors->new(
            type      => 'CODE',
            severity  => 'ERR',
            action    => 'UNKNOWN',
            from      => 'CheckLO',
            msg_short => 'Programming error, please contact the APIIS development team.',
            msg_long  => 'Programming error in passing parameters to LoadObject: '
                         . "key '$thiskey' is missing in data hash.",
         );
         push @error_objects, $err;
      } else {
#         ConnectDB() unless defined $dbh;
      }
   }
   return ( scalar @error_objects, \@error_objects );
}


=head2 get_language_id

   get_language_id - returns internal database id of an language 2 letters ISO-code

   input: language ISO code (i.e. 'DE', 'BG')

   output: status
           reference to array of error objects
           internal database lang_id

=cut

sub get_language_id {
  my $lang=shift;
  my $sqltext= sprintf "SELECT lang_id from languages where iso_lang = '%s'", $lang;
  my $sql_ref=$apiis->DataBase->sys_sql($sqltext);
  my $errors =$sql_ref->errors;
  if ($sql_ref->status) {
    return($sql_ref->status,$errors,undef);
  };
  my $result=$sql_ref->handle->fetch;

  return($sql_ref->status,$errors,$$result[0]);
}


=head2 file2inspool

   file2inspool - load files from the inspool folder into INSPOOL table in the database

   input: inspool folder name

   output: status of the load process 0 if successfull, -1 otherwise

=cut

sub file2inspool {
  my $inspool_dir = shift;
  my $save_dir    = $inspool_dir."/done";
  my ($ds, $ext_unit);
eval {
  ######################################################################
  # reading files from inspool directory:
  my ( $file, @files );
  opendir(SPOOL, $inspool_dir) or die __("Problems opening directory"), $inspool_dir, ": $!\n";
  while ( defined( $file = readdir(SPOOL) ) ) {
    next if $file =~ /^\.\.?$/;	# skip . and ..
    next unless $file =~ /^DS[0-9]+/i; # only read DS-files
    next if -z $file;		# file has zero size
    push @files, $file;
  }
  ######################################################################
  
  # database preparations:
  $dbh=$apiis->DataBase->sys_dbh;
  $now=$apiis->extdate2iso($apiis->now);
  $user=$apiis->os_user;
  $owner=$apiis->node_name;
  
  # INSPOOL:
  $sth_ins_inspool = $dbh->prepare(qq{
				      INSERT INTO inspool
				      (ds, ext_unit, record_seq, in_date, status, record, last_change_user, last_change_dt,guid,owner,version)
				      VALUES (?, ?, ?, timestamp'$now', 'NEW', ?, '$user', '$now',?,'$owner',1 )
				     }) or die $dbh->errstr;
  
  # LOAD_STAT:
  my $sth_ins_stat = $dbh->prepare(qq{
				      INSERT INTO load_stat
				      (ds, job_start, job_end, rec_tot_no, last_change_dt, last_change_user,guid,owner,version)
				      VALUES (?, ?, ?, ?, '$now', '$user',?,'$owner',1)
				     }) or die $dbh->errstr;
  
  ######################################################################
  # process files:
  my $thisfile;
  foreach $thisfile (sort @files ) {
    my $job_start = $apiis->extdate2iso($apiis->now);	# get current date and time
    
    print "\nLoad data from file $thisfile\n";
    open (INA, "<$inspool_dir/$thisfile") or die __("Problems opening file"), $thisfile, ": $!\n";
    my $k = 0;
    my $record;
    my $blobstatus=0;
    print "Inserting into database ...\n";
    while (<INA>) {
      mychomp($_);		# remove End-Of-Line
      next if //;		# skip End-Of-File marker from DOS files
      next if /^\s*$/;		# skip empty lines;
      if ( $. == 1 ) {
	$ds = $_;next;
      }
      if ( $. == 2 ) {
	$ext_unit = $_; next;
      }
      if ( ($. == 3) and ($_=~/^blobs/i) ) {
	my $pureline =$_;
	$pureline=~s/blobs//;
	@blob_columns = split(' ',$pureline);
	$blobstatus=1;
	next;
      }
      my $row=$_;
      if ($blobstatus) {
	@line=split(/\|/,$row,$blob_columns[0]);
	#insert files into blobs
	for($i=1;$i<@blob_columns;$i++) {
	  $bufer="";
	  my $bl_file=$line[$blob_columns[$i]];
	  my $bl_file_fullname=$inspool_dir."/$bl_file";
	  $line[$blob_columns[$i]]=load_blob($bl_file_fullname);
	}
	$row=join("\|",@line);
      }
      # insert into table 'inspool':
#      my $record_seq_nextval=$apiis->DataBase->seq_next_val('seq_inspool__record_seq');
      $sth_ins_inspool->execute($ds, $ext_unit,$apiis->DataBase->seq_next_val('seq_inspool__record_seq'),$row, $apiis->DataBase->seq_next_val('seq_database__guid')) or die $dbh->errstr;
      print '*' unless ++$k%100;
      print " --> $k\n" unless $k%1000;
    }
    close INA;
    $apiis->DataBase->sys_dbh->commit;
    
    #print "--> $k\n";   
    print "from file: $thisfile inserted $k records in INSPOOL ... done.\n";
    my $job_end = $apiis->extdate2iso($apiis->now);
    
    # create a record in table 'load_stat':
    $sth_ins_stat->execute($thisfile, $job_start, $job_end, $k,$apiis->DataBase->seq_next_val('seq_database__guid') );
    $apiis->DataBase->sys_dbh->commit;
    # moving files from $inspool_dir to $inspool_dir/done
    mkdir $save_dir, 0750 unless -d $save_dir;
    move("$inspool_dir/$thisfile", "$save_dir/$thisfile")
      or die __("Problems moving file "), $thisfile, ": $!\n";
  }  
  $apiis->DataBase->sys_dbh->commit;
  print " ... file2inspool done.\n";
};
    if ( $@ ) {
      $apiis->DataBase->sys_dbh->rollback;
      print "$@\n";
      return -1;
    } else {
      $apiis->DataBase->sys_dbh->commit;
      return 0;
    }
}

=head2 load_db_from_INSPOOL

   load_db_from_INSPOOL - loads the records from INSPOOL table in there appropriate tables using LoadObjects

   input: list of datastream names

   output: status of the load process 0 if successfull, -1 otherwise

=cut

sub load_db_from_INSPOOL {
  my $ds_list=shift;
  eval {
    my @ds = split( /\s+/,$ds_list );
    foreach my $ds ( @ds ) {
      print "Running datastream $ds ....\n";
      my $load_string = "use $ds";
      eval $load_string;
      print $@ if $@;
      my %arguments=(ds => $ds,debug=>$debug);
      &$ds((ds => $ds,debug=>$debug));
    } # end datastream
  };
    if ( $@ ) {
      print "$@\n";
      return -1;
    } else {
      return 0;
    }
}

=head2 load_blob

   load_blob - loads file as binary large object in table blobs and returns the internal database identificator blob_id

   input: full-qualified file name or variable containing the file, mimetype, blob_id
          if mimetype is missing then it is guessed from the file and first parameter is file name
          if mimetype is supplied then the first parameter is variable containing file data
	  if blob_id is supplied then the record with that blob_id is updated
          if nosynch (the forth parameter) is 1 file will be not exchanged with other databases

   output: internal identificator for the blob - blob_id

=cut
sub load_blob {

  my $file_name=shift;
  my $mimetype=shift;
  my $blob_id=shift;
  my $nosynch=shift;
  #check if there is blob_id, then we are updating
  my $update=0; 
  $update=1 if (defined $blob_id and $blob_id);
  #check if there is nosynch flag, then the record is marked as not for synchronization
  my $synch='t';
  $synch='f' if ($nosynch);

  my $now=scalar $apiis->extdate2iso($apiis->now);
  my $user=$apiis->User->id;
  my $owner = 'unknown';
  if ( lc $apiis->access_rights eq 'auth' ){
     $owner = $apiis->User->user_node;
  }
  if ( lc $apiis->access_rights eq 'ar' ){
     $owner = $apiis->User->user_marker;
  }

  my $bufer='';
  
  eval {
    unless ($mimetype) {
      open(FILE, "<$file_name") or &{$apiis->log('warning',"load_blob: Missing file - $file_name" );
				     die __("Missing file:[_1]", $file_name);
				   };
      while(read(FILE, $data, 1024)) {
	$bufer .= $data;
      }
      close FILE;
      if (!$bufer) {
	$apiis->log('warning',"load_blob: Error loading file - $file_name");
	die __("Error loading file: [_1]",$file_name);
      };
      $mimetype=mimetype($file_name);
      $apiis->log('debug',"load_blob: Mime type of $file_name is $mimetype (as guessed by MMagic)");
    } else {
      $apiis->log('debug',"load_blob: Mime type is $mimetype (from CGI)");
      $bufer=$file_name;
    }
    if ( $mimetype eq 'image/pjpeg' ) { $mimetype = 'image/jpeg'; }
    my $db_mimetype;
    my $sql_mime="SELECT db_code FROM codes WHERE ext_code='$mimetype' AND class='MIMETYPE'";
    my $sql_ref=$Apiis::Init::apiis->DataBase->sys_sql($sql_mime);
    while (my $row=$sql_ref->handle->fetch) {
      $db_mimetype=$$row[0];
    }
    $apiis->log('err',"No coding found for (ext_code,class) ($mimetype,'MIMETYPE')") unless($db_mimetype);
    my $tst_var=sprintf "  INSERT INTO blobs
			  (blob_id, blob,db_mimetype,last_change_user, last_change_dt,guid,owner,version,synch)
			  VALUES (?,?, ?, '%s', '%s',?,'%s',1,'%s' )
			 ",$user,$now,$owner,$synch;
    if ($update) {    
        $tst_var=sprintf " UPDATE blobs
	    	           SET blob=?,db_mimetype=?,last_change_user='%s', last_change_dt='%s',version=version+1 
		           WHERE blob_id=? ",$user,$now ;
    }
    $apiis->log('debug',"load_blob: ".$tst_var);
    my $sth_ins_blobs=$Apiis::Init::apiis->DataBase->sys_dbh->prepare($tst_var) or die $dbh->errstr;
    $blob_id=$apiis->DataBase->seq_next_val('seq_blobs__blob_id') unless ($blob_id);

    my $table_ref = $apiis->Model->table('blobs');

    my $bind_type=$apiis->DataBase->bindtypes($table_ref->datatype('blob_id'));
    eval "%bind_ref= ($bind_type)";
    if ($update) {
        $sth_ins_blobs->bind_param(3,$blob_id,\%bind_ref);
    } else {
        $sth_ins_blobs->bind_param(1,$blob_id,\%bind_ref);
    }	
    $bind_type=$apiis->DataBase->bindtypes($table_ref->datatype('blob'));
    eval "%bind_ref= ($bind_type)";
    if ($update) {
        $sth_ins_blobs->bind_param(1,$bufer,\%bind_ref);
    } else {
        $sth_ins_blobs->bind_param(2,$bufer,\%bind_ref);
    }
    $bind_type=$apiis->DataBase->bindtypes($table_ref->datatype('db_mimetype'));
    eval "%bind_ref= ($bind_type)";
    if ($update) {
        $sth_ins_blobs->bind_param(2,$db_mimetype,\%bind_ref);
    } else {
        $sth_ins_blobs->bind_param(3,$db_mimetype,\%bind_ref);
    }
    if (!$update) {
        $bind_type=$apiis->DataBase->bindtypes($table_ref->datatype('guid'));
        eval "%bind_ref= ($bind_type)";
        $sth_ins_blobs->bind_param(4,$apiis->DataBase->seq_next_val('seq_database__guid'),\%bind_ref);
    }
    $sth_ins_blobs->execute();
  };
  if ($@) {
    $apiis->log('err',"load_blob: $@");
    return undef;
  } else {
    my $action;
    $update?$action='updated':$action='inserted';
    $apiis->log('info',"load_blob: Successfully ".$action." file in blobs with internal number $blob_id");
    return $blob_id;
  }
}

=head2 mimetype

   mimetype - guesses the mime type (or media type) of the supplied file 

   input: full qualified file name

   output: file mimetype

=cut
sub mimetype {
  use File::MMagic;
  my $file_name=shift;
  my $mm = File::MMagic->new();
  my $magic=$mm->checktype_filename($file_name);
  $magic =~ s/ ;  # look for a the first semicolon
	       .* # and then anything up until
	       $  # the end of line
	       /;/x;
  return  $magic;
}


=head2 read_pass

- reads user name and password from file

=cut

sub read_pass {
  my $pass_file=shift;
  my ($id,$pass);
  open (PF,"<$pass_file") or return undef;
  while (<PF>){
    mychomp($_);
    $id=$_ if ( $. == 1 );
    $pass=$_ if ( $. == 2 );
    last if ($. >= 3);
  }
  return ($id,$pass);
}



1;

=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>

load_db_from_INSPOOL  and original file2inspool written by Ralf Fischer <ralf@tzv.fal.de>

CheckLO and original Process_LO_Batch written by Helmut Lichtenberg <heli@tzv.fal.de>

=cut
