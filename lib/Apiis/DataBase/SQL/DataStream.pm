##############################################################################
# 
# the SQL module for creating datastream object.
##############################################################################

=head1 NAME

DataStream

=head1 SYNOPSIS

    $ds = Apiis::DataBase::SQL::DataStream->new(
						ds     => $ds,
						debug  => $debug
   );


This is the module for creating an object for handling datasteams. 

=head1 DESCRIPTION

Creates the internal structure for the hash previously used in the batch processing and provides methods for accessing them.



Public and internal methods are:

=head1 PUBLIC METHODS

=head2 ds

- returns the name of the datastream

=cut

=head2 job_start

- sets or returns the time when the job was started

=cut

=head2 job_end

 - sets or returns the time when the job was finished

=cut

=head2 records_total 

- sets or returns total number of processed records

=cut

=head2 records_error

- sets or returns the number of errors that occure in the records - it is not precise and can give only impression of real number of errors

=cut

=head2 records_ok 

- sets or returns total number of records that was OK

=cut

=head2 data

- sets or returns the data 

=cut

=head2 LO_keys 

- sets or returns the list of LO_keys

=cut

=head2 ext_unit

- sets or returns the ext_unit that has supplied this record

=cut

=head2 record_seq 

- sets or returns the record number from INSPOOL system

=cut

=head2 target_column

- sets or returns an extra information for linking the errors to special column

=cut

=head2 debug 

- sets or returns debug level

=cut

=head2 verbose

- sets or returns the verbose mode (more output messages)

=cut

=head2 sth_update_inspool

- sets or returns statement handle for updating inspool

=cut

=head2 sth_inspool_err

- sets or returns statement handle for inserting new record in inspool_err

=cut

=head2 sth_ds 

- sets or returns statement handle for reading record from  inspool

=cut

=head2 sth_load_stat

- sets or returns statement handle for inserting new record in load_stat

=cut


=head2 status 

- sets or returns the object status - inherited from apiis

=cut

=head2 errors 

- sets or returns list of error objects - inherited from apiis

=cut

##############################################################################

package Apiis::DataBase::SQL::DataStream;
$VERSION = '$Id ';

use strict;
use Carp;
use warnings;
use Data::Dumper;
use Apiis::Init;



@Apiis::DataBase::SQL::DataStream::ISA = qw(
  Apiis::Init
);

# for debugging:
# use Class::ISA;
# print "Apiis::DataBase::Record path is:\n ",
  # join ( ", ", Class::ISA::super_path('Apiis::DataBase::Record') ), "\n";

our($apiis);

{    # private class data and methods to leave the closure:
   my %_attr_data = (
		     _ds                 => 'ro',
		     _job_start          => 'ro',
		     _job_end            => 'ro',
		     _records_total      => 'rw',
		     _records_error      => 'rw',
		     _records_ok         => 'rw',
		     _data               => 'rw', #array
		     _LO_keys            => 'rw',
		     _ext_unit           => 'rw',
		     _record_seq         => 'rw',
		     _target_column      => 'rw',
		     _debug              => 'rw', #debug level
		     _verbose            => 'rw', 
		     _sth_update_inspool => 'ro',
		     _sth_inspool_err    => 'ro',
		     _sth_ds             => 'ro',
		     _sth_load_stat      => 'ro',
		     _dbh                => 'ro',
    );

=head2 _standard_keys (internal)

- encapsulates the names of the automatically created methods

=cut

   sub _standard_keys { keys %_attr_data; }    # attribut names:

   # is a certain object attribute accessible with this method:
   # $_[1]: attribut name/key, $_[2]: value

=head2 _accessible (internal)

- checks if the method is read-only or read-write

=cut

   sub _accessible { $_attr_data{ $_[1] } =~ /$_[2]/; }

}

##############################################################################

=head2 new 

- creates the datastream object

=cut

sub new {
   my ( $invocant, %args ) = @_;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init( %args );         # run the _init of the invoking class:
   return $self;
}

##############################################################################

=head2 _init (internal)

- initializes the counters and prepares several database statements 

=cut

sub _init {
   my $self = shift;
   my %args = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++; # Conway p. 243  
   if ( not exists $args{ds} ) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'ERR',
				      from      => 'Apiis::DataBase::SQL::DataStream',
				      msg_short => "No key 'ds' passed",
				      msg_long  => 'No datastream name passed to datastream',
				     )
		  );
   } else {
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
       }
     }    # end of creating public methods automagically
     $self->{"_ds"}=$args{ds};
     ($args{debug})?$self->debug($args{debug}):$self->debug(0);
     $self->verbose(1); #maybe implement it later
     $self->records_total(0);
     $self->records_ok(0);
     $self->records_error(0);
     $self->{"_job_start"}=$apiis->extdate2iso($apiis->now);
     my ($status,$thisdbh,$sql_ref);
     my $owner=$apiis->node_name; #this will be changed to $apiis->class jiji
     eval {
       # prepare statement for updating table inspool:
       $apiis->DataBase->connect;
       my $thisdbh = $self->{"_dbh"} = $apiis->DataBase->dbh;
       #have to ensure separate db_handle, that will not interfere with the one used in the LO
       local $thisdbh->{RaiseError} = 1 unless $thisdbh->{RaiseError};
       $self->{"_sth_update_inspool"} = $thisdbh->prepare(qq{
							   UPDATE inspool SET 
							   status = ?,
							   proc_dt = ?,
							   last_change_dt = ?,
							   last_change_user = ?
							   WHERE record_seq = ?}) or die $thisdbh->errstr;
       
      # columns in inspool_err:
      # record_seq, err_type, action, dbtable, dbcol, err_source, short_msg, long_msg,
      # ext_col, ext_val, mod_val, comp_val, target_col, ds, ext_unit, status,
      # err_dt, last_change_dt, last_change_user, dirty,
      my $insert_inspool_err=sprintf "INSERT INTO inspool_err (
				record_seq, err_type, action, dbtable, dbcol, err_source, short_msg,
				long_msg, ext_col, ext_val, mod_val, comp_val, target_col, ds,
				ext_unit, status, err_dt, last_change_dt, last_change_user, dirty,
                                guid, owner, version
			       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,?,'%s',1)",$owner;
      $self->{"_sth_inspool_err"} = $thisdbh->prepare($insert_inspool_err) or die $thisdbh->errstr;
       
      # prepare statement to retrieve records from this data stream:
      my $sql = "SELECT record_seq, ext_unit, record
                 FROM   inspool
                 WHERE  ds = '".$self->ds."' AND
                        status = 'NEW'
                 ORDER BY record_seq";
       $sql_ref = $apiis->DataBase->sys_sql($sql);
       $status = $sql_ref->status;
       $self->{"_sth_ds"}=$sql_ref;

      # columns in load_stat:
      # ds, job_start, job_end, status, rec_tot_no, rec_err_no, rec_ok_no,
      # last_change_dt, last_change_user, dirty
      my $insert_load_stat=sprintf "INSERT INTO load_stat (
            ds, job_start, job_end, status,
            rec_tot_no, rec_err_no, rec_ok_no,
            last_change_dt, last_change_user, dirty,
            guid, owner, version
         ) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,'%s',1)", $owner;
      $self->{"_sth_load_stat"} = $thisdbh->prepare($insert_load_stat) or die $thisdbh->errstr;
       
     };  # end eval

     if ( $@ or $status) {
       my $err_msg=${$sql_ref->errors}[0]->msg_long if ($sql_ref->errors);
       print STDERR "$@\n" if $self->verbose;
       my $long_msg = $@ . ' ' . $err_msg if $err_msg; #check where to get the message!
       eval {
	 my $tnow=$apiis->extdate2iso($apiis->now);
	 $self->sth_inspool_err->execute(
					 undef,
					 undef,
					 undef,
					 undef,
					 undef,
					 undef,
					 $@,
					 $long_msg,
					 undef,
					 undef,
					 undef,
					 undef,
					 undef,
					 $self->ds,
					 $self->ext_unit, #or just undef?
					 'A',
					 $tnow,
					 $tnow,
					 $apiis->User->id,
					 undef,
					 $apiis->DataBase->seq_next_val('seq_database__guid')
					) or die $thisdbh->errstr;
       $thisdbh->commit unless $self->debug >4;
       };
       if ($@) {
	 print STDERR "$@\n" if $self->verbose;
       }
       $self->status(1);
       $self->errors(
		     Apiis::Errors->new(
				      type      => 'UNKNOWN',
				      severity  => 'ERR',
				      from      => 'Apiis::DataBase::SQL::DataStream',
				      msg_short => $@,
				      msg_long  => $@,
				     )
		  );

     }
   }
 }



#############################################################################

=head2 CheckDS

Verifies if the number of elements in the DS is the same as the number of LO keys

=cut

#############################################################################
sub CheckDS{
    my $self = shift; 
    if ( $#{$self->data} != $#{$self->LO_keys} ){
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type        => 'CODE',
				      severity    => 'ERR',
				      action      => 'UNKNOWN',
				      from        => 'CheckDS',
				      msg_long    => "Number of elements in datastream (".$#{$self->data}.") and external names (".$#{$self->LO_keys}.") do not correspond.",
				     )
		  );

   }
  }
##############################################################################

=head2 PostHandling

Writes the summary statistics on the screen and in tableload_stat and  error_messages in table inspool_err

=cut

#############################################################################

sub PostHandling {
   my  $ds = shift;
   $ds->{"_job_end"}=$apiis->extdate2iso($apiis->now);
   my $non_data_errors;
   defined $ds->errors
     ? ( $non_data_errors = scalar @{ $ds->errors } )
     : ( $non_data_errors = 0 );
   printf "Statistics:
      Datastream:\t%s
      Start:\t\t%s
      End:\t\t%s
      Records:
      \tOK:\t\t%s
      \tErrors:\t\t%s
      \tTotal:\t\t%s
      Non-data errors:\t%s\n",$ds->ds,$ds->job_start,$ds->job_end, $ds->records_ok,$ds->records_error,$ds->records_total,$non_data_errors    if ($ds->verbose);
   if ( $non_data_errors ){
      map {
         # record_seq, err_type, action, dbtable, dbcol, err_source, short_msg,
         # long_msg, ext_col, ext_val, mod_val, comp_val, target_col, ds,
         # ext_unit, status, err_dt, last_change_dt, last_change_user, dirty
         my $this_ext_cols = join(' ', @{$_->ext_fields}) if $_->ext_fields;
         #$sth_inspool_err
	 my $tnow=$apiis->extdate2iso($apiis->now);
	 $ds->sth_inspool_err->execute(
            $ds->record_seq,
            $_->type,
            $_->action,
            $_->db_table,
            $_->db_column,
            $_->from,
            $_->msg_short,
            $_->msg_long,
            $this_ext_cols,
            undef,
            $_->data,
            undef,
            $ds->target_column,
            $ds->ds,
            $ds->ext_unit,
            'A', $tnow, $tnow, $apiis->User->id, undef,$apiis->DataBase->seq_next_val('seq_database__guid')
         );
         $_->print if $ds->debug > 0;
      } @{$ds->errors};
      $ds->dbh->commit unless $ds->debug >4;
   }

   # columns in load_stat:
   # ds, job_start, job_end, status, rec_tot_no, rec_err_no, rec_ok_no,
   # last_change_dt, last_change_user, dirty
   my $tnow=$apiis->extdate2iso($apiis->now);
   $ds->sth_load_stat->execute(
			       $ds->ds,
			       $ds->job_start,
			       $ds->job_end,
			       undef,
			       $ds->records_total,
			       $ds->records_error,
			       $ds->records_ok,
			       $tnow,
			       $apiis->User->id,
			       undef,
			       $apiis->DataBase->seq_next_val('seq_database__guid')
			      );
   $ds->dbh->commit unless ($ds->debug >4);
}
##############################################################################


1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>
Zhivko Duchev <duchev@tzv.fal.de>

=cut

__END__
