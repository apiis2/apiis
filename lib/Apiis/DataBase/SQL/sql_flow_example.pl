#!/usr/bin/perl

BEGIN {    # execute some initialization before compilation
   # $Exporter::Verbose=1;
   use Env qw( APIIS_HOME );
   die "APIIS_HOME is not set!\n" unless $APIIS_HOME;
   use lib "$APIIS_HOME/lib";
   require apiis_init;
   initialize_apiis( VERSION => '$Revision: 1.1 $' );
}

$apiis->check_status( die => 'CRIT' );
use Apiis::DataBase::Record;
use Apiis::DataBase::SQL::Statement;
use Data::Dumper;

$apiis->join_model('efabis');




my  $sqltext="INSERT INTO  animal (db_animal,comments,birth_dt) values(1,'just another comment','01-03-2001') ";
$sqltext="UPDATE  breeds  set country_id=NULL where breed_id=1 ";
#$sqltext="SELECT * from me";

Proceed($sqltext);



sub ExecuteInsert {
  my $statement=shift;

  my $record = Apiis::DataBase::Record->new(
					    tablename => $statement->tablename,
					   );
  my @column_names=$statement->columns();
  my @column_values=$statement->values();
  for($i=0;$i<@column_names;$i++) {
    $record->column($column_names[$i])->intdata($column_values[$i]);
  }
  $record->encoded(1);
  $record->insert();
  $record->check_status;
  if ($record->status) {
    $apiis->DataBase->dbh->rollback;
  } else {
    $apiis->DataBase->dbh->commit;
    print $record->rows, " records inserted.\n";
  }
}

sub ExecuteUpdate {
  my $statement=shift;
 
  my  $record = Apiis::DataBase::Record->new(
					     tablename => $statement->tablename
					    );

  my @column_names=$statement->columns();
  my @column_values=$statement->values();
  for($i=0;$i<@column_names;$i++) {
    $record->column($column_names[$i])->intdata($column_values[$i]);
    $record->column($column_names[$i])->updated(1);
  }
 print $record->column(country_id)->intdata,"\n";
  my $sqlselect=sprintf "SELECT %s FROM %s  WHERE %s",$apiis->DataBase->rowid,$statement->tablename,$statement->whereclause;

  my $sql_ref=$apiis->DataBase->directsql($sqlselect);

  $apiis->check_status;
  while (my $arr_ref = $sql_ref->handle->fetch) {
    push @data_array,${$arr_ref}[0];
  }
  warn "More than one record matches the conditions!\n" if(@data_array>1);

  my $updated_rows=0;
  foreach $oid (@data_array) {
    $record->column($apiis->DataBase->rowid)->intdata($oid);
    $record->encoded(1);
    $record->update();
    $record->check_status;
    if ($record->status) {
      $apiis->DataBase->dbh->rollback;
      exit;
    }
    $updated_rows+=$record->rows;
  }
  $apiis->DataBase->dbh->commit;
  print $updated_rows, " records updated.\n";
}


sub ExecuteDelete {
  my $statement=shift;
 
  my  $record = Apiis::DataBase::Record->new(
					     tablename => $statement->tablename
					    );

 my $sqlselect=sprintf "SELECT %s FROM %s  WHERE %s",$apiis->DataBase->rowid,$statement->tablename,$statement->whereclause;

  my $sql_ref=$apiis->DataBase->directsql($sqlselect);
  $apiis->check_status;

  while (my $arr_ref = $sql_ref->handle->fetch) {
    push @data_array,${$arr_ref}[0];
  }
  warn "More than one record matches the conditions!\n" if(@data_array>1);
  my $deleted_rows=0;
  foreach $oid (@data_array) {
    $record->column($apiis->DataBase->rowid)->intdata($oid);
    $record->encoded(1);
    $record->delete();
    $record->check_status;
    $apiis->DataBase->dbh->rollback  if ($record->status); 
    $deleted_rows+=$record->rows;
  }
  $apiis->DataBase->dbh->commit;
  print $deleted_rows, " records deleted.\n";
}


sub ExecuteSelect {
  my $sqltext=shift;
  die "SELECT is not implemented yet!\n";
}


sub Proceed {
  my $sqltext=shift;
  my  $statement = Apiis::DataBase::SQL::Statement->new(
							sql     => $sqltext
						       );

  if ($statement->status) {
    foreach ($statement->errors) {
      $_->print;
    }
    exit;
  };
  
  if ($statement->actionname eq "SELECT") {
    $sth=ExecuteSelect($sqltext);
  } elsif ($statement->actionname eq "INSERT") {
    ExecuteInsert($statement);
  } elsif ($statement->actionname eq "UPDATE") {
    ExecuteUpdate($statement);
  } elsif ($statement->actionname eq "DELETE") {
    ExecuteDelete($statement);
  } else {
    die "Only INSERT, UPDATE, DELETE and SELECT allowed!\n";
  }
}



