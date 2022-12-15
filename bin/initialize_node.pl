#!/usr/bin/env perl 

=head1 NAME

initialize_node.pl - script for initial setting of the sequences and node information 

=head1 SYNOPSIS

initialize_node.pl <model_name> <sequences_start_value> <node IP address>

=head1 DESCRIPTION

The script loads the node name from apiisrc file and the node IP address from parameter list into table 'nodes'. It also initializes all sequences with the start value from the parameter list.

=cut


BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use strict;
use warnings;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.5 $' );


my $modelname=shift;
my $start_value=shift;
my $node_ip=shift;

$apiis->join_model($modelname);

use Apiis::DataBase::Record;

fix_sequences($start_value);
set_node_ip($node_ip);

=head2 fix_sequences

Initializes all sequences with the value passed as second parameter

=cut

sub fix_sequences {
  my $initial_value=shift;
  my @tables = $apiis->Model->tables;				
  foreach $table (@tables) {
    my $table_ref = $apiis->Model->table($table);		
    if ($table_ref->sequence) {
       my @sequences=$table_ref->sequence;
       foreach $sequence (@sequences) {
	 my $sqltext="select setval('$sequence', $initial_value);";
	 print "$sqltext\n";
	 my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
	 if ($sql_ref->status) {
	   foreach ($sql_ref->errors) {
	     $_->print;
	   }
	   $apiis->DataBase->dbh->rollback;
	   print "err\n";
	   return;
	 }
	 if ($apiis->status) {
	   foreach ($apiis->errors) {
	     $_->print;
	   }
	   $apiis->DataBase->dbh->rollback;
	   print "erra\n";
	   return;
	 }
       } #end foreach
     } #end if
  } #end foreach
  $apiis->DataBase->dbh->commit;
} #end sub

=head2 set_node_ip

Writes node name and node IP address in table 'nodes'

=cut

sub set_node_ip {
  my $node_ip=shift;
  my $now=$apiis->now;
  my $sqltext=sprintf "INSERT INTO nodes (guid,nodename,address,last_change_dt,last_change_user,owner,version,synch) VALUES (%s,%s,%s,%s,%s,%s,1,'1')",$apiis->DataBase->seq_next_val('seq_database__guid'),$apiis->DataBase->dbh->quote($apiis->node_name),$apiis->DataBase->dbh->quote($node_ip),$apiis->DataBase->dbh->quote($apiis->now),$apiis->DataBase->dbh->quote($apiis->user),$apiis->DataBase->dbh->quote($apiis->node_name);
  print "$sqltext\n";
  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
  if ($sql_ref->status) {
    foreach ($sql_ref->errors) {
      $_->print;
    }
    $apiis->DataBase->dbh->rollback;
  } else {
    $apiis->DataBase->dbh->commit;
  }
}
