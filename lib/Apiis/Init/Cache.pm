##############################################################################
# $Id: Cache.pm,v 1.12 2013/02/13 10:54:05 heli Exp $
##############################################################################

package Apiis::Init::Cache;

use strict;
use warnings;
use Apiis::Init;
use Data::Dumper;
our $apiis;
##############################################################################

=head1 NAME

Apiis::Init::Cache provide some internal routines for caching

=head1 DESCRIPTION

Apiis::Init::Cache contains some internal routines, mostly used in Init.pm, for
caching.

=head1 METHODS

=cut

##############################################################################
sub new {
   my ( $invocant, %args ) = @_;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init(%args);
   return $self;
}
##############################################################################
sub _init {
    my ( $self, %args ) = @_;
    my $pack = __PACKAGE__;
    return if $self->{"_init"}{$pack}++;    # Conway p. 243

    # memcached as an external caching daemon, check for presence:
    eval {
        require Cache::Memcached::Fast;
    };
    if ( not $@ ) {
        my $memd = new Cache::Memcached::Fast {
            servers            => ["localhost:11211"],
            compress_threshold => 10_000,
            utf8               => ($^V ge v5.8.1 ? 1 : 0),
        };
        if ($memd) {
            my $testvalue = '__this_is_my_textvalue';
            $memd->set( '__testkey_in_Init_Cache', $testvalue, 2 );
            my $testresult = $memd->get('__testkey_in_Init_Cache');
            if ( $testresult and ($testvalue eq $testresult) ) {
                $self->hasMemcached(1);
                $self->memcache($memd);
            }
        }
    }

}
##############################################################################

=head2 hasMemcached | memcache (public)

B<hasMemcached> acts as a boolean flag, whether or not the module
Cache::Memcached is installed and if the memcached daemon is working. A short
test is made to ashure this.

The reference object to memcached is returned by $self->memcache.

=cut

# flag to indicate, if the Cache::Memcached module is installed and working:
sub hasMemcached {
    $_[0]->{_hasmemcached} = $_[1] if $_[1];
    return $_[0]->{_hasmemcached};
}

# stores/returns the reference object to the memcached:
sub memcache {
    $_[0]->{_memcache} = $_[1] if $_[1];
    return $_[0]->{_memcache};
}
##############################################################################

=head2 fh_filelog

Returns the filehandle for the file, which is defined in apiisrc for file
logging. If this filehandle does not exist it will be opened.

=cut

sub fh_filelog {
   my ( $self, $fh ) = @_;
   if ( not exists $self->{'_fh_filelog'}) {
      my $logfile = $apiis->filelog_filename;
      open( FILELOG, ">> $logfile" )
        or die "Cannot open file logfile $logfile: $!\n";
      $self->{'_fh_filelog'} = *FILELOG;
   }

   return $self->{'_fh_filelog'};
}
##############################################################################

=head2 fh_sqllog

The same like B<fh_filelog> but for the sql logging feature. Additionally it
writes a comment into the logfile when it is opened the first time.

=cut

sub fh_sqllog {
   my ( $self, $fh ) = @_;
   if ( not exists $self->{'_fh_sqllog'}) {
      my $logfile = $apiis->sql_logfile;
      open( SQLLOG, ">> $logfile" )
        or die "Cannot open sql logfile $logfile: $!\n";
      $self->{'_fh_sqllog'} = *SQLLOG;
      my $username = $apiis->os_user;
      $username = $apiis->User->id if $apiis->exists_user;

      printf SQLLOG "--rem %s [db_host: %s, db_name: %s, user: %s]:\n",
        $apiis->now, $apiis->Model->db_host, $apiis->Model->db_name, $username;
   }

   return $self->{'_fh_sqllog'};
}
##############################################################################

=head2 fh_close

Closes the filehandle.

=cut

sub fh_close {
   my ( $self, $fh ) = @_;
   if ( $fh and $self->{ "_$fh" } ){
      close $self->{ "_$fh" };
      delete $self->{ "_$fh" };
   }
}
##############################################################################

=head2 filelog_priorities

Returns a hashref with all the filelog priorities as key, which are true for
the given configuration. If e.g. warning is the filelog priorities, also
error, crit, alert, emerg, and panic are true.

=cut

sub _create_filelog_priorities {
   my ( $self, $rc_priority ) = @_;
   my @priorities =
     qw( debug info notice warn warning error err crit alert emerg panic );

   my ( $found, %priorities );
   for my $thisprior (@priorities) {
      if ( $found or $thisprior eq lc $rc_priority ) {
         $priorities{$thisprior} = 1;
         $found++;
      }
   }
   $self->{'_filelog_priorities'} = \%priorities;
}
sub filelog_priorities { return $_[0]->{'_filelog_priorities'}; }
##############################################################################

=head2 syslog_priorities

The same as B<filelog_priorities> applies to B<syslog_priorities>.

=cut

sub _create_syslog_priorities {
   my ( $self, $rc_priority ) = @_;
   my @priorities =
     qw( debug info notice warn warning error err crit alert emerg panic );

   my ( $found, %priorities );
   for my $thisprior (@priorities) {
      if ( $found or $thisprior eq lc $rc_priority ) {
         $priorities{$thisprior} = 1;
         $found++;
      }
   }
   $self->{'_syslog_priorities'} = \%priorities;
}

sub syslog_priorities { return $_[0]->{'_syslog_priorities'}; }

##############################################################################
# $apiis->Cache->GetCache( 'namespace', $key );
sub GetCache { return $_[0]->{$_[1]}{$_[2]}; }
# $apiis->Cache->SetCache( 'namespace', $key, $value );
sub SetCache { $_[0]->{$_[1]}{$_[2]} = $_[3]; }
##############################################################################

1;
