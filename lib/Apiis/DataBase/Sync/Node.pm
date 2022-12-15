##############################################################################
# 
# the module for creating node objects.
##############################################################################
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
=head1 NAME


APIIS::DataBase::Sync::Node -- An object for encapsulating the node activities

=head1 SYNOPSIS

    $node = Apiis::DataBase::Sync::Node->new(
                                             nodename=>'Mariensee',
                                             class_column=>'owner'
                                             );


This is the module for creating an object that handles the node information . 
=head1 DESCRIPTION

Provides methods to create new server or client of the synchronization process, reading DataElementDescriptions, reading data state, comparing states etc.


Public and internal methods are:

=head1 PUBLIC METHODS

=cut

##############################################################################

package Apiis::DataBase::Sync::Node;
$VERSION = '$Id ';

use strict;
use Carp;
use warnings;
use Data::Dumper;
use Apiis::Init;
use Net::EasyTCP;
#use Apiis::Record;

@Apiis::DataBase::Sync::Node::ISA = qw(
  Apiis::Init

);

# for debugging:
# use Class::ISA;
# print "Apiis::DataBase::Record path is:\n ",
  # join ( ", ", Class::ISA::super_path('Apiis::DataBase::Sync::Node') ), "\n";



{    # private class data and methods to leave the closure:
   my %_attr_data = (
      _actionname       => 'ro',
      _tablename        => 'ro',
      _nodes            => 'ro',
      _loadnodes        => 'ro',
      _sources_DED      => 'ro',
      _targets_DED      => 'ro',
      _debug            => 'rw',
      _class_column     => 'ro',
      _nodename         => 'ro',
      _DED_state        => 'rw',
      _state	        => 'rw',
      _partner	        => 'rw',
      _logging          => 'rw'
    );
   sub _standard_keys { keys %_attr_data; }    # attribut names:

   # is a certain object attribute accessible with this method:
   # $_[1]: attribut name/key, $_[2]: value
   sub _accessible { $_attr_data{ $_[1] } =~ /$_[2]/; }

}

##############################################################################

=head2 new 

- creates new node object

=cut

sub new {
   my ( $invocant, %args ) = @_;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init( %args );         # run the _init of the invoking class:
   return $self;
}

##############################################################################ww

=head2 _init (internal)

-creates dynamic methods and fill the information about all registered nodes

=cut

sub _init {
   my $self = shift;
   my %args = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++; # Conway p. 243  
   $self->{"_debug"}=[1];
   if ( not exists $args{nodename} ) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase::SQL::Statement',
				      msg_short => "No key 'nodename' passed to Apiis::DataBase::Sync::Node",
				     )
		  );
   } else {
     $self->{"_nodename"}=$args{nodename};
     $self->{"_class_column"}=$args{class_column} if(exists $args{class_column});
     $self->{"_logging"}=[$args{logging}] if(exists $args{logging});
     for my $thiskey ( $self->_standard_keys() ) {
       my $method = $thiskey;
       $method =~ s/^_//;
       # to avoid 'Subroutine xxx redefined' messages
       unless ( $self->can("$method") ) {
	 if ( $self->_accessible( $thiskey, 'ro' ) ) {
	   # read only:
	   no strict 'refs';
	   *$method = sub {
	     if ( ref( $_[0]->{$thiskey} ) eq 'ARRAY' ) {
	       wantarray && return @{ $_[0]->{$thiskey} };
	     }
	     return $_[0]->{$thiskey};
	   };
	 } elsif ( $self->_accessible( $thiskey, 'rw' ) ) {
	   # read/write:
	   no strict 'refs';
	   *$method = sub {
	     my ( $self, @values ) = @_;
	     $self->{$thiskey} = \@values if @values;
	     if ( defined $self->{$thiskey} and scalar @{$self->{$thiskey}} > 1 ) {
	       # we have stored an array with more than one element:
	       wantarray && return @{ $self->{$thiskey} };
	       return $self->{$thiskey};
	     } else {
	       # return only the first element as scalar:
	       return $self->{$thiskey}->[0];
	     }
	   };
	 } else {
	   # must be an error:
	   confess "No such method: $method";
	 }
       }    # end of creating public methods automagically
     }
     $self->_loadnodes();
   }
}





##############################################################################

=head2 create_client

- creates new Net::EasyTCP client
Usage: $node->create_client($server_host,$port)

=cut

sub create_client {
  my $self = shift;
  my $host=shift;
  my $port=shift;
  my $client;
  eval {
    $client = new Net::EasyTCP(
			       mode            =>      "client",
			       host            =>      $host,
			       port            =>      $port,
			       timeout         =>      300
			      ) || die;
  };
  if ($@) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'OS',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase::Sync::Node',
				      msg_short => "Cannot establish connection to server",
				      msg_long  => "Cannot establish connection: $@"
				     )
		  );
     return undef;
  }
  return $client;
}



##############################################################################

=head2 create_server

- creates new Net::EasyTCP server
Usage: $node->create_server($port)

=cut

sub create_server {
  my $self = shift;
  my $port = shift;
  my $server;
  eval {
     $server = new Net::EasyTCP(
			       mode            =>      "server",
			       port            =>      $port,
        		      ) || die;

  };
  if ($@) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'OS',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase::Sync::Node',
				      msg_short => "Cannot create server",
				      msg_long  => "Cannot create server: $@"
				     )
		  );
     return undef;
  }
  return $server;
}



##############################################################################

=head2 read_DED

- reads DataElementDescriptions (table,class,column names) for node $node_name and role source or target from the database.
Usage: $node->read_DED($node_name,'source') or  $node->read_DED($node_name,'target')

=cut

sub read_DED {
   my $self=shift;
   my @allsource=();
   my $node = shift;
   my $role = shift; #can be "source" or "target" on server we usually read the targets
   if (($role ne 'source') and ($role ne 'target')) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase:;Sync::Node',
				      msg_short => "Unknown role in read_DED method",
				      msg_long  => "Role in read_DED must be 'source' or 'target'"
				     )
		  );
     return undef;
   }
   my $looktable=$role.'s';  #table is "sources" or "targets"
   my $sqltext="SELECT tablename,class,columnnames FROM $looktable  WHERE $role='$node'";
   print "$sqltext\n" if $self->debug>6; #in case of debugging
   my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
   my $status = $sql_ref->status;
   my $affected_rows = $sql_ref->rows;
   if ($status) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'DB',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase:;Sync::Node',
				      msg_short => "Cannot read DED",
				      msg_long  => "Cannot read DED"
				     )
		  );
     return undef;
  }
   while ( my $arr_ref = $sql_ref->handle->fetch ) {
     my @result = @{ $arr_ref };
     push @allsource, [shift @result,shift @result,@result];
   };
   $sql_ref->handle->finish;
   if ($role eq 'source') {
     $self->{"_sources_DED"}= \@allsource;
   } else {
     $self->{"_targets_DED"}= \@allsource;
   }
}
##############################################################################

sub read_state {
  my $self=shift;
  my $source=shift;
  my @result=();
  my %state=();
  my $sqltext=sprintf "SELECT guid,version FROM $$source[0]  WHERE %s='$$source[1]' AND synch='1'",$self->class_column;
  print "$sqltext\n" if $self->debug>6;
  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
  my $status = $sql_ref->status;
  my $affected_rows = $sql_ref->rows;
  if ($status) {
    $self->status(1);
    $self->errors(
		  Apiis::Errors->new(
				     type      => 'DB',
				     severity  => 'CRIT',
				     from      => 'Apiis::DataBase:;Sync::Node',
				     msg_short => "Cannot read state of DataElement",
				     msg_long  => "Cannot read state of DataElement"
				    )
		  );
     return undef;
  }
   while ( my $arr_ref = $sql_ref->handle->fetch ) {
     my @result = @{ $arr_ref };
     $state{$result[0]}=$result[1];
   };
   $sql_ref->handle->finish;
   $self->{"_DED_state"}= \%state;
   return $affected_rows;
}

##############################################################################

=head2 ip2name

- converts IP address into name accordingly to the information in 'nodes' table
Usage : $node->ip2name($nodeip)

=cut

sub ip2name {
  my $self=shift;
  my $nodeip=shift;
  foreach (sort keys %{$self->nodes}) {
    return $_ if (${$self->nodes}{$_} eq $nodeip) 
  }
  $self->status(1);
  $self->errors(
		Apiis::Errors->new(
				   type      => 'DB',
				   severity  => 'CRIT',
				   from      => 'Apiis::DataBase:;Sync::Node',
				   msg_short => "Cannot find node name for address $nodeip",
				   msg_long  => "Cannot find node name for address $nodeip"
				  )
	       );
  return undef;
}

###############################################################################

=head2 name2ip

- converts name into IP address accordingly to the information in 'nodes' table
Usage : $node->name2ip($nodename)

=cut

sub name2ip {
  my $self=shift;
  my $nodename=shift;
  if (${$self->nodes}{$nodename}) {
    return ${$self->nodes}{$nodename};
  } else {
    $self->status(1);
    $self->errors(
		  Apiis::Errors->new(
				     type      => 'DATA',
				     severity  => 'CRIT',
				     from      => 'Apiis::DataBase:;Sync::Node',
				     msg_short => "Cannot find address for node name $nodename",
				     msg_long  => "Cannot find address for node name $nodename"
				    )
		 );
    return undef;
  }
}


##############################################################################

=head2 _loadnodes (internal)

- reads from the database information about all registered nodes

=cut
sub _loadnodes {
  my $self=shift;
  my %nodes;
  my $sqltext="SELECT nodename, address FROM nodes";
  print "$sqltext\n" if $self->debug>6; #in case of debugging
  my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
  my $status = $sql_ref->status;
  my $affected_rows = $sql_ref->rows;
  if ($status) {
    $self->status(1);
    $self->errors(
		  Apiis::Errors->new(
				     type      => 'DB',
				     severity  => 'CRIT',
				     from      => 'Apiis::DataBase:;Sync::Node',
				     msg_short => "Cannot read nodes information",
				     msg_long  => "Cannot read nodes information"
				    )
		 );
    return undef;
  }
  while ( my $arr_ref = $sql_ref->handle->fetch ) {
    my @result = @{ $arr_ref };
    $nodes{$result[0]}=$result[1];
  };
  $sql_ref->handle->finish;
  $self->{"_nodes"}=\%nodes;
}


##############################################################################

=head2 DED_state

- sets or reads the state of ONE DataElement
Usage : $node->DED_state(\%data_element_state) or $node->DED_state

=cut

sub DED_state {
  my $self=shift;
  my $value=shift;
  $self->{"_DED_state"}=$value if $value;
  return $self->{"_DED_state"} if (defined $self->{"_DED_state"});
}


##############################################################################

=head2 compare_states

- compares the internal state in DED_state with the one passed as a parameter and replaces the version information in the passed hash with merge action info. In case of success returns also reference to the modified hash
Usage : $node->compare_states(\%data_element_state)

=cut

sub compare_states {
  my $self=shift;
  my $foreignstateref=shift;
  unless (ref($foreignstateref) eq 'HASH') {
    $self->status(1);
    $self->errors(
		  Apiis::Errors->new(
				     type      => 'PARAM',
				     severity  => 'CRIT',
				     from      => 'Apiis::DataBase::Sync::Node',
				     msg_short => "Wrong parameter type in 'compare_states'",
				     msg_long  => "Wrong parameter type:'compare_states' expects HASH reference"
				    )
		 );
    return undef;
  };
  my  $t0=[Time::HiRes::gettimeofday];
  my  @keyz=sort keys %$foreignstateref;
  print "elapsed in sorting foreign hash:".Time::HiRes::tv_interval($t0)."\n" if $self->debug>6;
  $t0=[Time::HiRes::gettimeofday];
  foreach (@keyz) {
      #simply delete the record with this guid - it exists no more on the
      #server
    $$foreignstateref{$_}='D'  unless (exists (${$self->{"_DED_state"}}{$_}));
  }
  print "elapsed in setting D flag:".Time::HiRes::tv_interval($t0)."\n" if $self->debug>6;
  $t0=[Time::HiRes::gettimeofday];
  @keyz=sort keys %{$self->DED_state}; 
  print "elapsed in sorting own hash:".Time::HiRes::tv_interval($t0)."\n" if $self->debug>6;
  $t0=[Time::HiRes::gettimeofday];
  my $key;
  foreach $key (@keyz) {
    if (exists($$foreignstateref{$key})) {
      if ($$foreignstateref{$key} < ${$self->{"_DED_state"}}{$key}) {
          #special case update is handled as a sequence of delete and insert a
          #new record. This is done to prevent index violations.
          #!!!!IMPORTANT - as  the state hash keys are the guids a letter 'd'
          #is added in front of the guid for deletion to make it unique
	$$foreignstateref{$key}='I';
	$$foreignstateref{'d'.$key}='D';
      } else {
	delete $$foreignstateref{$key};
      };
    } else {
      $$foreignstateref{$key}='I';
    }
  }
  print "elapsed in setting U and I tags:".Time::HiRes::tv_interval($t0)."\n" if $self->debug>6;
  return $foreignstateref;
}


##############################################################################

=head2 load_merge_element

- Create SQL statement from the DED and merge element and executes it 
Usage : $node->load_merge_element($DED,$merge_element)

=cut

sub load_merge_element {
  my $self=shift;
  my $datael=shift;
  my $mergeel=shift;
  my @columns=();
  my @places=();
  my $cnt=0;
  my ($i,$rv,$sth,$sqltext,$placeholders,$columnnames);
  print Dumper($mergeel) if $self->debug>6;
  @columns=split(',',$$datael[2]);
  $cnt=@columns;
  for ($i=0;$i<$cnt;$i++) {
    push @places, '?';
    #$$mergeel[$i+3]='' unless  (defined $$mergeel[$i+3]);
  }
  if ($$mergeel[2] eq "I") {
    $placeholders= join(',', @places);
    $sqltext="INSERT INTO $$datael[0] ($$datael[2],guid) VALUES ($placeholders,$$mergeel[1])";
  }
  elsif ($$mergeel[2] eq "U") {
    $columnnames= join('=?,', @columns);
    $columnnames.='=?';
    $sqltext="UPDATE $$datael[0] SET $columnnames WHERE guid=$$mergeel[1]";
  }
  elsif ($$mergeel[2] eq "D") {
    $$mergeel[1]=~/^d?(\d+)$/;
    my $guid=$1;
    $sqltext=sprintf "DELETE FROM %s WHERE guid=%s",$$datael[0],$guid;
  }
  $apiis->log('debug',"Merging",$sqltext);
  print "$sqltext\n" if $self->debug>6;
  #  ConnectDB() unless defined $dbh;
  my $dbh=$apiis->DataBase->sys_dbh;
  eval {
        local $dbh->{RaiseError} = 1 unless $dbh->{RaiseError}; #jiji
        local $dbh->{PrintError} = 0 if $dbh->{PrintError}; #jiji
	$sth =$apiis->DataBase->dbh->prepare($sqltext);
	unless ($$mergeel[2] eq "D") {
	  my $table_ref = $apiis->Model->table($$datael[0]);
	  my %bind_ref=();
	  for($i=1;$i<=$cnt;$i++) {
	    my $bind_type=$apiis->DataBase->bindtypes($table_ref->datatype($columns[$i-1]));
	    eval "%bind_ref= ($bind_type)";
	    #$$mergeel[$i+2]=$dbh->quote($$mergeel[$i+2]) if (($bind_type=~ 'DATE') or ($$mergeel[$i+2] eq 'undef')); #for old versions of DBD::Pg
	    $sth->bind_param($i,$$mergeel[$i+2],\%bind_ref);
	  }
	}
	#$sth->trace(2,'database.trace'); # debug
	$rv = $sth->execute || die "$@";
	$sth->finish;
      };
  if ($@) {
      #replace empty array elements with string undefined to prevent warning
      #messages
    my (@server_data,$i);
    for ($i=0;$i<@$mergeel; $i++) {
        if (defined $$mergeel[$i]) {
            $server_data[$i]=$$mergeel[$i];
        } else {
             $server_data[$i]='undefined';
        }
    }; 
    my $values=join('|',@server_data);
    $self->status(1);
    $self->errors(
		  Apiis::Errors->new(
				     type      => 'DB',
				     severity  => 'CRIT',
				     from      => 'Apiis::DataBase::Sync::Node',
				     msg_short => "Cannot execute sql statement:". $sqltext,
				     msg_long  => "Cannot execute sql statement:" .$sqltext. "with server data $values ". $@
				    )
		 );
  }
}

##############################################################################
=head2 print_log

- Prints the message into the log file with attached timestamp
Usage : $node->print_log($file_handle,$message)

=cut

sub print_log {
  my $self=shift;
  return unless $self->logging;
  my $file=shift;
  my $message=shift;
  my $fullmsg=sprintf "%s: %s\n",$apiis->now,$message;
  eval {
    print $fullmsg if $self->debug>2; 
    $file->print($fullmsg);
  };
  if ($@) {
    $self->status(1);
    $self->errors(
		  Apiis::Errors->new(
				     type      => 'OS',
				     severity  => 'INFO',
				     from      => 'Apiis::DataBase::Sync::Node',
				     msg_short => "Cannot print log message",
				     msg_long  => "Cannot print log message: $@"
				    )
		 );
  }
}

##############################################################################
=head2 check_DED

- Checks if the passed DataElementDescription is in the sources or targets.
Usage: $node->check_DED($DED,'sources') or  $node->check_DED($DED,'targets')

=cut

sub check_DED {
   my $self=shift;
   my $DED = shift;
   my $role = shift; #can be "sources" or "targets"
   my $my_DEDs;
   if($role eq 'sources') {
     $my_DEDs=$self->sources_DED;
   } elsif($role eq 'targets') {
     $my_DEDs=$self->targets_DED;
   }else {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase:;Sync::Node',
				      msg_short => "Unknown role in read_DED method",
				      msg_long  => "Second parameter in check_DED must be 'source' or 'target'"
				     )
		  );
     return undef;
   }
   foreach (@$my_DEDs) {
     return 1 if $self->compare_DED($_,$DED);
   }
   return 0;
}


##############################################################################
=head2 compare_DED

- Checks if the passed DataElementDescriptions are identical.
Usage: $node->compare_DED($DED1,$DED2)

=cut

sub compare_DED {
  my $self=shift;
  my $DED1=shift;
  my $DED2=shift;
  for (my $i=0;$i<@$DED1;$i++) {
    return 0 if ($$DED1[$i] ne $$DED2[$i]);
  }
  return 1;
}

##############################################################################


1;

=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>

=cut

__END__


