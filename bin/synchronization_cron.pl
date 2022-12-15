#!/usr/bin/env perl 

=head1 NAME

synchronization_cron.pl -- perl script for automated execution of synchronization

=head1 DESCRIPTION

This script has to be scheduled as a cron job. It reads the time schedule settings from $APIIS_LOCAL/etc/synchrc, automatically starts/stops the local server and synchronizes with other nodes

=cut


BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use warnings;
use strict;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.4 $' );

use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Net::EasyTCP;
use FileHandle;
use Apiis::DataBase::Sync::Node;
use Apiis::DataBase::User;
use apiis_alib;

my $psswd=shift;
my $modelname=shift;
my ($id, $pass)=read_pass($psswd);
my $thisobj = Apiis::DataBase::User->new(
					 id       => $id,
					 password => $pass,
					);
$thisobj->check_status;
$apiis->join_model($modelname, userobj => $thisobj);
$apiis->check_status;




my $conf_ref=read_conf();
manage_server($conf_ref);
synch_with_nodes($conf_ref);

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
    return;
  }else{
    my $cfg = new Config::IniFiles( -file   =>  "$ini_file",  -nocase => 1 );
     foreach my $mainkey ( $cfg->Sections ) {
      if ($mainkey eq "server" or $mainkey eq "nodes"){
	foreach my $subkey ( $cfg->Parameters($mainkey) ) {
	  $conf{$subkey} = $cfg->val( $mainkey, $subkey );
	  $conf{$subkey} =~ s/\s*$//;
	}
      }
    }
  }
  return \%conf;
}



=head2 uptime 

Returns 1 if the current time is in the scheduled interval otherwise 0

=cut

sub uptime{
  my $schedule=shift;
  my @times=split(',',$schedule);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $current_time="$hour:$min";
  foreach (@times) {
    my ($start,$end)=split('-',$_);
    return 1 if (($start le $current_time) and ($current_time lt $end));
  }
  return 0;
}


=head2 manage_server

Starts/stops the server depending on the schedule

=cut

sub manage_server {
  my $conf_ref=shift;
  my $servername=$apiis->node_name;
  my $serverstat=ping_node(uc $servername);
  system("server.pl $psswd $modelname &") if (uptime($$conf_ref{server_uptime}) and ($serverstat eq "DOWN"));
  stop_server($servername) if (not uptime($$conf_ref{server_uptime}) and ($serverstat eq "FREE"));
}



=head2 ping_node

Pings  remote or local node and returns 'DOWN' if the server is not running, otherwise 'FREE' or 'BUSY'

=cut
sub ping_node {
  my $nodename=shift;
  my $node=Apiis::DataBase::Sync::Node->new(
					    nodename=>$nodename,
					    class_column=>'owner',
					   );
  my $nodestat;
  eval {
    my $nodeip=$node->name2ip($nodename);
    my $client = new Net::EasyTCP(
				  mode            =>      "client",
				  host            =>      $nodeip,
				  port            =>      5433,
				 );
    $client->send("PNG");
    $nodestat=$client->receive(60);
  };
  if($@) {
    $nodestat="DOWN";
  }
  return $nodestat;
} 


=head2 stop_server

Stops the server using 'SD' signal

=cut
sub stop_server {
  my $nodename=shift;
  my $node=Apiis::DataBase::Sync::Node->new(
					    nodename=>$nodename,
					    class_column=>'owner',
					   );
  eval {
    my $nodeip=$node->name2ip($nodename);
    my $client = new Net::EasyTCP(
				  mode            =>      "client",
				  host            =>      $nodeip,
				  port            =>      5433,
				 );
    $client->send("SD");
    return 0;
    };
  return 1 if($@);
} 


=head2 synch_with_nodes

Synchronizes with the nodes written in $APIIS_LOCAL/etc/synchrc file according to the schedule.

=cut

sub synch_with_nodes {
  my $conf_ref=shift;
  my $nodename;
  foreach $nodename (keys %$conf_ref) {
    next if ($nodename eq 'server_uptime');
    my $nodename_uc= uc $nodename;
    system("client.pl $psswd $modelname $nodename_uc &") if (uptime($$conf_ref{$nodename}));
  }
}


=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>

=cut
