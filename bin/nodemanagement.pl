#!/usr/bin/env perl 

=head1 NAME

       nodemanagement.pl

=head1 SYNOPSIS

       nodemanagement.pl <password file> <model_name> 


=head1 DESCRIPTION

       This is the Tk GUI frontend for managing the synchronization process

=cut


use Tk;
require Tk::BrowseEntry;
require Tk::ROText;
require Tk::ProgressBar;
require Tk::MListbox;
require Tk::FileSelect;

BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use warnings;
use strict;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.48 $' );


use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Net::EasyTCP;
use Apiis::DataBase::Sync::Node;
use FileHandle;
use apiis_alib;
use Apiis::DataBase::User;

my $psswd=$ARGV[0];
my $modelname=$ARGV[-1];
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
my $date="01.09.2004";

my $nodename=$apiis->node_name;
my $servername=$nodename;
my ($logging, $log_folder)=read_conf();
my $node=Apiis::DataBase::Sync::Node->new(
					  nodename=>$apiis->node_name,
					  class_column=>'owner',
					  logging=>$logging
					 );
my $nodeip=$node->name2ip($nodename);
$node->debug(1); #high-level of debuging is 7 with more output on the console
if ($node->status) {
  foreach ($node->errors) {
    $_->print;
  }
  die "Critical error! The program cannot continue!\n";
}


my  @columns=();
my  $selected=0;
my  @tcolumns=();
my  $tselected=0;
my  @mtcolumns=();
my  $mtselected=0;
my  @mscolumns=();
my  $msselected=0;

my ($mainnode,$mainsrc,$maintrg,$mainroute,$srcname,$class_name,$table_name,$src_name,$ttable_name,$tclass_name,$trg_name,$columnslist,$tcolumnslist,$node_name,$node_ip,$node_guid,$origguid,$torigguid);
my ($node_name_entry,$tclasslist,$tablelist,$ttablelist,$node_ip_entry,$classlist,$srcnodelist,$trgnodelist,$nodelist,$updatebtn,$tupdatebtn,$servstat,$percent_done,$fh);
my ($mainmultitrg,$mtrg_name,$mtclass_names,$mttable_name,$mtrgnodelist,$mttablelist,$mtclasslist,$mtcolumnslist,$mtinsertbtn,$tclasses);
my ($mainmultisrc,$msrc_name,$msclass_names,$mstable_name,$msrcnodelist,$mstablelist,$msclasslist,$mscolumnslist,$msinsertbtn,$sclasses);
my $backcolor='light steel blue';
my $menucolor='light blue';
my $framecolor='light steel blue';
my $menuactive='cyan';
my $menutext='gray23';
my $main=MainWindow->new();

$main->minsize(qw(340 250));
$main->title("Node management");
$main->configure(-background=>$backcolor);


my $menu_bar=$main->Frame(
			  -relief=>'groove',
			  -borderwidth=>3,
			  -background=>$menucolor,
			 )->pack(-side=>'top',-fill=>'x');


my $synch_mb=$menu_bar->Menubutton( 
				    -text=>'Synchronization',
                                    -underline=>0,
				    -background=>$menucolor,
				    -activebackground=>$menuactive,
				    -foreground=>$menutext,
				   )->pack(-side=>'left');

$synch_mb->command(
		    -label=>'Start',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&doit
		   );

$synch_mb->separator(
		     -background=>$menucolor,
		     -foreground=>$menutext,
		     -activebackground=>$menuactive
		    );

$synch_mb->command(
		    -label=>'Exit',
                    -underline=>1,	
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>sub{$main->destroy}
		   );




my $server_mb=$menu_bar->Menubutton( 
				    -text=>'Server',
                                    -underline=>2,
				    -background=>$menucolor,
				    -activebackground=>$menuactive,
				    -foreground=>$menutext,
				   )->pack(-side=>'left');



$server_mb->command(
		    -label=>'Start',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>sub{system("$APIIS_HOME/bin/server.pl -w $psswd -p $modelname &"); $servstat="Starting server"; }
		   );

$server_mb->command(
		    -label=>'Stop',
                    -underline=>1,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&stop_server
		   );

$server_mb->command(
		    -label=>'Ping',
                    -underline=>1,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&ping_server
		   );


my $settings_mb=$menu_bar->Menubutton( 
				    -text=>'Settings',
                                    -underline=>2,
				    -background=>$menucolor,
				    -activebackground=>$menuactive,
				    -foreground=>$menutext,
				   )->pack(-side=>'left');

$settings_mb->command(
		    -label=>'Sources',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&sources,
		   );

$settings_mb->command(
		    -label=>'Targets',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&targets,
		   );

$settings_mb->command(
		    -label=>'Nodes',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&nodes
		   );

$settings_mb->command(
		    -label=>'Multiclass Source',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&multiclass_sources,
		   );

$settings_mb->command(
		    -label=>'Multiclass Target',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&multiclass_targets,
		   );

$settings_mb->command(
		    -label=>'Dump to file',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&dump_tables
		   );

$settings_mb->command(
		    -label=>'Load from dump',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&load_dump
		   );

$settings_mb->command(
		    -label=>'Check route integrity',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&route_check
		   );

my $help_mb=$menu_bar->Menubutton( 
				    -text=>'Help',
                                    -underline=>0,
				    -background=>$menucolor,
				    -activebackground=>$menuactive,
				    -foreground=>$menutext,
				   )->pack(-side=>'right');


$help_mb->command(
		    -label=>'About',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=>\&help
		   );

$help_mb->command(
		    -label=>'Help',
                    -underline=>0,
		    -background=>$menucolor,
		    -foreground=>$menutext,
		    -activebackground=>$menuactive,
		    -command=> sub {my $browser=$apiis->browser; system(" $browser $APIIS_HOME/doc/implementer/synchronization/node_management/management_help.html &")}
		   );


# frame1
#my $frame1;
my $frame1 = $main->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                     ->pack(-side=>'top',-fill=>'none',-expand=>0, -pady=>3,-ipady=>5);
$frame1->Label( -text=>'Synchronize with node',-bg=>$backcolor
            )->pack(-side=>'top');

my $server_nodelist = $frame1->BrowseEntry(-variable => \$servername,
					 -state =>  'readonly',
					 -listcmd=>\&load_nodes,
					)->pack(-side => 'top',-padx=>77);
$server_nodelist->configure(-background=>$backcolor);

# frame2
my $frame2 = $main->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                     ->pack(-side=>'top',-fill=>'none',-expand=>0, -pady=>3,-ipady=>5);
$frame2->Label( -text=>'System information',-bg=>$backcolor
            )->pack(-side=>'top');

my $eventpad = $frame2->Scrolled(
                'ROText',
                -scrollbars => 'e',
                -width => 40,
                -height => 5,
                )->pack(-side => 'top', -padx => 10);

# frame3
my $frame3 = $main->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                     ->pack(-side=>'top',-fill=>'none',-expand=>0, -pady=>3,-ipady=>5,-ipadx=>12);
$frame3->Label( -text => 'Progress',-bg=>$backcolor
                )->pack(-side => 'top', -padx => 10);

        # the progressbar itself
my $pframe = $frame3->Frame(-relief=>'sunken',-borderwidth=>2)
                           ->pack(-side=>'top');

			   #$percent_done=10;
my $progress = $pframe->ProgressBar(
                -width => 12,
                -length => 300,
                -from => 0,
                -to => 100,
                -gap => 1,
                -blocks=>100,
                -variable => \$percent_done,
                # green color, from 70% on yellow, ...
                -colors => [0, 'SlateBlue4',25,'SlateBlue3',50,'SlateBlue2',75,'SlateBlue1'],
                )->pack( -side => 'top');


my $frame4 = $main->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                     ->pack(-side=>'top',-fill=>'none',-expand=>0, -pady=>3,-ipady=>5,-ipadx=>90);
$frame4->Label( -text=>'Server status',-bg=>$backcolor
            )->pack(-side=>'top');

my $serverstatentry=$frame4->Entry( -textvariable=>\$servstat)->pack(-side=>'top');

MainLoop();

=head2 read_conf

       Parses the information from the local /etc/synchrc file for logging

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

       Wrapper, which calls the 'synchclient' subroutine for synchronization and writes the errors in the log file

=cut
sub doit {

  $percent_done=0;
  $fh = new FileHandle;  
  my $log_file=$log_folder."client_".$apiis->today.".log";
  if ($logging) {
    $fh->open(">>$log_file") || print "Cannot create log file\n";
  }

  my $errobj_ref=synchclient($node,$servername);

  if (defined $errobj_ref) {
    foreach my $err (@$errobj_ref) {
      my $logtext=sprintf "%s: %s  ERROR:  %s\n",$apiis->now,$err->severity, $err->msg_long;
      $node->print_log($fh,$logtext);
      $eventpad->insert('end',$logtext);
      $eventpad->see('end');
    }
    $fh->close if $logging;
    #exit(1);
  }
  $percent_done=100; 
  $fh->close if $logging;
}


=head2 synchclient

       Creates the TCP/IP client and synchronizes with the desired server.
       input: client_node_obj, server_name

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
  my $logtext="";
  my $total_dbmerge_time=0;
  my $total_receivemerge_time=0;
  my $dbmerge_time=0;
  my $receivemerge_time=0;
  my ($begintime,$t0,$readstate_time,$sendstate_time,$alltime,$reply);
  my $host=$node->name2ip($servernode);
  $logtext="Synchronization with node: $servernode on host: $host started";
  $node->print_log($fh,$logtext);
  $eventpad->insert('end',$logtext."\n");
  $eventpad->see('end');
  $main->update;
  $begintime=[gettimeofday];
  $node->read_DED($servernode,'source');
  if ($node->status) {
    return $node->errors;
  }
  $logtext='Source information read';
  $node->print_log($fh,$logtext);
  $eventpad->insert('end',$logtext."\n");
  $eventpad->see('end');
  $main->update;
  my $client=$node->create_client($host,'5433');
  return $node->errors if ($node->status);
  $node->print_log($fh, $client->compression) if $node->debug>6; #jiji
  $node->print_log($fh, $client->encryption) if $node->debug>6; #jiji
  $logtext='Connection created';
  $node->print_log($fh,$logtext);
  $eventpad->insert('end',$logtext."\n");
  $eventpad->see('end');
  $main->update;


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
  $logtext="Server replied $reply";
  $node->print_log($fh,$logtext);
  $eventpad->insert('end',$logtext."\n");
  $eventpad->see('end');
  $main->update;
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
    $logtext='Connection closed';
    $node->print_log($fh,$logtext);
    $eventpad->insert('end',$logtext."\n");
    $eventpad->see('end');
    $main->update;
  } elsif ($reply eq "FREE")  {

    foreach my $DED (@{$node->sources_DED}) {
      eval {
	use Data::Dumper;
	print Dumper($DED) if $node->debug>6;
	$client->send({'DED'=>$DED});
	$logtext='Data element description sent';
	$node->print_log($fh,$logtext);
	$eventpad->insert('end',$logtext."\n");
	$eventpad->see('end');
	$main->update;
	$reply = $client->receive();
	die "DED ($$DED[0]) refused by server" if (not(defined $reply) or ($reply ne "OK"));
	$logtext='Data element description confirmed';
	$node->print_log($fh,$logtext);
	$eventpad->insert('end',$logtext."\n");
	$eventpad->see('end');
	$main->update;
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
      $readstate_time=tv_interval($t0);
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
	$sendstate_time=tv_interval($t0);
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
	$node->print_log($fh,'Awaiting response from the server');
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
      while ((ref($reply) eq 'ARRAY') and ($$reply[0] ne "END")) {
	$dbmerge_time=0;
	$receivemerge_time=0;
	if ($$reply[0] eq "RCNT") {
	  $countall=$$reply[1];
	  $logtext="Expected $countall merge records from the server";
	  $node->print_log($fh,$logtext);
	  $eventpad->insert('end',$logtext."\n");
	  $eventpad->see('end');
	  $main->update;
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
	    $logtext="$received elements received";
	    $node->print_log($fh,$logtext) if $node->debug>5;
	    $eventpad->insert('end',$logtext."\n");
	    $eventpad->see('end');
	    $main->update;
	  };
	} else {
	  $logtext="ERROR:  Unrecognized response from the server!";
	  $node->print_log($fh,$logtext);
	  $eventpad->insert('end',$logtext."\n");
	  $eventpad->see('end');
	  $main->update;
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
	    return [$err_obj];
	  };
	  $logtext='Connection closed';
	  $node->print_log($fh,$logtext);
	  $eventpad->insert('end',$logtext."\n");
	  $eventpad->see('end');
	  $main->update;
	  exit;
	}
      }#end while loop
      $insertall +=$insert;
      $updateall +=$update;
      $deleteall +=$delete;
      $logtext="$insert records inserted, $update records updated, $delete records deleted";
      $node->print_log($fh,$logtext);
      $eventpad->insert('end',$logtext."\n");
      $total_dbmerge_time+=$dbmerge_time;
      $total_receivemerge_time+=$receivemerge_time;
      $logtext="Time elapsed in receiving merge data: $receivemerge_time";
      $node->print_log($fh,$logtext);
      $eventpad->insert('end',$logtext."\n");
      $logtext="Time elapsed in updating database: $dbmerge_time";
      $node->print_log($fh,$logtext);	
      $eventpad->insert('end',$logtext."\n");
      $eventpad->see('end');
      $main->update;
    } #end foreach
    $apiis->DataBase->sys_dbh->commit;
    return $apiis->errors if($apiis->status);
    $logtext="Total time elapsed in receiving merge data: $total_receivemerge_time";
    $node->print_log($fh,$logtext);
    $eventpad->insert('end',$logtext."\n");
    $logtext="Total time elapsed in updating database: $total_dbmerge_time";
    $node->print_log($fh,$logtext );	
    $eventpad->insert('end',$logtext."\n");
    $logtext="Database updated: Total $insertall records inserted, $updateall records updated, $deleteall records deleted";
    $node->print_log($fh,$logtext);
    $eventpad->insert('end',$logtext."\n");
    $eventpad->see('end');
    $main->update;
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
    $logtext='Connection closed';
    $node->print_log($fh,$logtext);
    $eventpad->insert('end',$logtext."\n");
    $eventpad->see('end');
    $main->update;
  }
  $logtext='Synchronization finished';
  $node->print_log($fh,$logtext);
  $eventpad->insert('end',$logtext."\n");
  $alltime=tv_interval($begintime);
  $logtext="Total synchronization time: $alltime";
  $node->print_log($fh,$logtext);
  $eventpad->insert('end',$logtext."\n");
  $eventpad->see('end');
  $main->update;
  return undef;
}

=head2 help

       Creates and shows 'About' window for the program

=cut
sub help {

   warnwin($main,
      'About Node Management',
      $main->Pixmap(-file=>"$APIIS_HOME/lib/images/sync.xpm"),
      "Node Management\n\n".
      "by Zhivko Duchev\n\n".
      "version: $version\n$date\n\n".
      " -------------------\n\n".
      "Special thanks to:\n".
      "  Hartmut Boerner\n".
      "  Helmut Lichtenberg\n".
      "  Detlef Schulze\n".
      "for the support".
      " ",
      ['Close']);
}

=head2 sources

       Manages the data sources information. For more detail see the synchronization documentation or the HTML help

=cut
sub sources {

  if (! Exists($mainsrc)) {
    $src_name='';
    $class_name='';
    $table_name='';
    $mainsrc=$main->Toplevel();
    $mainsrc->minsize(qw(450 250));
    $mainsrc->title("Sources management");
    $mainsrc->configure(-background=>$backcolor);

    my $frame = $mainsrc->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                     ->pack(-side=>'top',-padx=>5,-pady=>5,-anchor=>'s');
    my $frame1 = $frame->Frame(-relief=>'groove',-borderwidth=>0,-bg=>$framecolor)
                     ->pack(-side=>'left',-padx=>5,-fill=>"y",-expand=>1,-pady=>5);
    $srcnodelist = $frame1->BrowseEntry(-variable => \$src_name,
	                               -bg=>$framecolor,
	                               -label=>"Source node ",
				       -state =>  'readonly',
				       -listcmd=>\&load_nodes,
                                       -browsecmd=>\&refresh_columns_list,
		                      )->pack(-side=>'top',-anchor=>'e',-pady=>5,-padx=>5);
    $tablelist = $frame1->BrowseEntry(-variable => \$table_name,
	                               -bg=>$framecolor,
	                               -label=>"Table ",
				       -state =>  'readonly',
				       -listcmd=>\&load_tables,
				       -browsecmd=>\&refresh_columns_list,
				      )->pack(-side=>'top',-anchor=>'e',-pady=>5,-padx=>5);
    $classlist = $frame1->BrowseEntry(-variable => \$class_name,
	                               -bg=>$framecolor,
	                               -label=>"Class ",
				       -state =>  'readonly',
				       -listcmd=>\&load_classes,
				       -browsecmd=>\&refresh_columns_list,
				      )->pack(-side=>'top',-anchor=>'e',-pady=>5,-padx=>5);

    my $frame2 = $frame->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                     ->pack(-side=>'right',-padx=>0,-pady=>5);
    $frame2->Label( -text=>'Columns'
		   )->pack(-side=>'top',-fill=>'x',-expand=>1);
    $columnslist=$frame2->Scrolled( "Listbox",
				     -scrollbars=>"e",
				     -selectmode=>"extended",
				      -exportselection=>0,
				   )->pack(-side => 'left');
    $updatebtn=$frame1->Button(-text=>"UPDATE",
				-command=>\&update_source,
				)->pack(-side => 'bottom',-fill=>'x',-expand=>1,-anchor=>'s');
    my $closebtn=$mainsrc->Button(-text=>"Close",
				  -command=>sub{$mainsrc->destroy}
				 )->pack(-side=>'top',-fill=>'x',-expand=>1,-anchor=>'s',-padx=>1);

  } else {
    $mainsrc->deiconify();
    $mainsrc->raise();
  }
}

=head2 targets

       Manages the data targets information. For more detail see the synchronization documentation or the HTML help

=cut
sub targets {
  if (! Exists($maintrg)) {
    $trg_name='';
    $tclass_name='';
    $ttable_name='';
    $maintrg=$main->Toplevel();
    $maintrg->minsize(qw(450 250));
    $maintrg->title("Targets management");
    $maintrg->configure(-background=>$backcolor);

    my $frame = $maintrg->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                          ->pack(-side=>'top',-padx=>5,-pady=>5,-anchor=>'s');
    my $frame1 = $frame->Frame(-relief=>'groove',-borderwidth=>0,-bg=>$framecolor)
                          ->pack(-side=>'left',-padx=>5,-fill=>"y",-expand=>1,-pady=>5);
    $trgnodelist = $frame1->BrowseEntry(-variable => \$trg_name,
	                                -bg=>$framecolor,
					-label=>" Target node ",
					-state =>  'readonly',
					-listcmd=>\&load_nodes,
					-browsecmd=>\&trefresh_columns_list,
					)->pack(-side => 'top',-anchor=>'e',-pady=>5,-padx=>5);
    $ttablelist = $frame1->BrowseEntry(-variable => \$ttable_name,
	                                -bg=>$framecolor,
					-label=>"Table ",
				        -state =>  'readonly',
				        -listcmd=>\&load_tables,
				        -browsecmd=>\&trefresh_columns_list,
					)->pack(-side => 'top',-anchor=>'e',-pady=>5,-padx=>5);
    $tclasslist = $frame1->BrowseEntry(-variable => \$tclass_name,
	                                -bg=>$framecolor,
					-label=>"Class ",
					-state =>  'readonly',
					-listcmd=>\&load_classes,
					-browsecmd=>\&trefresh_columns_list,
					)->pack(-side => 'top',-anchor=>'e',-pady=>5,-padx=>5);
    my $frame2 = $frame->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                              ->pack(-side=>'right',-padx=>0,-pady=>5);
    $frame2->Label( -text=>'Columns'
		   )->pack(-side=>'top',-fill=>'x',-expand=>1);
    $tcolumnslist=$frame2->Scrolled( "Listbox",
				      -scrollbars=>"e",
				      -selectmode=>"extended",
				      -exportselection=>0,
				    )->pack(-side => 'left');
    $tupdatebtn=$frame1->Button(-text=>"UPDATE",
				 -command=>\&update_target,
				)->pack(-side => 'bottom',-fill=>'x',-expand=>1,-anchor=>'s');
    my $tclosebtn=$maintrg->Button(-text=>"Close",
				   -command=>sub{$maintrg->destroy}
				  )->pack(-side=>'top',-fill=>'x',-expand=>1,-anchor=>'s',-padx=>1);

  } else {
    $maintrg->deiconify();
    $maintrg->raise();
  }
}


=head2 multiclass_sources

       Inserts the data sources information when same data is imported for multiple classes. 

=cut
sub multiclass_sources {
  if (! Exists($mainmultisrc)) {
    $sclasses=get_classes();
    $msrc_name='';
    $msclass_names='';
    $mstable_name='';
    $mainmultisrc=$main->Toplevel();
    $mainmultisrc->minsize(qw(450 250));
    $mainmultisrc->title("Inserting source data for multiple classes");
    $mainmultisrc->configure(-background=>$backcolor);

    my $frame = $mainmultisrc->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
      ->pack(-side=>'top',-padx=>5,-pady=>5,-anchor=>'s');
    my $frame1 = $frame->Frame(-relief=>'groove',-borderwidth=>0,-bg=>$framecolor)
      ->pack(-side=>'left',-padx=>5,-fill=>"y",-expand=>1,-pady=>5);
    $msrcnodelist = $frame1->BrowseEntry(-variable => \$msrc_name,
	                                -bg=>$framecolor,
					-label=>" Source node ",
					-state =>  'readonly',
					-listcmd=>\&load_nodes,
					)->pack(-side => 'top',-anchor=>'e',-pady=>5,-padx=>5);
    $mstablelist = $frame1->BrowseEntry(-variable => \$mstable_name,
	                                -bg=>$framecolor,
					-label=>"Table ",
				        -state =>  'readonly',
				        -listcmd=>\&load_tables,
					-browsecmd=>\&msrefresh_columns_list,
					)->pack(-side => 'top',-anchor=>'e',-pady=>5,-padx=>5);
    my $frame3 = $frame1->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                              ->pack(-side=>'right',-padx=>0,-pady=>5);
    $frame3->Label( -text=>'Classes'
		   )->pack(-side=>'top',-fill=>'x',-expand=>1);
    $msclasslist = $frame3->Scrolled("Listbox",
				     -scrollbars=>"e",
				     -selectmode=>"extended",
				     -exportselection=>0,
				     -height=>6,
				     -listvariable=>\$sclasses,
				    )->pack(-side => 'left');
    my $frame2 = $frame->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                              ->pack(-side=>'right',-padx=>0,-pady=>5);
    $frame2->Label( -text=>'Columns'
		   )->pack(-side=>'top',-fill=>'x',-expand=>1);
    $mscolumnslist=$frame2->Scrolled( "Listbox",
				      -scrollbars=>"e",
				      -selectmode=>"extended",
				      -exportselection=>0,
				    )->pack(-side => 'left');
    $msinsertbtn=$mainmultisrc->Button(-text=>"INSERT",
				       -command=>\&insert_msource,
				      )->pack(-side => 'left',-fill=>'y',-expand=>0,-anchor=>'s');
    my $tclosebtn=$mainmultisrc->Button(-text=>"Close",
					-command=>sub{$mainmultisrc->destroy}
				       )->pack(-side=>'right',-fill=>'y',-expand=>0,-anchor=>'s',-padx=>1);

  } else {
    $mainmultisrc->deiconify();
    $mainmultisrc->raise();
  }
}



=head2 multiclass_targets

       Inserts the data targets information when same data is exported for multiple classes. 

=cut
sub multiclass_targets {
  if (! Exists($mainmultitrg)) {
    $tclasses=get_classes();
    $mtrg_name='';
    $mtclass_names='';
    $mttable_name='';
    $mainmultitrg=$main->Toplevel();
    $mainmultitrg->minsize(qw(450 250));
    $mainmultitrg->title("Inserting target data for multiple classes");
    $mainmultitrg->configure(-background=>$backcolor);

    my $frame = $mainmultitrg->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                          ->pack(-side=>'top',-padx=>5,-pady=>5,-anchor=>'s');
    my $frame1 = $frame->Frame(-relief=>'groove',-borderwidth=>0,-bg=>$framecolor)
                          ->pack(-side=>'left',-padx=>5,-fill=>"y",-expand=>1,-pady=>5);
    $mtrgnodelist = $frame1->BrowseEntry(-variable => \$mtrg_name,
	                                -bg=>$framecolor,
					-label=>" Target node ",
					-state =>  'readonly',
					-listcmd=>\&load_nodes,
					)->pack(-side => 'top',-anchor=>'e',-pady=>5,-padx=>5);
    $mttablelist = $frame1->BrowseEntry(-variable => \$mttable_name,
	                                -bg=>$framecolor,
					-label=>"Table ",
				        -state =>  'readonly',
				        -listcmd=>\&load_tables,
					-browsecmd=>\&mtrefresh_columns_list,
					)->pack(-side => 'top',-anchor=>'e',-pady=>5,-padx=>5);
    my $frame3 = $frame1->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                              ->pack(-side=>'right',-padx=>0,-pady=>5);
    $frame3->Label( -text=>'Classes'
		   )->pack(-side=>'top',-fill=>'x',-expand=>1);
    $mtclasslist = $frame3->Scrolled("Listbox",
				     -scrollbars=>"e",
				     -selectmode=>"extended",
				     -exportselection=>0,
				     -height=>6,
				     -listvariable=>\$tclasses,
				    )->pack(-side => 'left');
    my $frame2 = $frame->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                              ->pack(-side=>'right',-padx=>0,-pady=>5);
    $frame2->Label( -text=>'Columns'
		   )->pack(-side=>'top',-fill=>'x',-expand=>1);
    $mtcolumnslist=$frame2->Scrolled( "Listbox",
				      -scrollbars=>"e",
				      -selectmode=>"extended",
				      -exportselection=>0,
				    )->pack(-side => 'left');
    $mtinsertbtn=$mainmultitrg->Button(-text=>"INSERT",
				       -command=>\&insert_mtarget,
				      )->pack(-side => 'left',-fill=>'y',-expand=>0,-anchor=>'s');
    my $tclosebtn=$mainmultitrg->Button(-text=>"Close",
				   -command=>sub{$mainmultitrg->destroy}
				  )->pack(-side=>'right',-fill=>'y',-expand=>0,-anchor=>'s',-padx=>1);

  } else {
    $mainmultitrg->deiconify();
    $mainmultitrg->raise();
  }
}

=head2 nodes

       Manages the nodes names and addresses. For more detail see the synchronization documentation or the HTML help

=cut
sub nodes {
  if (! Exists($mainnode)) {
    $node_name='';
    $node_ip='';
    $node_guid=0;  ;
    $mainnode=$main->Toplevel();
    $mainnode->minsize(qw(450 250));
    $mainnode->title("Nodes management");
    $mainnode->configure(-background=>$backcolor);
    my $frame = $mainnode->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                              ->pack(-side=>'top',-padx=>5,-pady=>5,-anchor=>'s');
    my $frame1=$frame->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                              ->pack(-side=>'left');
    $nodelist=$frame1->Scrolled("MListbox",
			       -height=>11,
			       -width=>230,
			       -resizeable=>0,
			       -columns=>[[-text=>'Record number',
					   -sortable=>0,
					  -textwidth=>14],
					  [-text=>'Node name',
					   -textwidth=>10],
					  [-text=>'Node address',
					   -textwidth=>20]],
			       -scrollbars=>'oe',
			      )->pack(-side=>'top');
    $nodelist->columnHide(0);
    $nodelist->bindRows('<Button-1>',\&set_node_vars);
    refresh_node_list(\$nodelist);

    my $frame2=$frame->Frame(-relief=>'groove',-borderwidth=>0,-bg=>$framecolor)
                              ->pack(-side=>'left',-fill=>'x',-expand=>1,-anchor=>'s');
    $frame2->Label( -text=>'Node name',-bg=>$framecolor)
		    ->pack(-side=>'top');

    $node_name_entry=$frame2->Entry(-textvariable=>\$node_name)->pack(-side=>'top');

    $frame2->Label( -text=>'Node IP address',-bg=>$framecolor)
		    ->pack(-side=>'top');

    $node_ip_entry=$frame2->Entry(-textvariable=>\$node_ip)->pack(-side=>'top');

    my $newbtn=$frame2->Button(-text=>"New",
				 -command=>[\&clear_node_vars,\$nodelist],
				)->pack(-side => 'left');
    my $updatebtn=$frame2->Button(-text=>"Save",
				   -command=>\&change_record,
				  )->pack(-side => 'left',-pady=>10);

    my $deletebtn=$frame2->Button(-text=>"Delete",
				   -command=>\&delete_record,
				  )->pack(-side => 'left',-pady=>10);

    my $closebtn=$mainnode->Button(-text=>"Close",
				    -command=>sub{$mainnode->destroy}
				   )->pack(-side=>'top',-fill=>'x',-expand=>1);
  } else {
    $mainnode->deiconify();
    $mainnode->raise();
  }
}

=head2 set_node_vars

       Sets the  node name, address and guid of the record based on the current selection from the list

=cut
sub set_node_vars {
  my $caller=shift;
  my $selected_row=$caller->curselection();
  my @selected=$caller->getRow($selected_row);
  $node_name=$selected[1];
  $node_ip=$selected[2];
  $node_guid=$selected[0];
}

=head2 clear_node_vars

       Clears the current selection and resets teh node name, address and record guid

=cut
sub clear_node_vars {
  my $caller_ref=shift;
  ${$caller_ref}->selectionClear(0,'end');
  $node_name='';
  $node_ip='';
  $node_guid=0;
}

=head2 refresh_node_list

       Refreshes the nodes drop-down list from the current database values

=cut
sub refresh_node_list {
  my $caller_ref= shift;
  ${$caller_ref}->delete(0,'end');
  my $sqltext="SELECT guid,nodename,address FROM nodes ORDER BY nodename";
  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
  if ($sql_ref->status) {
    my $err_msg=${$sql_ref->errors}[-1]->msg_short;
    MsgBox($mainnode,$err_msg,"Error");
    return;
  }
  my @result=();
  while (@result=$sql_ref->handle->fetchrow_array) {
    ${$caller_ref}->insert('end',\@result);
  }
}


=head2 change_record

       Inserts new record into table nodes or update existing one with the data from the nodes form

=cut
sub change_record {
  my $sqltext='';
  my $actiontext='';
  unless ($node_name and $node_ip) {
    MsgBox($mainnode,"Enter node name","Error") unless ($node_name);
    MsgBox($mainnode,"Enter node ip address","Error") unless ($node_ip);
    return;
  }
  if ($node_guid) {
    $sqltext=sprintf "UPDATE nodes SET nodename='$node_name', address='$node_ip', last_change_dt='%s', last_change_user='%s' WHERE guid=$node_guid",$apiis->now, $apiis->User->id;
    $actiontext="Record $node_guid updated.";
  } else {
    $sqltext=sprintf "INSERT INTO nodes (guid,nodename,address,owner,version,last_change_dt,last_change_user) VALUES (nextval('seq_database__guid'),'$node_name','$node_ip','%s',1,'%s','%s')",$apiis->node_name, $apiis->now, $apiis->User->id;
    $actiontext="New record inserted.";
  }
  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
  if ($sql_ref->status) {
    $apiis->DataBase->sys_dbh->rollback;
    my $err_msg=${$sql_ref->errors}[-1]->msg_short;
    MsgBox($mainnode,$err_msg,"Error");
  } else {
    $apiis->DataBase->sys_dbh->commit;
    MsgBox($mainnode,"Table 'Nodes' changed! ".$actiontext,"Information");
    refresh_node_list(\$nodelist);
    $node->_loadnodes();
  }
}

=head2 delete_record

       Deletes record from table nodes

=cut
sub delete_record {
  my $sqltext='';
  my $actiontext='';
  if ($node_guid) {
    $sqltext="DELETE FROM nodes WHERE guid=$node_guid";
    $actiontext="Record $node_guid deleted.";
    my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
    if ($sql_ref->status) {
      $apiis->DataBase->sys_dbh->rollback;
      my $err_msg=${$sql_ref->errors}[-1]->msg_short;
      MsgBox($mainnode,$err_msg,"Error");
    } else {
      $apiis->DataBase->sys_dbh->commit;
      $node_guid=0;
      MsgBox($mainnode,"Table 'Nodes' changed! ".$actiontext,"Information");
      refresh_node_list(\$nodelist);
      $node->_loadnodes();
    }
  } else {
    MsgBox($mainnode,"You have to select at least one node!","Error");
  }
}

=head2 refresh_columns_list

       Refreshes sources columns drop-down list from the current database values

=cut
sub refresh_columns_list {

  untie @columns;
  untie $selected;
  tie @columns, "Tk::Listbox", $columnslist;
  tie $selected, "Tk::Listbox", $columnslist;
  if ((defined $table_name) and ($table_name ne '')) {
    my $table_ref=$apiis->Model->table($table_name);
    @columns=sort ($table_ref->cols);
    for(my $i=0;$i<@columns;$i++) {
      delete $columns[$i] if ($columns[$i] eq 'guid');
    }
    my $sqltext="SELECT guid,columnnames FROM sources WHERE source='$src_name' AND tablename='$table_name' AND class='$class_name' ";
    my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
    my @slist=();
    $origguid=0;
    unless ($sql_ref->status) {
      my @result=$sql_ref->handle->fetchrow_array;
      if (@result) {
	@slist=split(',', $result[1]);
	$origguid=$result[0];
      }
      $selected=\@slist;
    }
  }
}


=head2 trefresh_columns_list

       Refreshes targets drop-down list from the current database values

=cut
sub trefresh_columns_list {
  untie @tcolumns;
  untie $tselected;
  tie @tcolumns, "Tk::Listbox", $tcolumnslist;
  tie $tselected, "Tk::Listbox", $tcolumnslist;
  if ((defined $ttable_name) and ($ttable_name ne '')) {
    my $table_ref=$apiis->Model->table($ttable_name);
    @tcolumns=sort ($table_ref->cols);
    for(my $i=0;$i<@tcolumns;$i++) {
      delete $tcolumns[$i] if ($tcolumns[$i] eq 'guid');
    }
    my $sqltext="SELECT guid,columnnames FROM targets WHERE target='$trg_name' AND tablename='$ttable_name' AND class='$tclass_name' ";
    my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
    my @tlist=();
    $torigguid=0;
    unless ($sql_ref->status) {
      my @result=$sql_ref->handle->fetchrow_array;
      if (@result) {
	@tlist=split(',', $result[1]);
	$torigguid=$result[0];
      }
      $tselected=\@tlist;
    }
  }
}


=head2 msrefresh_columns_list

       Refreshes targets drop-down list from the current database values

=cut
sub msrefresh_columns_list {
  untie @mscolumns;
  untie $msselected;
  tie @mscolumns, "Tk::Listbox", $mscolumnslist;
  tie $msselected, "Tk::Listbox", $mscolumnslist;
  if ((defined $mstable_name) and ($mstable_name ne '')) {
    my $table_ref=$apiis->Model->table($mstable_name);
    @mscolumns=sort ($table_ref->cols);
    for(my $i=0;$i<@mscolumns;$i++) {
      delete $mscolumns[$i] if ($mscolumns[$i] eq 'guid');
    }
  }
}


=head2 mtrefresh_columns_list

       Refreshes targets drop-down list from the current database values

=cut
sub mtrefresh_columns_list {
  untie @mtcolumns;
  untie $mtselected;
  tie @mtcolumns, "Tk::Listbox", $mtcolumnslist;
  tie $mtselected, "Tk::Listbox", $mtcolumnslist;
  if ((defined $mttable_name) and ($mttable_name ne '')) {
    my $table_ref=$apiis->Model->table($mttable_name);
    @mtcolumns=sort ($table_ref->cols);
    for(my $i=0;$i<@mtcolumns;$i++) {
      delete $mtcolumns[$i] if ($mtcolumns[$i] eq 'guid');
    }
  }
}



=head2 update_source

       Inserts, deletes or updates record in table sources

=cut
sub update_source {
  my ($caller)=@_;
  my $curselection=$selected;
  my $sqltext='';
  my $actiontext='';
  my $columnnames;
  my $now=$apiis->now;
  my $user=$apiis->User->id;
  my $status=0;
  my $updateflag=0;
  my $sql_ref;
  my $err_msg;
  $columnnames=join(',',@$curselection)if (ref $curselection eq 'ARRAY' );
  if ($origguid) {
    if ($columnnames) {
      $sqltext="UPDATE sources SET source='$src_name', tablename='$table_name',class='$class_name', columnnames='$columnnames',last_change_dt='$now',last_change_user='$user',version=version+1 WHERE guid=$origguid";
      $actiontext="Record $origguid updated.";
      $updateflag=1;
    } else {
      $sqltext="DELETE FROM sources where guid=$origguid";
      $actiontext="Record $origguid deleted.";
    }
  } else {
    if($columnnames and $class_name and $src_name) {
      $sqltext=sprintf "INSERT INTO sources (guid,source,tablename,class,columnnames,last_change_dt,last_change_user,version,owner) VALUES(%s,'$src_name','$table_name','$class_name','$columnnames','$now','$user',1,'$nodename')",$apiis->DataBase->seq_next_val('seq_database__guid');
      $actiontext="New record inserted.";
    } else {
      $err_msg="You have to select at least one column!" unless ($columnnames);
      $err_msg="You have to select table!" unless ($table_name);
      $err_msg="You have to select the source node!" unless ($src_name);
      $err_msg="You have to select class!" unless ($class_name);
      $status=1;
    }
  }
  print "$sqltext\n" if $node->debug>6;
  unless ($status) {
    $sql_ref = $apiis->DataBase->sys_sql($sqltext);
    $status=$sql_ref->status if ($sql_ref->status and (${$sql_ref->errors}[-1]->severity ne 'WARNING'));
  }
  if ($status) {
    $apiis->DataBase->sys_dbh->rollback;
    $err_msg=${$sql_ref->errors}[-1]->msg_short unless($err_msg);
    MsgBox($mainsrc,$err_msg,"Error");
  } else {
    if ($updateflag) {
      $sqltext="UPDATE $table_name SET version=0 WHERE owner='$class_name'";
      print "$sqltext\n" if $node->debug>6; 
      my $sql_ref1 = $apiis->DataBase->sys_sql($sqltext);
      my $status1=$sql_ref1->status if ($sql_ref1->status and (${$sql_ref1->errors}[-1]->severity ne 'WARNING'));
      if ($status1) {
	$apiis->DataBase->sys_dbh->rollback;
	my $err_msg1=${$sql_ref1->errors}[-1]->msg_short;
	MsgBox($mainsrc,"Cannot update table $table_name: ".$err_msg1,"Error");
      } else {
	$apiis->DataBase->sys_dbh->commit;
      }
    } else {
      $apiis->DataBase->sys_dbh->commit;
    }
    MsgBox($mainsrc,"Table 'Sources' changed! ".$actiontext,"Information");
    refresh_columns_list();
  }
}


=head2 update_target

       Inserts, deletes or updates record in table targets

=cut
sub update_target {
  my ($caller)=@_;
  my $tcurselection=$tselected;
  my $sqltext='';
  my $actiontext='';
  my $columnnames;
  my $status=0;
  my $sql_ref;
  my $now=$apiis->now;
  my $user=$apiis->User->id;
  my $err_msg;
  $columnnames=join(',',@$tcurselection) if (ref $tcurselection eq 'ARRAY' );
  if ($torigguid) {
    if ($columnnames) {
      $sqltext="UPDATE targets SET target='$trg_name', tablename='$ttable_name',class='$tclass_name', columnnames='$columnnames',last_change_dt='$now',last_change_user='$user',version=version+1 WHERE guid=$torigguid";
      $actiontext="Record $torigguid updated.";
    } else {
      $sqltext="DELETE FROM targets where guid=$torigguid";
      $actiontext="Record $torigguid deleted.";
    }
  } else {
    if($columnnames and $tclass_name and $trg_name) {
      $sqltext="INSERT INTO targets (guid,target,tablename,class,columnnames,last_change_dt,last_change_user,version,owner) VALUES(nextval('seq_database__guid'),'$trg_name','$ttable_name','$tclass_name','$columnnames','$now','$user',1,'$nodename')";
      $actiontext="New record inserted.";
    } else {
      $err_msg="You have to select at least one column!" unless ($columnnames);
      $err_msg="You have to select table!" unless ($ttable_name);
      $err_msg="You have to select the target node!" unless ($trg_name);
      $err_msg="You have to select class!" unless ($tclass_name);
      $status=1;
    }
  }
  print $sqltext if  $node->debug>6;
  unless ($status) {
    $sql_ref = $apiis->DataBase->sys_sql($sqltext);
    $status=$sql_ref->status if ($sql_ref->status and (${$sql_ref->errors}[-1]->severity ne 'WARNING'));
  }
  if ($status) {
    $apiis->DataBase->sys_dbh->rollback;
    $err_msg=${$sql_ref->errors}[-1]->msg_short unless ($err_msg);
    MsgBox($maintrg,$err_msg,"Error");
  } else {
    $apiis->DataBase->sys_dbh->commit;
    MsgBox($maintrg,"Table 'Targets' changed! ".$actiontext,"Information");
    trefresh_columns_list();
  }
}


=head2 insert_msource

       Inserts record(s) in table sources.

=cut
sub insert_msource {
  my ($caller)=@_;
  my $mscurselection=$msselected;
  my $sqltext='';
  my $actiontext='';
  my $columnnames;
  my $status=0;
  my $sql_ref;
  my $now=$apiis->now;
  my $user=$apiis->User->id;
  my $err_msg;
  my $cclass;
  my $cnt=0;
  $columnnames=join(',',@$mscurselection) if (ref $mscurselection eq 'ARRAY' );
  untie $msclass_names;
  tie $msclass_names, "Tk::Listbox", $msclasslist;
  if($columnnames and $msrc_name) {
    foreach $cclass (@$msclass_names) {
      if ($cclass) {
	$cnt++;
	$sqltext="INSERT INTO sources (guid,source,tablename,class,columnnames,last_change_dt,last_change_user,version,owner) VALUES(nextval('seq_database__guid'),'$msrc_name','$mstable_name','$cclass','$columnnames','$now','$user',1,'$nodename')";
	print $sqltext if  $node->debug>6;
	$actiontext="New record(s) inserted.";
	$sql_ref = $apiis->DataBase->sys_sql($sqltext);
	$status=$sql_ref->status if ($sql_ref->status and (${$sql_ref->errors}[-1]->severity ne 'WARNING'));
	last if $status;
      }
    }
    unless ($cnt) {
      $err_msg="You have to select at least one class!";
      $status=1;
    }
  } else {
    $err_msg="You have to select at least one column!" unless ($columnnames);
    $err_msg="You have to select table!" unless ($mstable_name);
    $err_msg="You have to select the source node!" unless ($msrc_name);
    $status=1;
  }
  if ($status) {
    $apiis->DataBase->sys_dbh->rollback;
    $err_msg=${$sql_ref->errors}[-1]->msg_short unless ($err_msg);
    MsgBox($mainmultisrc,$err_msg,"Error");
  } else {
    $apiis->DataBase->sys_dbh->commit;
    MsgBox($mainmultisrc,"Table 'Sources' changed! ".$actiontext,"Information");
  }
}


=head2 insert_mtarget

       Inserts record(s) in table targets

=cut
sub insert_mtarget {
  my ($caller)=@_;
  my $mtcurselection=$mtselected;
  my $sqltext='';
  my $actiontext='';
  my $columnnames;
  my $status=0;
  my $sql_ref;
  my $now=$apiis->now;
  my $user=$apiis->User->id;
  my $err_msg;
  my $cclass;
  my $cnt=0;
  $columnnames=join(',',@$mtcurselection) if (ref $mtcurselection eq 'ARRAY' );
  untie $mtclass_names;
  tie $mtclass_names, "Tk::Listbox", $mtclasslist;
  if($columnnames and $mtrg_name) {
    foreach $cclass (@$mtclass_names) {
      if ($cclass) {
	$cnt++;
	$sqltext="INSERT INTO targets (guid,target,tablename,class,columnnames,last_change_dt,last_change_user,version,owner) VALUES(nextval('seq_database__guid'),'$mtrg_name','$mttable_name','$cclass','$columnnames','$now','$user',1,'$nodename')";
	print $sqltext if  $node->debug>6;
	$actiontext="New record(s) inserted.";
	$sql_ref = $apiis->DataBase->sys_sql($sqltext);
	$status=$sql_ref->status if ($sql_ref->status and (${$sql_ref->errors}[-1]->severity ne 'WARNING'));
	last if $status;
      }
    }
    unless ($cnt) {
      $err_msg="You have to select at least one class!";
      $status=1;
    }
  } else {
    $err_msg="You have to select at least one column!" unless ($columnnames);
      $err_msg="You have to select table!" unless ($mttable_name);
    $err_msg="You have to select the target node!" unless ($mtrg_name);
    $status=1;
  }
  if ($status) {
    $apiis->DataBase->sys_dbh->rollback;
    $err_msg=${$sql_ref->errors}[-1]->msg_short unless ($err_msg);
    MsgBox($mainmultitrg,$err_msg,"Error");
  } else {
    $apiis->DataBase->sys_dbh->commit;
    MsgBox($mainmultitrg,"Table 'Targets' changed! ".$actiontext,"Information");
  }
}


=head2 stop_server

       Stops the local server using 'SD' signal.

=cut
sub stop_server {
  eval {
    my $client = new Net::EasyTCP(
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
} 



=head2 ping_server

       Pings local or remote server using 'PNG' signal.

=cut
sub ping_server {
  eval {
    my $serverip=$node->name2ip($servername);
    print "server >$serverip< name >$servername<\n";
    my $client = new Net::EasyTCP(
				  mode            =>      "client",
				  host            =>      $serverip,
				  port            =>      5433,
				 ) or die;
    $client->send("PNG");
    $servstat=$client->receive(300);
  };
  if($@) {
    $servstat="Not responding: $@";
  }
} 


=head2 warnwin

       Creates dialog box with customized title, picture, buttons.

=cut
sub warnwin {

   my ($fdtop, $title, $bitmap, $text, $buttons) = @_;

   $buttons = ['OK'] if(!$buttons);

   use Tk::Dialog;

   my $d;

   if( ref($bitmap) =~ /Tk::Pixmap/) {
      $d = $fdtop->Dialog(-title=>$title,-bg=>$framecolor,
                          -image=>$bitmap,
                          -font=>'variable',
                          -text=>$text,
                          -buttons=>$buttons);
   } else {
      $d = $fdtop->Dialog(-title=>$title,-bg=>$framecolor,
                          -bitmap=>$bitmap,
                          -font=>'variable',
                          -text=>$text,
                          -buttons=>$buttons);
   }
   return $d->Show;

} # warnwin

=head2 load_nodes

       Fills the nodes drop-down list with values from the database

=cut
sub load_nodes {
  my ($caller)=@_;
  my $sqltext="SELECT nodename FROM nodes ORDER BY nodename";
  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
  my @list=();
  my @result=();
  while ( my $arr_ref = $sql_ref->handle->fetch ) {
    push @list, $$arr_ref[0];
  };
  $caller->configure(-choices=>\@list);

}

=head2 load_classes

       Fills the classes drop-down list with values from the database

=cut
sub load_classes {
  my ($caller)=@_;
  my $sqltext="SELECT iso_country_code FROM countries ORDER BY iso_country_code";
  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
  my @list=();
  my @result=();
  push @list, ('EAAP','FAO');
  while ( my $arr_ref = $sql_ref->handle->fetch ) {
    push @list, $$arr_ref[0];
  };
  $caller->configure(-choices=>\@list);

}


=head2 get_classes_

       Returns an array with all defined classes in the database

=cut
sub get_classes {
  my @list=('EAAP','FAO'); 
  my $sqltext="SELECT iso_country_code,db_region as region FROM countries WHERE part_of is NULL 
               UNION
               SELECT  c1.iso_country_code,c2.db_region as region  from countries c1 left join countries c2 on (c1.part_of=c2.country_id) where c1.part_of is not NULL 
               ORDER BY region, iso_country_code";
  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
  while ( my $arr_ref = $sql_ref->handle->fetch ) {
    push @list, $$arr_ref[0];
  };
  return \@list

}


=head2 MsgBox

       Creates simple Info dialog with title and text customizable

=cut
sub MsgBox {
  my $fdtop= shift;
  my $msg = shift;
  my $title = shift;
  my $buttons = ['OK'];

   use Tk::Dialog;

   my $d = $fdtop->Dialog(-title=>$title,
                          -font=>'variable',
			  -text=>$msg,
			  -buttons=>$buttons);
   return $d->Show;
}


=head2 load_tables

       Puts all table names from the model file in the caller drop-down list. Has to be called only from BrowseEntry.

=cut
sub load_tables {
  my ($caller)=@_;
  my @list=$apiis->Model->tables;
  $caller->configure(-choices=>\@list);

}


=head2 dump_tables

       Dumps 'sources', 'targets' and 'nodes' tables into ASCII file : '/var/synch_tables.dmp'

=cut
sub dump_tables {
  my $dbname=$apiis->Model->db_name;
  my $dump_file=$apiis->APIIS_LOCAL.'/var/synch_tables.dmp';
  open (DUMPFILE,">$dump_file");
  my $sql_sources="SELECT source, tablename, class, columnnames,owner,version FROM sources";
  my $sql_ref=$apiis->DataBase->sys_sql($sql_sources);
  print DUMPFILE "SOURCES\n";
  while (my $row=$sql_ref->handle->fetch) {
    local $"='|';
    print DUMPFILE "@$row\n";
  }
  my $sql_targets="SELECT target, tablename, class, columnnames,owner,version FROM targets";
  $sql_ref=$apiis->DataBase->sys_sql($sql_targets);
  print DUMPFILE "TARGETS\n";
  while (my $row=$sql_ref->handle->fetch) {
    local $"='|';
    print DUMPFILE "@$row\n";
  }
  my $sql_nodes="SELECT nodename,address,owner,version FROM nodes";
  $sql_ref=$apiis->DataBase->sys_sql($sql_nodes);
  print DUMPFILE "NODES\n";
  while (my $row=$sql_ref->handle->fetch) {
    local $"='|';
    print DUMPFILE "@$row\n";
  }
  close DUMPFILE;
}

=head2 load_dump

      Loads 'sources', 'targets' and 'nodes' tables from '/var/synch_tables.dmp' file. The information from the file is loaded as new records one by one, therefore no problems with guids and existing records

=cut
sub load_dump {
  my $table;
  my $dbname=$apiis->Model->db_name;
  my $dump_file=$apiis->APIIS_LOCAL.'/var/synch_tables.dmp';
  eval {
    open (DUMPFILE,"<$dump_file");
    while (<DUMPFILE>) {
      chomp($_);
      if (($_ eq 'SOURCES') or ($_ eq 'TARGETS') or ($_ eq 'NODES')) {
	$table=lc($_);
	$apiis->DataBase->sys_dbh->commit;
	next;
      }
      my @values;
      @values =split('\|',$_,7) if ($table eq 'sources' or $table eq 'targets');
      @values =split('\|',$_,5) if ($table eq 'nodes');
      for(my $i=0;$i<@values;$i++) {
	if (defined $values[$i] and $values[$i] ne '') {
	  $values[$i]=$apiis->DataBase->dbh->quote($values[$i]);
	} else {
	  $values[$i]='NULL';
	}
      } 
      my $sql_insert=sprintf "INSERT INTO sources (guid,source, tablename, class, columnnames,owner,version) VALUES (%s,%s,%s,%s,%s,%s,%s)", $apiis->DataBase->seq_next_val('seq_database__guid'),$values[0],$values[1],$values[2],$values[3],$values[4],$values[5]  if ($table eq 'sources');
      $sql_insert=sprintf "INSERT INTO targets (guid,target, tablename, class, columnnames,owner,version) VALUES (%s,%s,%s,%s,%s,%s,%s)", $apiis->DataBase->seq_next_val('seq_database__guid'),$values[0],$values[1],$values[2],$values[3],$values[4],$values[5]  if ($table eq 'targets');
      $sql_insert=sprintf "INSERT INTO nodes (guid,nodename,address,owner,version,last_change_dt,last_change_user) VALUES (%s,%s,%s,%s,%s,'%s','%s')", $apiis->DataBase->seq_next_val('seq_database__guid'),$values[0],$values[1],$values[2],$values[3],$apiis->now,$apiis->User->id  if ($table eq 'nodes');
      my $sql_ref=$apiis->DataBase->sys_sql($sql_insert);
      $apiis->DataBase->sys_dbh->commit;
    }
    $apiis->DataBase->sys_dbh->commit;
    close DUMPFILE;
  };
    if ($@) {
      my $err1=$@;
      $apiis->log('err',$err1);
      MsgBox($mainnode,$err1,"Error") if (Exists($mainnode));
    } else {  
      $apiis->log('info',"Successfully reloaded sources, targets and nodes tables from dump");
      MsgBox($mainnode,"Successfully reloaded sources, targets and nodes tables from dump","Info") if (Exists($mainnode));
    }
}



=head2 check_route_integrity

     Compares DE route definition of node1 and node2 and produces a file '/tmp/route_integrity.txt' with sections 'MISSING' and 'CONFLICTS'

=cut
sub check_route_integrity {
  my $node1_name=shift;	
  my $node1_file=shift;
  my $node2_name=shift;
  my $node2_file=shift;
  
  my ($node1_sources,$node1_targets)=parse_dump($node1_file);
  my ($node2_sources,$node2_targets)=parse_dump($node2_file);
  my $node1_to_node2=compare_routes($node1_name,$node1_targets,$node2_name,$node2_sources);
  eval {
    open FILE, ">/tmp/route_integrity.txt" or die "Cannot open /tmp/route_integrity.txt: $!";
    print FILE "\nComparison between $node1_name targets and $node2_name sources\n";
    #  print FILE "\nOK\n";
    #  foreach (sort keys %$node1_to_node2) {
    #    if ($$node1_to_node2{$_} eq 'ok') {
    #       print FILE "--------------------------------------------------------------\n";
    #  	print FILE "DE:$_\n" 
    #    }
    #  }
    print FILE "\nMISSING Data Elements description\n";
    foreach (sort keys %$node1_to_node2) {
      if ($$node1_to_node2{$_} eq 'missing') {
	print FILE "--------------------------------------------------------------\n";
	print FILE "DE:$_\n";
      }
    }
    print FILE "\nCONFLICTS in route\n";
    foreach (sort keys %$node1_to_node2) {
      if ($$node1_to_node2{$_} eq 'conflict') {
	print FILE "--------------------------------------------------------------\n";
	print FILE "DE:$_\nconflict:$node1_name target is $$node1_targets{$_},but $node2_name source is $$node2_sources{$_}\n";
      }
    }
    $node1_to_node2=compare_routes($node2_name,$node2_targets,$node1_name,$node1_sources);
    print FILE "\nComparison between $node2_name targets and $node1_name sources\n";
    #  print FILE "\nOK\n";
    #  foreach (sort keys %$node1_to_node2) {
    #    if ($$node1_to_node2{$_} eq 'ok') {
    #       print FILE "--------------------------------------------------------------\n";
    #  	print FILE "DE:$_\n" 
    #    }
    #  }
    print FILE "\nMISSING Data Elements description\n";
    foreach (sort keys %$node1_to_node2) {
      if ($$node1_to_node2{$_} eq 'missing') {
	print FILE "--------------------------------------------------------------\n";
	print FILE "DE:$_\n";
      }
    }
    print FILE "\nCONFLICTS in route\n";
    foreach (sort keys %$node1_to_node2) {
      if ($$node1_to_node2{$_} eq 'conflict') {
	print FILE "--------------------------------------------------------------\n";
	print FILE "DE:$_\nconflict:$node1_name target is $$node1_targets{$_},but $node2_name source is $$node2_sources{$_}\n";
      }
    }
    close FILE;
  };
    if ($@) {
      my $err1=$@;
      $apiis->log('err',$err1);
      MsgBox($mainroute,$err1,"Error") if (Exists($mainroute));
    } else {  
      $apiis->log('info',"file /tmp/route_integrity.txt successfully written");
      MsgBox($mainroute,"file /tmp/route_integrity.txt successfully written","Info") if (Exists($mainroute));
    }
}

=head2 parse_dump

     Parses the dump file produced by dump_tables subroutine and returns hash references to sources and targets.
     The format of the two hashes is {DE=>Node name}.

=cut
sub parse_dump {
  my $file_name=shift;
  my (%sources,%targets,$nodes);
  my ($table,$current,@values);
  eval {
    open (DUMPFILE,"<$file_name");
    while (<DUMPFILE>) {
      chomp($_);
      if (($_ eq 'SOURCES') or ($_ eq 'TARGETS') or ($_ eq 'NODES')) {
	last if ($_ eq 'NODES');
	$table=lc($_);
	next;
      }
      @values =split('\|',$_,7) if ($table eq 'sources' or $table eq 'targets');
      @values =split('\|',$_,5) if ($table eq 'nodes');
      $sources{"$values[1]|$values[2]|$values[3]"}=$values[0] if ($table eq 'sources'); 
      $targets{"$values[1]|$values[2]|$values[3]"}=$values[0] if ($table eq 'targets'); 
    }
    close DUMPFILE;
  };
    if ($@) {
      my $err1=$@;
      $apiis->log('err',$err1);
      MsgBox($mainnode,$err1,"Error") if (Exists($mainnode));
    }
  return \%sources,\%targets;
}


=head2 compare_routes

       Given the names of the two nodes, the targets hash of the first node and the source hash of the second node return hash with three type of values 'ok' - if the source and target match, 'missing' if there is source without target or target without source and 'conflict' if the source and target nodes does not match.

=cut
sub compare_routes {
  my $node1_name=shift;
  my $node1_targets=shift;
  my $node2_name=shift;
  my $node2_sources=shift;
  my %status_hash;
  foreach my $key (sort keys %$node1_targets) {
    if ($$node1_targets{$key} eq $node2_name) {
      if ((exists $$node2_sources{$key}) and ($$node2_sources{$key} eq $node1_name)) {
	$status_hash{$key}='ok';
      } elsif (not exists $$node2_sources{$key}) {
     	$status_hash{$key}='missing';
      } else {
     	$status_hash{$key}='conflict';
      }
   }
  }
  foreach my $key (sort keys %$node2_sources) {
    if (($$node2_sources{$key} eq $node1_name)) {
      if (not exists $$node1_targets{$key}) {
     	$status_hash{$key}='missing';
      }
    }
  }
  return \%status_hash;
}


=head2 route_check

       Creates GUI for entering the parameters needed for 'check_route_integrity' subroutine

=cut
sub route_check {
  if (! Exists($mainroute)) {
    my $node1_name='';
    my $node2_name='';
    my $file1='';
    my $file2='';
    $mainroute=$main->Toplevel();
    $mainroute->minsize(qw(450 250));
    $mainroute->title("Routes integrity check");
    $mainroute->configure(-background=>$backcolor);

    my $frame = $mainroute->Frame(-relief=>'groove',-borderwidth=>2,-bg=>$framecolor)
                     ->pack(-side=>'top',-padx=>5,-pady=>5,-anchor=>'s');
    my $frame1 = $frame->Frame(-relief=>'groove',-borderwidth=>1,-bg=>$framecolor)
                     ->pack(-side=>'top',-padx=>5,-fill=>"y",-expand=>1,-pady=>5);
    my $node1list = $frame1->BrowseEntry(-variable => \$node1_name,
				  -bg=>$framecolor,
				  -label=>"Node1 name ",
				  -state =>  'readonly',
				  -listcmd=>\&load_nodes,
				  -browsecmd=>\&refresh_columns_list,
				 )->pack(-side=>'top',-anchor=>'e',-pady=>5,-padx=>5);
    $frame1->Label( -text=>'Node1 dump file',-bg=>$backcolor )->pack(-side=>'left');
    my $file1entry=$frame1->Entry( -textvariable=>\$file1)->pack(-side=>'left');
    my $browse1=$frame1->Button(-text=>"Browse",-command=>[\&select_file,\$file1],)->pack(-side => 'right',-fill=>'x',-expand=>0,-anchor=>'s');
    my $frame2 = $frame->Frame(-relief=>'groove',-borderwidth=>1,-bg=>$framecolor)->pack(-side=>'top',-padx=>0,-pady=>5);
    my $node2list = $frame2->BrowseEntry(-variable => \$node2_name,
				      -bg=>$framecolor,
				      -label=>"Node2 name ",
				      -state =>  'readonly',
				      -listcmd=>\&load_nodes,
				      -browsecmd=>\&refresh_columns_list,
				     )->pack(-side=>'top',-anchor=>'e',-pady=>5,-padx=>5);
    $frame2->Label( -text=>'Node2 dump file',-bg=>$backcolor )->pack(-side=>'left');
    my $file2entry=$frame2->Entry( -textvariable=>\$file2)->pack(-side=>'left');
    my $browse2=$frame2->Button(-text=>"Browse",-command=>[\&select_file,\$file2],)->pack(-side => 'right',-fill=>'x',-expand=>0,-anchor=>'s');
    my $frame3 = $mainroute->Frame(-relief=>'groove',-borderwidth=>0,-bg=>$framecolor)->pack(-side=>'top',-padx=>0,-pady=>5);
    my $checkbtn=$frame3->Button(-text=>"Check",
				-command=>sub{check_route_integrity($node1_name,$file1,$node2_name,$file2)},
				)->pack(-side => 'left',-fill=>'x',-expand=>1,-anchor=>'s');
    my $closebtn=$frame3->Button(-text=>"Close",
				  -command=>sub{$mainroute->destroy}
				 )->pack(-side=>'right',-fill=>'x',-expand=>1,-anchor=>'s',-padx=>1);

  } else {
    $mainroute->deiconify();
    $mainroute->raise();
  }
}



=head2 select_file

       Chooses file using Tk::FileSelect widget and writes result in the variable passed as a parameter

=cut
sub select_file {
  my $caller=shift;
  my $folder=$apiis->APIIS_LOCAL."/var/";
  my $FSref = $mainroute->FileSelect(-directory => $folder) ;
  $$caller = $FSref->Show;
}


=head1 AUTHOR

Zhivko Duchev <duchev@tzv.fal.de>
