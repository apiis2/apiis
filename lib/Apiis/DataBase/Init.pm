###########################################################################
# $Id: Init.pm,v 1.48 2019/10/02 21:58:06 ulf Exp $
###########################################################################
package Apiis::DataBase::Init;
$VERSION = '$Revision ';

=head1 NAME

Apiis::DataBase::Init -- Basic database initialisation

=head1 SYNOPSIS

Database Initialisation based on the configuration in apiisrc and model file

=head1 DESCRIPTION

When loading the model file, database initialisation usually is done
automatically. For certain special cases it can be delayed.

=cut

use strict;
use warnings;
use DBI;
use Carp;
use Data::Dumper;
use Apiis::Init;
use Apiis::DataBase::Record;
use Apiis::DataBase::SQL::DirectSQL;

# provide the sql methods for $apiis->DataBase:
@Apiis::DataBase::Init::ISA = qw(
  Apiis::DataBase::SQL::DirectSQL
);

our ( $apiis );

sub new {
   my ( $invocant, %args ) = @_;
   croak "Missing initialisation in main file (", __PACKAGE__, ")\n"
     unless defined $apiis;
   croak 'Model not joined into $apiis' unless $apiis->exists_model;

   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init(%args);
   if ( $self->status ) {
      $apiis->errors( $self->errors );
      $apiis->status( $self->status );
   }
   return $self;
}

##############################################################################
sub _init {
   my ( $self, %args ) = @_;
   my $pack = __PACKAGE__;
   # no strict "refs";
   return if $self->{"_init"}{$pack}++;    # Conway p.  243

   $self->{_dbh}            = undef;
   $self->{_sys_dbh}        = undef;
   $self->{_user_dbh}       = undef;
   $self->{_connected_sys}  = undef;
   $self->{_connected_user} = undef;
   $self->_populate_database( $apiis->Model->db_driver );

#   unless ( $self->status ) {
#      if ( exists $args{'database'} and $args{'database'} == 0 ) {
#         $apiis->log( 'notice',
#            "Apiis::DataBase::_init: Object created without database connection by os_user "
#            . $apiis->os_user );
#      } else {
#         $self->_connect_db(%args);
#      }
#   }
}

##############################################################################
# fill the DataBase area with values from the configuration file:
sub _populate_database {
   my $self   = shift;
   my $driver = shift;
   use Config::Auto;
   my $location = $apiis->APIIS_HOME . '/etc';
   my $config;
   eval { $config   = Config::Auto::parse("$location/${driver}.conf") };
   if ($@) {
      $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => '_populate_database',
            msg_short => __("Cannot find database configuration file."),
            msg_long  => $@,
         )
      );
      $self->status(1);
   } else {
      $self->{_datesep}         = $config->{FORMATS}->{DATESEP};
      $self->{_dateorder}       = $config->{FORMATS}->{DATEORDER};
      $self->{_sequence_call}   = $config->{MISC}->{SEQUENCE_CALL};
      $self->{_rowid}           = $config->{MISC}->{ROWID};
      $self->{_db_has_sequence} = $config->{MISC}->{DB_HAS_SEQUENCE};
      $self->{_explain}         = $config->{MISC}->{EXPLAIN};

      # to expand variables in the config file:
      my $db_name     = $apiis->Model->db_name;
      my $db_user     = $apiis->Model->db_user;
      my $db_host     = $apiis->Model->db_host;
      my $db_port     = $apiis->Model->db_port;
      my $db_password = $apiis->Model->db_password;
      my $connect     = eval qq{qq{$config->{MISC}->{CONNECT}}};
      croak $@ if $@;
      $self->{_connect} = $connect;

      foreach ( keys %{ $config->{DATATYPES} } ) {
         $self->{_datatypes}->{ uc $_ } = $config->{DATATYPES}->{$_};
      }
      foreach ( keys %{ $config->{BINDTYPES} } ) {
         $self->{_bindtypes}->{ uc $_ } = $config->{BINDTYPES}->{$_};
      }

      sub connect { shift()->_connect_db( @_ ) }

      foreach my $thiskey ( keys %{$self} ) {
         $thiskey =~ s/^_//;
         next if $thiskey eq 'init';
         next if $thiskey eq 'datatypes';
         next if $thiskey eq 'bindtypes';
         next if $self->can($thiskey);
         no strict "refs";
         *$thiskey = sub { return $_[0]->{"_$thiskey"}; }
      }
   }
}

# without an argument, datatypes and bindtypes return an array of
# available data-/bindtypes. To get the value of one type you
# must invoke $apiis->DataBase->datatypes('char');
sub datatypes {
    my ( $self, $arg ) = @_;
    return if !$apiis->exists_database;
    if ($arg) {
        # last EXIT if !exists $self->{'_datatypes'}->{ uc "_$arg" };
        return $self->{'_datatypes'}->{ uc $arg };
    }
    return keys %{ $self->{'_datatypes'} }
}
sub bindtypes {
    my ( $self, $arg ) = @_;
    return if !$apiis->exists_database;
    if ($arg) {
        # last EXIT if !exists $self->{'_bindtypes'}->{ uc "_$arg" };
        return $self->{'_bindtypes'}->{ uc $arg };
    }
    return keys %{ $self->{'_bindtypes'} }
}

##############################################################################
sub _connect_db {
   my ( $self, %args ) = @_;
   my ( $thisuser, $thispasswd, $db_handle );
   my $app_user = 0;
   EXIT: {
      if ( exists $args{'user'} and lc $args{'user'} eq 'application' ){
         if ( not $self->connected_sys ) {
            $self->status(1);
            $self->errors(
               Apiis::Errors->new(
                  type      => 'DB',
                  severity  => 'ERR',
                  from      => '_connect_db',
                  msg_short => __( "Cannot connect application user to database."),
                  msg_long  => __( "Connect system user first with '\$apiis->DataBase->connect;'"),
               )
            );
            last EXIT;
         }

         # connect the apiis user (not system): 
         if ( $self->connected_user ) {
             my ( $package, $file, $line ) = caller();
             $apiis->log( 'warning', sprintf(
                     "DataBase::Init::_connect_db: "
                     . "user connection already exists. Called from %s line %s",
                     $file, $line
                 )
             );
             last EXIT;
         }

         # skip auth completely and give user all rights if so configured:
        if ( lc $apiis->access_rights eq 'none' ) {
            $self->{_user_dbh} = $self->{_sys_dbh};
            $apiis->log( 'notice',
                      q{System DB-handle cloned to user. }
                    . q{No access_rights configured} );
            last EXIT;
        }

         $app_user = 1;
         if ( exists $args{'userobj'} ){
            $apiis->_join_user(\%args);
            # $apiis->check_status; # debug
            last EXIT if $apiis->status;
         } 

         $thisuser = $apiis->User->id;
         $thispasswd = $apiis->User->_passwd; # cleartext!
         $apiis->log('debug', "_connect_db: going to connect as user $thisuser");
         # $apiis->log('debug', "_connect_db: going to connect as user $thisuser / $thispasswd");
      } else {
         # connect the system user:
         if ( $self->connected_sys ){
            $apiis->log('warning',
               "DataBase::Init::_connect_db: a system connection to the database exists already");
            last EXIT;
         }
         $thisuser = $apiis->Model->db_user;
         $thispasswd = $apiis->Model->db_password;
         $apiis->log('debug', "_connect_db: going to connect as system user $thisuser");
      }
   
      eval {
         $db_handle = DBI->connect(
            $self->{_connect}, $thisuser, $thispasswd,
              { RaiseError => 1,
                AutoCommit => 0,
                PrintError => 0,
                PrintWarn  => 0 }
         );
	 # setting utf8 flag for retrieved data if database is in Unicode
	 if ( $apiis->Model->db_driver eq 'Pg' ) {
         if ($apiis->Model->db_pg_enable_utf8) {
	        $db_handle->{pg_enable_utf8}=1 if (lc $apiis->Model->db_encoding eq 'unicode');
         } else {
            $db_handle->{pg_enable_utf8}=0;         
         }
	 }
      };
      if ($@) {
         my $err_msg = $@;
         chomp $err_msg;
         $self->status(1);
         $self->errors(
            Apiis::Errors->new(
               type      => 'DB',
               severity  => 'CRIT',
               from      => '_connect_db',
               msg_short => __("Cannot connect user '[_1]' to database.", $thisuser ),
               msg_long  => __( "Database error: [_1]", $err_msg ),
            )
         );
         last EXIT;
      }

      $app_user ? ($self->{_connected_user} = 1) : ($self->{_connected_sys} = 1);

      # set datestyle to a well defined format:
      if ( $apiis->Model->db_driver eq 'Pg' ) {
         # we need some more experience from other databases to find a
         # generic way for defining dateformats. Until then we have to live
         # with a hardcoded workaround.  what about:
         # $ENV{"NLS_DATE_FORMAT"} = "yyyymmddhh24miss"; (oracle) also have
         # a look at sql-ledger->User.pm->sub dbconnect_vars.
         my $sqltext = "set datestyle='ISO'";
         eval {
            local $db_handle->{RaiseError} = 1 unless $db_handle->{RaiseError};
            local $db_handle->{PrintError} = 0 if $db_handle->{PrintError};
            my $sth = $db_handle->prepare($sqltext);
            $sth->execute;
         };
         if ($@) {
            my $err_msg = $@;
            chomp $err_msg;
            $self->errors(
               Apiis::Errors->new(
                  type      => 'DB',
                  severity  => 'WARNING',
                  from      => '_connect_db',
                  msg_short => __("Problems to set ISO-dateformat for user '[_1]'", $thisuser),
                  msg_long  => $err_msg,
               )
            );
            $self->status(1);
            last EXIT;
         }
         else {
             $apiis->log('debug', '_connect_db: Pg::datestyle successfully set to ISO');
         }
      }
   
      if ($app_user) {
         $self->{_user_dbh} = $db_handle;
      } else {
         $self->{_dbh}     = $db_handle;    # compat, removed later
         $self->{_sys_dbh} = $db_handle;
         # Fill DataBase structure with user information:
         # $self->_fill_db_users_struct; # no caching due to performance problems (20.12.04 - heli)
         # $self->check_status;    # debug
         $self->_get_roles;
         last EXIT if $self->status;
         $apiis->log( 'debug',
            "_join_database: DataBase structure joined into \$apiis and filled with user data"
         );
      }
   
      # some logging:
      $apiis->log( 'notice',
         sprintf "Connected to database %s (%s %s) on host %s, user %s",
         $apiis->Model->db_name, $db_handle->get_info(17), $db_handle->get_info(18),
         $apiis->Model->db_host, $thisuser );
   } # label EXIT

   if ( $self->status ){
      for ( $self->errors ) {
          if (   $_->severity eq 'CRIT'
              or $_->severity eq 'ALERT'
              or $_->severity eq 'EMERG'
              or $_->severity eq 'PANIG' )
          {
              $apiis->status(1);
              $apiis->errors( scalar $self->errors );
          }
      }
   }
}

sub user_dbh { return $_[0]->{_user_dbh}; }
sub sys_dbh { return $_[0]->{_sys_dbh}; }
sub _fill_db_users_struct {
   $_[0]->_get_users;
   $_[0]->_get_roles;
   $_[0]->_get_user_roles;
}

##############################################################################

=head2 $apiis->DataBase->disconnect()

B<$apiis->DataBase->disconnect()> disconnects the global database handle
$dbh ($apiis->DataBase->dbh) from the database. If you pass a handle to
B<disconnect()> like:

   $apiis->DataBase->disconnect( $my_db_handle );

then this $my_db_handle will be disconnected.

=cut

sub disconnect {
    my ( $self, $db_handle ) = @_;

    my @handles;
    if ($db_handle) {
        push @handles, $db_handle;
    }
    else {
        push @handles, $self->sys_dbh;
        push @handles, $self->user_dbh;
    }

    # DBI::disconnect the handles now:
    eval { $_->disconnect for @handles };
    if ($@) {
        my $err_msg = $@;
        chomp $err_msg;
        $apiis->errors(
            Apiis::Errors->new(
                type      => 'DB',
                severity  => 'CRIT',
                from      => 'disconnect',
                msg_short => __("Cannot disconnect from database"),
                msg_long  => $err_msg,
            )
        );
        $apiis->status(1);
    }
    else {
        # remove the handles from the $apiis-structure:
        HANDLE:
        for my $handle (qw/_dbh _sys_dbh _user_dbh/) {
            next HANDLE if !$self->{$handle};
            next HANDLE if $self->{$handle}->{Active};
            $self->{$handle} = undef;
            $apiis->log( 'info', sprintf
                'Database handle %s disconnected successfully', $handle );
        }
    }
}

##############################################################################

=head2 commit(), user_commit(), sys_commit(), rollback(), user_rollback(), sys_rollback()

These methods commit/rollback all transactions for either the system
or the user database handle.

While

   $apiis->DataBase->sys_commit;
   $apiis->DataBase->sys_rollback;

and

   $apiis->DataBase->commit;
   $apiis->DataBase->rollback;

commit/rollback changes to the system database handle,

   $apiis->DataBase->user_commit;
   $apiis->DataBase->user_rollback;

perform this for the user database handle.

If the commit/rollback fails, an error object is created and an error status
of 1 is returned and the $object->status is set to 1.

=cut

sub user_commit {
    $_[0]->_commit_back( { action => 'commit' } );
}

sub sys_commit {
    $_[0]->_commit_back( { user => 'system', action => 'commit' } );
}

sub commit {
    $_[0]->_commit_back( { user => 'system', action => 'commit' } );
}

sub user_rollback {
    $_[0]->_commit_back( { action => 'rollback' } );
}

sub sys_rollback {
    $_[0]->_commit_back( { user => 'system', action => 'rollback' } );
}

sub rollback {
    $_[0]->_commit_back( { user => 'system', action => 'rollback' } );
}

# do a commit or rollback:
sub _commit_back {
    my ( $self, $args_ref ) = @_;
    my ( $dbh,  $user );
    my $action = $args_ref->{action};

    if ($args_ref) {
        $user = 'system' if lc $args_ref->{user} eq 'system';
    }

    if ($user) {
        # system database handle:
        $dbh = $self->sys_dbh;
    }
    else {
        # user database handle:
        $dbh  = $self->user_dbh;
        $user = $apiis->User->id || 'application';
    }

    # now run the action:
    eval { $dbh->$action };
    if ($@) {
        my $err_msg = $@;
        chomp $err_msg;
        $apiis->errors(
            Apiis::Errors->new(
                type      => 'DB',
                severity  => 'CRIT',
                from      => "Apiis::DataBase::Init->$action",
                msg_long  => $err_msg,
                msg_short => __(
                    "Could not [_1] the current transaction ([_2])",
                    $action, $user ),
            )
        );
        $self->status(1);
        $apiis->status(1); # ???
    }
    else {
        $apiis->log( 'info', "transaction: $action successful ($user)" );
    }
    return $self->status || 0;
}

###########################################################################

=head2 seq_next_val

   $apiis->DataBase->seq_next_val( <sequence_name> );

returns the next value of the sequence <sequence_name>.

=cut

sub seq_next_val {
   my ( $self, $seq_name ) = @_;
   my $nextval;

   if ($seq_name) {
      my %sql_args = (
          statement => sprintf($apiis->DataBase->sequence_call, $seq_name),
          user      => 'system',
      );
      my $seqqq = $apiis->DataBase->sql( \%sql_args );
      if ( scalar $seqqq->errors ) {
         $self->errors( $seqqq->errors );
         $self->status(1);
         $apiis->log( 'err', "seq_next_val: failed for sequence '$seq_name'" );
      } else {
         while ( my $row_ref = $seqqq->handle->fetch ) {
            $nextval = $row_ref->[0];
         }
      }
   } else {
      $self->status(1);
      $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'CRIT',
            db_table  => $self->tablename,
            from      => 'seq_next_val',
            msg_short => "No sequence name passed",
         )
      );
   }
   return $nextval;
}
##############################################################################

=head2 _get_users (internal)

B<_get_users> retrieves all configured users from table 'users' and fills
an internal datastructure to access the needed values.

B<_get_users> is invoked by Apiis::Init::_join_database.

Note: As this served as some kind of caching and we have performance
problems during initialization (especially for the web interface), this
approach will be deactivated and replaced by queries for every single user
(based on the login data). (20.12.04 - heli)

=cut

sub _get_users {
    my $self = shift;
    my ( $tablename, $query_col, %take_col );

    my @oldcolumns = qw{ user_id login };
    my @newcolumns = qw{ user_id user_login   };
    # old auth setup (should be removed later):
    if ( lc $apiis->access_rights eq 'auth' ) {
        $tablename = 'users';
        $query_col = 'login';
        for my $idx ( 0 .. $#newcolumns ) {
            $take_col{ $newcolumns[$idx] } = $oldcolumns[$idx];
        }
    }

    # new auth setup:
    if ( lc $apiis->access_rights eq 'ar' ) {
        $tablename = 'ar_users';
        $query_col = 'user_login';
        %take_col  = map { $_ => $_ } @newcolumns;
    }

    my $users = Apiis::DataBase::Record->new( tablename => $tablename, );
    $users->column( $take_col{user_id} )->extdata('not null');
    my @query_records = $users->fetch(
        expect_rows    => 'many',
        expect_columns => [$query_col],
        user           => 'system',
    );

    # get elements of user object from DB record:
    for my $thisrecord (@query_records) {
        $thisrecord->decode_record;
        my $thisuser =
            join( ' ', $thisrecord->column( $take_col{user_login} )->extdata );
        $self->Apiis::DataBase::Init::_get_user($thisuser);
    }
}
##############################################################################

=head2 _get_user (internal)

B<_get_user> retrieves the data for the passed user from table 'users' and fills
an internal datastructure to access the needed values.

B<_get_user> is invoked by Apiis::DataBase::Init::verify_user.

=cut

sub _get_user {
    my ( $self, $thisuser ) = @_;
    my $ar_type = lc $apiis->access_rights;

    # exit early if auth is skipped totally:
    return if $ar_type eq 'none';

    # migrating auth setup:
    my ( $tablename, @columns, %take_col );
    my @oldcolumns =
        qw{ user_id login password lang_id user_node session_id };
    my @newcolumns = qw{
        user_id           user_login   user_password
        user_language_id  user_marker  user_session_id };

    # old auth setup (should be removed later):
    if ( $ar_type eq 'auth' ) {
        $tablename = 'users';
        @columns   = @oldcolumns;
        for my $idx ( 0 .. $#newcolumns ) {
            $take_col{ $newcolumns[$idx] } = $oldcolumns[$idx];
        }
    }

    # new auth setup:
    if ( $ar_type eq 'ar' ) {
        $tablename = 'ar_users';
        @columns   = @newcolumns;
        %take_col  = map { $_ => $_ } @newcolumns;
    }

    # create Record object and query for login user:
    my $db_user = Apiis::DataBase::Record->new( tablename => $tablename );
    $db_user->column( $take_col{user_login} )->extdata($thisuser);
    my @query_records = $db_user->fetch(
        expect_rows    => 'one',
        expect_columns => \@columns,
        user           => 'system',
    );

    # get elements of user object from DB record:
    RECORD:
    for my $thisrecord (@query_records) {
        $thisrecord->decode_record;

        # create new object with user login name:
        my $usr_obj = Apiis::DataBase::User->new( id => $thisuser );
        last RECORD if !defined $usr_obj;
        if ( $usr_obj->status ) {
            $self->status( $usr_obj->status );
            $self->errors( $usr_obj->errors );
            last RECORD;
        }

        # load all data from query into user object:
        COLUMN:
        for my $col (@columns) {
            next COLUMN if $col eq $take_col{user_login};    # already done
            my $extdata_ref = $thisrecord->column($col)->extdata;
            my $extdata = $extdata_ref->[0] if $extdata_ref;
            if ( defined $extdata ) {
                if ( $col eq $take_col{user_password} ) {
                    $usr_obj->password( $extdata, encrypted => 1 );
                    next COLUMN;
                }
                # default
                $usr_obj->$col($extdata);
            }
        }
        $apiis->log( 'debug',
            sprintf "Adding user '%s' to DataBase structure", $thisuser );
        $self->{'_db_users'}{$thisuser} = $usr_obj;

        # get cleartext language:
        my $thislang = $usr_obj->user_language_id;
        last RECORD if !defined $thislang;

        my $languages =
            Apiis::DataBase::Record->new( tablename => 'languages', );
        $languages->column('lang_id')->extdata($thislang);
        my @lang_query = $languages->fetch(
            expect_rows    => 'one',
            expect_columns => [qw( iso_lang )],
            user           => 'system',
        );
        foreach my $thisrecord (@lang_query) {
            $thisrecord->decode_record;
            my $this_iso_lang = $thisrecord->column('iso_lang')->extdata->[0];
            if ( defined $this_iso_lang ) {
                $usr_obj->language($this_iso_lang);
            }
        }
    }
}

##############################################################################
=head2 _get_roles (internal)

B<_get_roles> retrieves all roles from table 'roles' and fills
an internal datastructure to access the needed values.

=cut

sub _get_roles {
    my $self = shift;
    my $ar_type = lc $apiis->access_rights;

    EXIT: {
        # access rights switched of completely:
        if ( $ar_type eq 'none' ){
            last EXIT;
        }

        # migrating auth setup:
        my ( $tablename, @columns, %take_col );
        my @oldcolumns = qw{ role_id role };
        my @newcolumns = qw{ role_id role_name };

        # old auth setup (should be removed later):
        if ( $ar_type eq 'auth' ) {
            $tablename = 'roles';
            @columns   = @oldcolumns;
            for my $idx ( 0 .. $#newcolumns ) {
                $take_col{ $newcolumns[$idx] } = $oldcolumns[$idx];
            }
        }

        # new auth setup:
        if ( $ar_type eq 'ar' ) {
            $tablename = 'ar_roles';
            @columns   = @newcolumns;
            %take_col  = map { $_ => $_ } @newcolumns;
        }

        if ( !$tablename ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::DataBase::Init::_get_roles',
                    msg_short => __( q{Unknown parameter: '[_1]'}, $ar_type ),
                    msg_long  => __(
                        q{Error in apiisrc, key '[_1]'}, 'access_rights'
                    ),
                )
            );
            $self->status(1);
            last EXIT;
        }

        # create Record object and retrieve all roles:
        my $roles = Apiis::DataBase::Record->new( tablename => $tablename, );

        if ( !$roles ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::DataBase::Init::_get_roles',
                    msg_short => __(
                        q{Cannot create Record object for table: '[_1]'},
                        $tablename
                    ),
                )
            );
            last EXIT;
        }
        if ( $roles->status ) {
            $self->status(1);
            $self->errors( scalar $roles->errors );
            $roles->status(0);
            $roles->del_errors();
            last EXIT;
        }

        $roles->column( $take_col{role_id} )->extdata('not null');
        my @query_records = $roles->fetch(
            expect_rows    => 'many',
            expect_columns => \@columns,
            user           => 'system',
        );

        # store roles in internal structure:
        foreach my $thisrecord (@query_records) {
            $thisrecord->decode_record;
            my $thisrole_ref =
                $thisrecord->column( $take_col{role_name} )->extdata;
            my $thisrole = $thisrole_ref->[0] if $thisrole_ref;
            my $role_id_ref =
                $thisrecord->column( $take_col{role_id} )->extdata;
            my $role_id = $role_id_ref->[0] if $role_id_ref;
            if ( defined $thisrole and defined $role_id ) {
                $self->{'__db_roles'}{$role_id} = $thisrole;
            }
        }
    }    # end label EXIT
}

##############################################################################

=head2 _get_user_roles (internal)

All roles of the $apiis->DataBase->users are fetched from database and stored
in the user objects.

B<_get_user_roles> is invoked by Apiis::Init::_join_database.

=cut

sub _get_user_roles {
    my ( $self, $user_obj ) = @_;
    my $ar_type = lc $apiis->access_rights;

    EXIT: {
        # skip early if no auth is configured:
        last EXIT if $ar_type eq 'none';

        # migrating auth setup:
        my $tablename;

        # old auth setup (should be removed later):
        if ( $ar_type eq 'auth' ) {
            $tablename = 'user_roles';
        }

        # new auth setup:
        if ( $ar_type eq 'ar' ) {
            $tablename = 'ar_user_roles';
        }

        if ( !$tablename ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::DataBase::Init::_get_user_roles',
                    msg_short => __( q{Unknown parameter: '[_1]'}, $ar_type ),
                    msg_long  => __(
                        q{Error in apiisrc, key '[_1]'}, 'access_rights'
                    )
                )
            );
            last EXIT;
        }

        # create Record object and retrieve data:
        my $roles = Apiis::DataBase::Record->new( tablename => $tablename, );
        if ( defined $user_obj ) {
            $roles->column('user_id')->extdata( $user_obj->user_id );
        }
        else {
            $roles->column('user_id')->extdata('not null');
        }
        my @query_records = $roles->fetch(
            expect_rows    => 'many',
            expect_columns => [qw( user_id role_id )],
            user           => 'system',
        );
        if ( $roles->status ) {
            $self->status( $roles->status );
            $self->errors( $roles->errors );
            last EXIT;
        }

        # store all roles for a user in a hash (key = user_id ) of arrays:
        my %roles_hash;
        foreach my $thisrecord (@query_records) {
            push @{ $roles_hash{ $thisrecord->column('user_id')->intdata } },
                $self->{'__db_roles'}{$thisrecord->column('role_id')->intdata};
        }

        if ( defined $user_obj ) {
            $user_obj->roles( \@{ $roles_hash{ $user_obj->user_id } } );
        }
        else {
            foreach my $thisuser ( $apiis->DataBase->users ) {
                $apiis->DataBase->user($thisuser)->roles(
                    \@{$roles_hash{$apiis->DataBase->user($thisuser)->user_id}}
                );
            }
        }
    } # end label EXIT
}

##############################################################################

=head2 users (public)

B<users> returns all database users of this project.

=cut

sub users {
   my $self = shift;
   my @users = keys %{$self->{'_db_users'}};
   wantarray && return @users;
   return \@users;
}
##############################################################################

=head2 user (public)

B<user> returns a User object for the passed user.

=cut

sub user {
   my ( $self, $thisuser ) = @_;
   return $self->{'_db_users'}{$thisuser} if exists $self->{'_db_users'};
}
##############################################################################

=head2 verify_user (internal)

B<verify_user> checks the login data of the passed user object (name and
password) against the internal values from the database.

=cut

sub verify_user {
   my ( $self, $usr_obj ) = @_;
   my ( $package, $file, $line ) = caller;
   my $local_status;

   EXIT: {
      if ( $usr_obj->status ){
          $self->errors( scalar $usr_obj->errors );
          last EXIT;
      }
      my $thisid     = $usr_obj->id;
      my $thispasswd = $usr_obj->password;
      unless ($thispasswd) {
         $local_status = 1;
         $self->errors(
            Apiis::Errors->new(
               type      => 'PARAM',
               severity  => 'ERR',
               from      => 'Apiis::DataBase::Init::verify_user',
               msg_short => __( "Parameter missing: [_1]", 'password' ),
            )
         );
         last EXIT;
      }

      # if the user needs more trials to login (e.g. wrong passwd), she
      # exists already as $apiis->DataBase->user:
      my $already_reloaded = 0;
      RELOAD: {
         # I don't create an error object here as the bad guy does not need to
         # know if the user name does not exist in the database or the password
         # is incorrect. The admin sees it in the logs.
         if ( not grep /^${thisid}$/, $apiis->DataBase->users ) {
            if ($already_reloaded) {
               $apiis->log( 'err', "User '$thisid' does not exist" );
               $local_status = 1;
               last EXIT;
            } else {
               # $self->_fill_db_users_struct;
               $self->_get_user( $thisid );
               last EXIT if $self->status; # case user does not exist
               $self->_get_user_roles( $apiis->DataBase->user($thisid) );
               $already_reloaded = 1;
               $apiis->log('info', "DB user loaded");
               goto RELOAD;
            }
         }
      }

      if ( $apiis->DataBase->user($thisid)->password eq $thispasswd ) {
         $usr_obj->authenticated(1);
         # also flag the database user object as authenticated as this
         # object will be used later in join_user:
         $apiis->DataBase->user($thisid)->authenticated(1);
         $apiis->log( 'notice', "User $thisid verified successfully" );
         # hier jetzt andere Infos über diesen user holen (roles) heli
      } else {
         $apiis->log( 'err', "Wrong password for user $thisid" );
         $local_status = 1;
         last EXIT;
      }
   }
   if ($local_status) {
      $self->status(1);
      $self->errors(
         Apiis::Errors->new(
            type      => 'AUTH',
            severity  => 'CRIT',
            from      => 'Apiis::DataBase::User::verify_user',
            msg_short => __("Authentication failed"),
         )
      );
   }
   return $local_status;
}

sub connected_sys {
    my ( $self, $arg ) = @_;
    $self->{_connected_sys} = $arg if defined $arg;
    return $self->{_connected_sys};
}

sub connected_user {
    my ( $self, $arg ) = @_;
    $self->{_connected_user} = $arg if defined $arg;
    return $self->{_connected_user};
}
##############################################################################

=head2 crosstab

B<crosstab> is a wrapper around the CPAN-Modules DBIx::SQLCrosstab and
DBIx::SQLCrosstab::Format. They allow a convenient way of creating
cross tabulations from the database and outputting it into different formats.
See 'man DBIx::SQLCrosstab' and 'man DBIx::SQLCrosstab::Format' for details.

$apiis->DataBase->crosstab integrates DBIx::SQLCrosstab into the apiis
framework. It assumes all necessary parameters getting provided with via a
hash reference.

Input parameters:

   * $hash_ref->{params} with all parameters according to DBIx::SQLCrosstab.
     This includes a database handle (either user_dbh or sys_dbh).
   * $hash_ref->{format} defines the output format
   * $hash_ref->{aux} passes an additional parameter, which some formats
     expect, e.g. as_xls('filename'):
        $hash_ref->{format} = 'as_xls';
        $hash_ref->{aux}    = 'filename';

Output parameters:

   * According to the documentation of DBIx::SQLCrosstab::Format

Example:

   my $return_val = $apiis->DataBase->crosstab($hash_ref);

=cut

sub crosstab {
    my ( $self, $args ) = @_;

    my $format    = $args->{format};
    my $params    = $args->{params};
    my $aux_param = $args->{aux};

    my $missing;
    $missing = 'format' if !$format;
    $missing = 'params' if !$params;

    if ( $missing ) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'crosstab',
                msg_short => __("Parameter missing: [_1]", $missing),
            )
        );
        return;
    }

    my $valid_format = {
        as_csv         => 1,           # optional
        as_html        => 0,
        as_xml         => 0,
        as_yaml        => 0,
        as_xls         => 'required',  # require additional parameter
        as_perl_struct => 'required',  # dito
    };

    if ( !exists $valid_format->{$format} ) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'crosstab',
                msg_short => __( "Wrong output format [_1]", $format ),
                msg_long  => sprintf( 'Allowed values: %s',
                    join( q{, }, keys %$valid_format ) ),
            )
        );
        return;
    }

    if ( $valid_format->{$format} eq 'required' and !$aux_param ) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'crosstab',
                msg_short => __("Format [_1] needs an auxiliary parameter", $format),
                msg_long  => "see 'man DBIx::SQLCrosstab::Format' for details",
            )
        );
        return;
    }

    # load the module:
    eval { require DBIx::SQLCrosstab::Format };
    if ($@) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'INSTALL',
                severity  => 'ERR',
                from      => 'crosstab',
                msg_short => sprintf( 'Required module %s not found',
                    'DBIx::SQLCrosstab::Format' ),
            )
        );
        return;
    }

    # now finally do the work:
    my $xtab = DBIx::SQLCrosstab::Format->new($params)
        or die "$DBIx::SQLCrosstab::errstr\n";
    my $query = $xtab->get_query or die "$DBIx::SQLCrosstab::errstr\n";
    $xtab->get_recs  or die "$DBIx::SQLCrosstab::errstr\n";

    return $xtab->$format($aux_param) if $valid_format->{$format};
    return $xtab->$format;
}

##############################################################################
1;

