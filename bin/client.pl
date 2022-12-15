#!/usr/bin/env perl 

=head1 NAME

client.pl -- perl script for the clent side in the synchronization process

=head1 SYNOPSIS

client.pl <password_file> <model_name> <server_name>

=head1 DESCRIPTION

The client creates socket connection to the server on port 5433 and synchronize the two databases according to the protocol described in APIIS documentation

=cut


BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use warnings;
use strict;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.16 $' );

use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Net::EasyTCP;
use FileHandle;
use Apiis::DataBase::Sync::Node;
use Apiis::DataBase::User;
use apiis_alib;

my $psswd=shift;
my $modelname=shift;
my $servername=shift;
my ($id, $pass)=read_pass($psswd);
my $thisobj = Apiis::DataBase::User->new(
					 id       => $id,
					 password => $pass,
					);
$thisobj->check_status;
$apiis->join_model($modelname, userobj => $thisobj);
$apiis->check_status;
exit if ($apiis->status);



my $version="1.0";


my ($fh,$total_dbmerge_time,$total_receivemerge_time,$begintime,$alltime);



doit($servername);


=head2 read_conf 

Parses the configuration file 'synchrc' from the project 'etc' folder

=cut
sub read_conf {
  my %conf=();
  my $ini_file=$apiis->APIIS_LOCAL."/etc/synchrc";
  no strict 'refs';
  my $a = Apiis::CheckFile->new( file => "$ini_file" );
  if ( $a->status ) {
    foreach ( @{ $a->errors } ) {
      $_->print;
    }
    $conf{'use_filelog'}=1;
    $conf{'filelog_folder'}=$apiis->APIIS_LOCAL."/var";
  }else{
    my $cfg = new Config::IniFiles( -file   =>  "$ini_file",  -nocase => 1 );
  EXIT: 
    foreach my $mainkey ( $cfg->Sections ) {
      if ($mainkey eq "logging"){
	foreach my $subkey ( $cfg->Parameters($mainkey) ) {
	  $conf{$subkey} = $cfg->val( $mainkey, $subkey );
	  $conf{$subkey} =~ /^\s*(\$*APIIS_HOME)(.*)/ && ($conf{$subkey} = $apiis->APIIS_HOME . $2);
	  $conf{$subkey} =~ /^\s*(\$*APIIS_LOCAL)(.*)/ && ($conf{$subkey} = $apiis->APIIS_LOCAL . $2);
	  $conf{$subkey} =~ /^\s*(\$*HOME)(.*)/ && ($conf{$subkey} = $apiis->HOME . $2);
	  $conf{$subkey} =~ s/\s*$//; 
	}
	last EXIT;
      }
    }
    $conf{'use_filelog'}=1 unless (exists $conf{'use_filelog'});
    $conf{'filelog_folder'}=$apiis->APIIS_LOCAL."/var" unless (exists $conf{'filelog_folder'});
  }
  return ($conf{'use_filelog'},$conf{'filelog_folder'})
}


=head2 doit 

       Creates new node object for the client node and handles the errors returned by 'synchclient' subroutine 

=cut
sub doit {
  my $servername=shift;
  my $percent_done=0;
  my ($logging, $log_folder)=read_conf();

  my $node=Apiis::DataBase::Sync::Node->new(
					    nodename=>$apiis->node_name,
					    class_column=>'owner',
					    logging=>$logging
					   );

  $fh = new FileHandle;  
  my $log_file=$log_folder."client_".$apiis->today.".log";
  if ($logging) {
    $fh->open(">>$log_file") || print "Cannot create log file\n";
  }

  #$node->debug(6);

  my $errobj_ref=synchclient($node,$servername);
  
  if (defined $errobj_ref and @$errobj_ref) {
    foreach my $err (@$errobj_ref) {
      my $logtext=$err->severity." ERROR:  ". $err->msg_long;
      $node->print_log($fh,$logtext);
    }
    $fh->close if $logging;
    exit(1);
  }
  $fh->close if $logging;
}


=head2 synchclient

       Creates new Net::EasyTCP client which communicates with the server. Synchronizes data according to the protocol and produces some statistics

=cut
sub synchclient {
  my $node=shift;
  my $servernode=shift;
  my $insert=0;
  my $update=0;
  my $delete=0;
  my $insertall=0;
  my $updateall=0;
  my $deleteall=0;
  my $received=0;
  my $stateref=();
  my $fullsrcref=();
  my ($reply,$t0,$dbmerge_time,$receivemerge_time);
      $total_dbmerge_time=0;
      $total_receivemerge_time=0;

  

  my $host=$node->name2ip($servernode);
  $node->print_log($fh,"Synchronization with node: $servernode on host: $host started");
  $begintime=[gettimeofday];
  $node->read_DED($servernode,'source');
  if ($node->status) {
    return $node->errors;
  }
  $node->print_log($fh,'Source information read');
  my $client=$node->create_client($host,'5433');
  return $node->errors if ($node->status);
  $node->print_log($fh, $client->compression) if $node->debug>6; #jiji
  $node->print_log($fh, $client->encryption) if $node->debug>6; #jiji
  $node->print_log($fh,'Connection created');


  # Send initial string

  eval {
        $client->send("FREE?");
        $reply = $client->receive();
  };
  if ($@) {
    my $err_obj = Apiis::Errors->new(
				     type      => 'OS',
				     severity  => 'FATAL',
				     from      => 'CLIENT',
				     msg_short => "$@",
				     msg_long  => "Error in handshaking ==>$@",
				    );
    $client->close();
    return [$err_obj];
  }
  
  $node->print_log($fh,"Server replied $reply");
  if ($reply eq "BUSY") {
    $node->print_log($fh,'Connection refused by server'); 
    eval {
          $client->close();
    };
    if ($@) {
      my $err_obj = Apiis::Errors->new(
				       type      => 'OS',
				       severity  => 'FATAL',
				       from      => 'CLIENT',
				       msg_short => "$@",
				       msg_long  => "Cannot close client ==>$@",
				      );
      return [$err_obj];
    };

    $node->print_log($fh,'Connection closed');
  } elsif ($reply eq "FREE")  {

    foreach my $DED (@{$node->sources_DED}) {
      eval {
	use Data::Dumper;
	print Dumper($DED) if $node->debug>6;
	$client->send({'DED'=>$DED});
	$node->print_log($fh,'Data element description sent');
	$reply = $client->receive();
	die "DED ($$DED[0]) refused by server" if ($reply ne "OK");
	$node->print_log($fh,'Data element description confirmed');
      };
      if ($@) {
	my $err_obj = Apiis::Errors->new(
					 type      => 'DATA',
					 severity  => 'CRIT',
					 from      => 'CLIENT',
					 msg_short => "$@",
					 msg_long  => "ERROR in data element description ==>$@",
					);
	return [$err_obj];
      };
      $t0=[gettimeofday];
      my $numrows=$node->read_state($DED);
      $stateref=$node->DED_state;
      my $readstate_time=tv_interval($t0);
      $node->print_log($fh,"Time elapsed in reading state of ($$DED[0],$$DED[1]): $readstate_time ");
      my $num_records= scalar keys %$stateref;
      $node->print_log($fh,"Number of records: $num_records");
      if ($node->status) {
	return $node->errors;
      }
      $node->print_log($fh,'State information read');
      
      eval {
	$$stateref{'id'}='STATE';
	$t0=[gettimeofday];
	$client->send($stateref);
	my $sendstate_time=tv_interval($t0);
	$node->print_log($fh,"Time elapsed in sending state: $sendstate_time");	
      };
      if ($@) {
	my $err_obj = Apiis::Errors->new(
					 type      => 'OS',
					 severity  => 'FATAL',
					 from      => 'CLIENT',
					 msg_short => "$@",
					 msg_long  => "Cannot send state information ==>$@",
					);
	return [$err_obj];
      };
      $node->print_log($fh,'State information sent');
      eval {
	$reply = $client->receive(600);
      };
      if ($@) {
	my $err_obj = Apiis::Errors->new(
					 type      => 'OS',
					 severity  => 'FATAL',
					 from      => 'CLIENT',
					 msg_short => "$@",
					 msg_long  => "Cannot receive merge data ==>$@",
					);
	return [$err_obj];
      };
      $node->print_log($fh,'Received response from the server');
      my $countall=0;
      while ($$reply[0] ne "END") {
	if ($$reply[0] eq "RCNT") {
	  $dbmerge_time=0;
	  $receivemerge_time=0;
	  $countall=$$reply[1];
	  $node->print_log($fh,"Expected $countall merge records from the server");
	  eval {
	    $client->send("MOK");
	    $reply = $client->receive();
	  };
	  if ($@) {
	    my $err_obj = Apiis::Errors->new(
					     type      => 'OS',
					     severity  => 'FATAL',
					     from      => 'CLIENT',
					     msg_short => "$@",
					     msg_long  => "Cannot exchange merge information ==>$@",
				  );
	    return [$err_obj];
	  };
	  $delete=0;
	  $insert=0;
	  $update=0;
	  next;
	}
	if ($$reply[0] eq "M") {
	  if ($$reply[2] eq "D") {
	    if ($$reply[1]=~/^d/) {
	      $insert--;
	      $update++
	    }
	    else {
	      $delete++;
	    }
	  } elsif( $$reply[2] eq "I") {
	    $insert++;
	  } elsif ( $$reply[2] eq "U") {
	    $update++;
	  }
	  $received++;
	  $t0=[gettimeofday];
	  $node->load_merge_element($DED,$reply);
	  $dbmerge_time+=tv_interval($t0);
	  $node->check_status;
	  eval {
	    $t0=[gettimeofday];
	    $reply = $client->receive();
	    $receivemerge_time+=tv_interval($t0);
	  };
	  if ($@) {
	    my $err_obj = Apiis::Errors->new(
					     type      => 'OS',
					     severity  => 'FATAL',
					     from      => 'CLIENT',
					     msg_short => "$@",
					     msg_long  => "Cannot exchange merge information ==>$@",
					    );
	    return [$err_obj];
	  };
  	  if ($received%1000==0) {
	    $node->print_log($fh,"$received elements received") if $node->debug>5;
	  };
	} else {
	  $node->print_log($fh,"ERROR:  Unrecognized response from the server!");
	  $apiis->DataBase->sys_dbh->rollback;  #call rollback
	  eval {
	    $client->close();
	  };
	  if ($@) {
	    my $err_obj = Apiis::Errors->new(
					     type      => 'OS',
					     severity  => 'FATAL',
					     from      => 'CLIENT',
					     msg_short => "$@",
					     msg_long  => "Cannot close client ==>$@",
					    );
	    print "$@";
	    return [$err_obj];
	  };
	  $node->print_log($fh,'Connection closed');
	  exit;
	}
      }#end while loop
      $insertall +=$insert;
      $updateall +=$update;
      $deleteall +=$delete;
      $node->print_log($fh,"$insert records inserted, $update records updated, $delete records deleted");
      $total_dbmerge_time+=$dbmerge_time;
      $total_receivemerge_time+=$receivemerge_time;
      $node->print_log($fh,"Time elapsed in receiving merge data: $receivemerge_time");
      $node->print_log($fh,"Time elapsed in updating database: $dbmerge_time");	
    } #end foreach
    $apiis->DataBase->sys_dbh->commit;
    $apiis->check_status;
    $node->print_log($fh,"Total time elapsed in receiving merge data: $total_receivemerge_time");
    $node->print_log($fh, "Total time elapsed in updating database: $total_dbmerge_time");	
    $node->print_log($fh,"Database updated: Total $insertall records inserted, $updateall records updated, $deleteall records deleted");
    eval {
      $client->send("READY");
      $client->close();
    };
    if ($@) {
      my $err_obj = Apiis::Errors->new(
				       type      => 'OS',
				       severity  => 'FATAL',
				       from      => 'CLIENT',
				       msg_short => "$@",
				       msg_long  => "Cannot end synchronization ==>$@",
				      );
      return [$err_obj];
    };
    $node->print_log($fh,'Connection closed');
  }
  $node->print_log($fh,'Synchronization finished');
  $alltime=tv_interval($begintime);
  $node->print_log($fh,"Total synchronization time: $alltime");
  return undef;
}


=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>

=cut
