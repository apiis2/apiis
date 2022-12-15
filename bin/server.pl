#!/usr/bin/env perl 
=head1 NAME

       server.pl

=head1 SYNOPSIS

       server.pl -w <password file> -p <model_name> [-c stop -i <IP address>]


=head1 DESCRIPTION

       Creates and manages the local Net::EasyTCP server used in APIIS database synchronization

=cut
BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use warnings;
use strict;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.17 $' );

use Net::EasyTCP;
use Data::Dumper;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Apiis::DataBase::Sync::Node;
use FileHandle;
use apiis_alib;
use Apiis::DataBase::User;

use Getopt::Std;
use vars qw( $opt_p  $opt_w $opt_c $opt_i );
getopts('p:w:c:i:h'); 


  my $pass_file;
  my $modelname;
  my ($command, $nodeip);
  if ($opt_p){
    $modelname = $opt_p;
  } 
  if ($opt_w){
    $pass_file = $opt_w;
  }
  if ($opt_c){
    $command = $opt_c;
  }
  if ($opt_i){
    $nodeip = $opt_i;
  }
  exit unless  ($modelname and  $pass_file);
  my ($id, $pass)=read_pass($pass_file);

  my $thisobj = Apiis::DataBase::User->new(
					   id       => $id,
					   password => $pass,
					  );
  $thisobj->check_status;
  $apiis->join_model($modelname, userobj => $thisobj);
  $apiis->check_status;
  exit if ($apiis->status);

  my  $trgname="";
  my  @DED=();
  my  $ownname=$apiis->node_name;
  my $fh = new FileHandle;
  my $DED;
  my $restart_count=0;
  my ($servstat, $node, $client, $server, $logging, $log_folder, $log_file, $ownip);
LOOP: {
  if (lc($command) eq 'stop') {
    eval {
       $client = new Net::EasyTCP(
				  mode            =>      "client",
				  host            =>      $nodeip,
				  port            =>      5433,
				 );
       $client->send("SD");
       $servstat= "Stopping server";
     };
    if($@) {
      $servstat="Not responding: $!";
    }
    print "$servstat\n";
    last LOOP;
  }
  $restart_count++;
  ($logging, $log_folder)=read_conf();
  $log_file=$log_folder."server_".$apiis->today.".log";
  if ($logging) {
    $fh->open(">>$log_file") || print "Cannot create log file\n";
  }
  


  $node=Apiis::DataBase::Sync::Node->new(
					 nodename=>$ownname, 
					 class_column=>'owner',
					 logging=>$logging
					);
  $node->debug(6);
  $server=$node->create_server('5433');
  $ownip=$node->name2ip($ownname);
  eval {
    $server->setcallback(
			 data            =>      \&gotdata,
			 connect         =>      \&connected,
			 disconnect      =>      \&disconnected,
			)
      || die ;
    $node->print_log($fh,'(Re)Starting the server');
    $node->state('FREE');
    $node->partner(0);
    $server->start() || die ;
  };
  if ($@) {
    $node->status(1);
    $node->errors(
		  Apiis::Errors->new(
				     type      => 'OS',
				     severity  => 'CRIT',
				     from      => 'server.pl',
				     msg_short => "$@",
				     msg_long  => "$@"
				    )
		 );
  }
  if ($node->status) {
    foreach ($node->errors) {
      $_->print;
    }
    $fh->close if $logging;
    goto LOOP if ($@ !~/FATAL|CREATING|SETTING|STARTING/ and $restart_count<10) ;
  }

  $fh->close if $logging;
}

=head2 got_data

       This suberoutine is executed each time when server receive data from a client. It gets client object as parameter and takes response based on the data - see protocol block-schema in APIIS documentation

=cut
sub gotdata {
  my $client = shift;
  my $serial = $client->serial();
  my $clientIP=$client->remoteip();
  my $data = $client->data();
  my ($status,$errobj_ref,$statesrcref);
  my @result=();
  
    $node->print_log($fh,"Received data from client $serial from host $clientIP");
    if ($data eq "FREE?") {
      $node->print_log($fh,'FREE? signal received');
      my $logtext='Server status:'.$node->state;
      $node->print_log($fh,$logtext);
      $client->send($node->state)|| die "FATAL ERROR SENDING SERVER STATUS TO CLIENT: $@"; #send current state
      if ($node->state eq "FREE"){
	$node->partner($serial); #mark the client number
	$node->state('BUSY');
	$trgname=$node->ip2name($clientIP); #convert IP to name
	print "target name $trgname\n" if $node->debug>6;
	$node->read_DED($trgname,'target');
	#die "FATAL ERROR ".$$errobj_ref[0]->msg_long if ($node->status);
      } else {
        $client->close() || die "ERROR CLOSING CLIENT: $@" if ($node->state eq "BUSY");
      }
    }
    elsif ((ref($data) eq "HASH") and (exists $$data{'DED'})) {
      $node->print_log($fh,'DED description received');
      $DED=$$data{'DED'};
      my $result=$node->check_DED($DED,'targets');
      if ($node->status) {
	$client->close() || die "ERROR CLOSING CLIENT: $@";
	die "FATAL ERROR ".$$errobj_ref[0]->msg_long;
      }
      if ($result) {
	$client->send('OK') || die "ERROR SENDING 'OK' TO CLIENT: $@"; #send confirmation
	$node->print_log($fh,'Data element confirmed - OK send to client');
      } else {
	$client->send('BAD') || die "ERROR SENDING 'BAD' TO CLIENT: $@"; #send confirmation
	$node->print_log($fh,'Data element not confirmed - BAD send to client');
      }
    }
    elsif ((ref($data) eq "HASH") and (exists $$data{id}) and  ($$data{id} eq "STATE")) {
      if ($serial ne $node->partner) {
	$client->close() || die "ERROR CLOSING CLIENT: $@";
	exit; # da se obmisli jiji
      }
      $node->print_log($fh,'Received state data');
      delete $$data{id};

      my $stateref=$node->read_state($DED);
      if ($status) {
	$client->close() || die "ERROR CLOSING CLIENT: $@";
	die "FATAL ERROR ".$$errobj_ref[0]->msg_long;
      }
      $node->print_log($fh,'Server data state read');
      my $t0=[gettimeofday];
      my $fullsrcref=$node->compare_states($data);
      my $comparestate_time=tv_interval($t0);
      #$data=$node->compare_states($data);
      #%$data=(); # never delete this data
      #clear the memory 
      $node->print_log($fh,"Data state compared: $comparestate_time");
      
      my %sort_order=('D'=>0,'U'=>1,'I'=>2);
      my @keyz=sort {$sort_order{$fullsrcref->{$a}} cmp $sort_order{$fullsrcref->{$b}}} keys  %$fullsrcref; #"D,U,I" order, thus deletions are first
      my $allrecords=@keyz;
      $node->print_log($fh,"Have to send $allrecords merge elements");
      $client->send(["RCNT",$allrecords]) || die "ERROR SENDING TO CLIENT: $@"; #number of merge elements
      $node->print_log($fh,"RCNT $allrecords sent");
      my $reply=$client->receive() || die "ERROR RECEIVING FROM CLIENT: $@";
      die __("UNRECOGNISED RESPONSE FROM CLIENT: [_1]",$reply) unless  ($reply eq 'MOK');
      my $element=1;
      my $guid;
      foreach $guid (@keyz) {
	@result=();
	if ( $$fullsrcref{$guid} ne "D") {
	  my $sqltext="Select $$DED[2] from  $$DED[0] where guid=$guid";
	  print "$sqltext\n" if $node->debug>6;
	  $t0=[gettimeofday];
	  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
	  my $status = $sql_ref->status;
	  my $affected_rows = $sql_ref->rows;
	  if ($status) {
	    $node->status(1);
	    $node->errors(
			  Apiis::Errors->new(
					     type      => 'DB',
					     severity  => 'CRIT',
					     from      => 'Apiis::DataBase::Sync::Node',
					     msg_short => "Cannot read merge element $guid",
					     msg_long  => "Cannot read merge element $guid from $$DED[0]"
					    )
			 );
	    # return undef;
	  }
	  if ($status) {
	    $client->close() || die "ERROR CLOSING CLIENT: $@";
	    die;
	  }
	  my $arr_ref = $sql_ref->handle->fetch;
	  @result = @{$arr_ref};
	  $sql_ref->handle->finish;
        }
	$t0=[gettimeofday];
	$client->send(["M",$guid,$$fullsrcref{$guid},@result])|| die "ERROR SENDING TO CLIENT: $@\n"; #send merge data
	  $node->print_log($fh,"$element elements sent") if ($element%1000==0);
	  $element++;
	} #end foreach 
      %$fullsrcref=();
      $client->send(["END"])|| die "ERROR SENDING TO CLIENT: $@\n"; #send end sygnal
      $node->print_log($fh,'END signal sent');
    }
    elsif ($data eq "READY") {
      $node->state('FREE');
      $node->partner(0);
      $node->print_log($fh,"Synchronization with $trgname finished!");
    }
    elsif ($data eq "SD") {
      my $clientip=$client->remoteip();
      if ($clientip eq $ownip) {
	$server->stop();
	$node->print_log($fh,"Server stopped!");
      } else {
	$node->print_log($fh,"Attempt to stop server from $clientip!");
      }
    }
    elsif ($data eq "PNG") {
      my $clientip=$client->remoteip();
      $client->send($node->state);
      $node->print_log($fh,"Server pinged by $clientip!");
    }
    else {
      $node->print_log($fh,'Unrecognized response');
      $client->close() || die "ERROR CLOSING CLIENT: $@";
      $node->state('FREE');
      $node->partner(0);
    }
  }


=head2 connected

       This subroutine  gets called when a new client connects

=cut
sub connected {
  my $client = shift;
  my $serial = $client->serial();
  my $ip = $client->remoteip();
  $node->print_log($fh,"Client $serial from host $ip connected");
  $node->print_log($fh, $client->compression) if $node->debug>6; 
  $node->print_log($fh, $client->encryption) if $node->debug>6; 
}

=head2 disconnected

       This subroutine gets called when an existing client disconnects

=cut
sub disconnected {
  my $client = shift;
  my $serial = $client->serial();
  my $ip = $client->remoteip();
  $node->print_log($fh,"Client $serial from host $ip disconnected");
  $fh->autoflush;
  if ($serial==$node->partner) {
    $node->state('FREE');
    $node->partner(0);
  }
}



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


=head1 AUTHOR

Zhivko Duchev <duchev@tzv.fal.de>

