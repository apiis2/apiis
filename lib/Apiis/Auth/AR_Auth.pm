##############################################################################
# $Id: AR_Auth.pm,v 1.5 2006/04/19 06:00:47 marek Exp $
##############################################################################
package Apiis::Auth::AR_Auth;
$VERSION = '$Revision ';
##############################################################################

=head1 NAME

Apiis::Auth::AR_Auth -- object for provading data about user access rights

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut

##############################################################################

use strict;
use warnings;

use Carp;
use Apiis::Init;
use Apiis::Auth::AR_Auth::SystemTask;
use Apiis::Auth::AR_Auth::DatabaseTask;
use Data::Dumper;

 @Apiis::Auth::AR_Auth::ISA = qw ( 
   Apiis::Init 
 );

{    # private class data and methods to leave the closure:
  my @methods = qw/ object_info /;

  my %_attr_data = (
         _object_info            => undef,    # scalar
         _get_user_db_access_rights           => undef,    # scalar
	 #_object_user            => undef,    # scalar
	 #__applications	       => undef,    # array
   );
   sub _standard_keys { keys %_attr_data; }
   sub methods {
      wantarray && return @methods;
      return \@methods;
   }
  
}    # end private class data:
##############################################################################

=head2 new (public)
 
  returns an object reference for a new Auth object.

=cut

sub new{
  my ($invocant,%args) = @_;
  my ($local_status,@errors);
  croak "Missing initialisation in main file (", __PACKAGE__, ").\n" unless defined $apiis;
  my ($package,$file,$line) = caller;

  my $class = ref($invocant) || $invocant;
  my $self = bless {}, $class; 
  $self->_init(%args);
  return $self;
}

##############################################################################

=head2 _init (internal)

  the main initialization of the Auth object.

=cut

sub _init {
  my ($self, %args) = @_;
  my $pack = __PACKAGE__;
  return if $self->{"_init"}{$pack}++;

 EXIT:{
  if ((not exists $args{auth_user}) or (not exists $args{auth_obj_type})){
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::AR_Auth::_init',
        msg_short => __("No key 'auth_user' or 'auth_obj_type' passed to Apiis::Auth::AR_Auth"),
      )
    );
    last EXIT;
  }else{
  ### check if the user object was created ###
    unless ($apiis->exists_user){
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::AR_Auth::_init',
          msg_short => __("User Object was not joined to the Apiis structure"),
        )
      );
      last EXIT ;
    }

    #INTERNAL METHODS   
    $self->{'_object_type'} = $args{auth_obj_type};
    $self->{'_object_user'} = $args{auth_user};
    $self->{'_st_not_defined'} = 1;
    $self->{'_dbt_not_defined'} = 1;

    if ($self->{'_object_type'} eq "Complete Object"){
      $self->_get_user_dbt_access_rights;
      $self->_get_user_st_access_rights;
    }elsif($self->{'_object_type'} eq "DBT"){
      $self->_get_user_dbt_access_rights;
    }elsif($self->{'_object_type'} eq "ST"){
      $self->_get_user_st_access_rights;
    }else{
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::AR_Auth::_init',
          msg_short => __("Wrong object type definition"),
          msg_long  => __("If you want to specify object type than you can only set 'DBT' or 'ST'
           value as a second parameter. The second parameter can also
           be empty and in such case object is created for both type 
           of the access rights."),
        )
      );
      last EXIT;
    }
    if ($self->{'_st_not_defined'} and $self->{'_dbt_not_defined'}){
      my $msg_sh = __("System and database access rights 
                       are not defined for the user '[_1]'. 
                       Auth Object can not be created.",$self->{'_object_user'});
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
          type      => 'AUTH',
          severity  => 'CRIT',
          from      => 'Apiis::Auth::AR_Auth::_init',
          msg_short => $msg_sh,
        )
      );
      last EXIT;
    }
  }
 }#EXIT
}

##############################################################################
### INITIALISATION METHODS ###################################################
##############################################################################

=head2 _get_user_dbt_access_rights (internal) 

  creates the hash with the user DB access rights which are read form the 
  user access view.

=cut

sub _get_user_dbt_access_rights {
   my $self = shift;
   my %ar_hash = ();

 EXIT:{
   if ($self->_exists_dbt) {
     $apiis->log( 'warning',"_get_user_dbt_access_rights: 
      the access rights for the database tasks were already collected, ignored.");
     last EXIT;
   }

   my $sql = "SELECT table_name,sqlaction,table_columns,descriptor_name,descriptor_value 
                FROM ".$self->{'_object_user'}.".v_dbtar_".$self->{'_object_user'}."";
   my $fetched  = $apiis->DataBase->sys_sql($sql);
   if ($fetched->status){
     $self->errors( $fetched->errors );
     $self->status(1);
     last EXIT;
   }
   if ($fetched->handle->rows){ 
     while ( my $ret = $fetched->handle->fetch ){
       my %tmp_hash;
       %tmp_hash = (
         descriptor_name   => $ret->[3],
         descriptor_value  => $ret->[4],
       );
       push @{$ar_hash{$ret->[1]}{$ret->[0]}{$ret->[2]}},\%tmp_hash;
     }
   }else{
     my $msg = __("User [_1] is not allowed to execute any 'Database Task' - 
                   access rights are not defined '[_1]'",$self->{'_object_user'});
     $apiis->log('info',"$msg");
     last EXIT; 
   }
   $self->{'_dbt_not_defined'} = 0;
   $self->{'_dbt_ar'} = \%ar_hash;
 }#EXIT
}
##############################################################################

=head2 _get_user_st_access_rights (internal) 

  creates the hash with the user system task access rights.

=cut

sub _get_user_st_access_rights {
   my $self = shift;
   my %ar_hash = ();
   my $system_user = $apiis->Model->db_user;

 EXIT:{
   if ($self->_exists_st) {
     $apiis->log( 'warning',"_get_user_st_access_rights: the access rights for the system tasks
     were already collected, ignored.");
     last EXIT;
   }

   my $sql = "SELECT stpolicy_name,stpolicy_type FROM "
              .$self->{'_object_user'}.".v_star_".$self->{'_object_user'}."";
   my $fetched  = $apiis->DataBase->sys_sql($sql);
   if ($fetched->status){
     $self->errors( $fetched->errors );
     $self->status(1);
     last EXIT;
   }
   if ($fetched->handle->rows){ 
     while ( my $ret = $fetched->handle->fetch ){
       push @{$ar_hash{$ret->[1]}},$ret->[0];
     }
   }else{
     my $msg = __("User [_1] is not allowed to execute any 'System Task' - 
                   access rights are not defined.",$self->{'_object_user'});
     $apiis->log('debug',"$msg");
     last EXIT; 
   }
   $self->{'_st_not_defined'} = 0;
   $self->{'_st_ar'} = \%ar_hash;
 }#EXIT
}
##############################################################################

=head2 _exists_dbt (internal)

The method returns 1 if the access rights for the database tasks were already
collected, 0 otherwise.

=cut

sub _exists_dbt {
   return 1 if exists $_[0]->{"_dbt_ar"};
   return 0;
}
##############################################################################

=head2 _exists_st (internal)

The method returns 1 if the access rights for the system tasks were already
collected, 0 otherwise.

=cut

sub _exists_st {
   return 1 if exists $_[0]->{"_st_ar"};
   return 0;
}

##############################################################################

=head2 _get_user_id (internal)

  get the curent user id from the users table

=cut
 
sub _get_user_id {
  my $self = shift;

 EXIT:{
  my $sql = "SELECT user_id FROM ar_users 
             WHERE user_login='".$self->{'_object_user'}."'";
  my $fetched  = $apiis->DataBase->sys_sql($sql);
  if ($fetched->status){
    $self->errors( $fetched->errors );
    $self->status(1);
    last EXIT;
  }
  if ($fetched->handle->rows) { 
    while ( my $ret = $fetched->handle->fetch ) {
      $self->{'_user_id'} = $ret->[0];
    }
  }else{
    my $msg = __("No such user in the database user: '[_1]'",$self->{'_object_user'});
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::AR_Auth::_get_user_id',
	msg_short => __("No such user in the database user: \"[_1]\"",$self->{'_object_user'}),
      )
    );
    last EXIT;
  }
 }#EXIT 
 return $self->{'_user_id'}; 
}

##############################################################################
### GENERAL PUBLIC METHODS ####################################################
##############################################################################

=head2 user_disabled (public) 

  This method check if the user is locked for logging to the system. It returns
  True or False value which is taken from the column 'user_disabled' from 
  table ar_users.

=cut

sub _get_user_disabled {
  my $self = shift;

 EXIT:{
  my $sql = "SELECT user_disabled FROM ar_users 
             WHERE user_login='".$self->{'_object_user'}."'";
  my $fetched  = $apiis->DataBase->sys_sql($sql);
  if ($fetched->status){
    $self->errors( $fetched->errors );
    $self->status(1);
    last EXIT;
  }

  if ($fetched->handle->rows) { 
    while ( my $ret = $fetched->handle->fetch ) {
      $self->{'_user_disabled'} = $ret->[0];
    }
  }else{
    my $msg = __("No such user in the database: '[_1]'",$self->{'_object_user'});
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::AR_Auth::_get_user_disabled',
	msg_short => __("No such user in the database: \"[_1]\"",$self->{'_object_user'}),
      )
    );
    last EXIT;
  }
 }#EXIT
 return $self->{'_user_disabled'};
}

##############################################################################
### SYSTEM TASKS METHODS #####################################################
##############################################################################
sub check_system_tasks {&Apiis::Auth::AR_Auth::SystemTask::_check_system_tasks;}

##############################################################################
### DATABASE TASKS METHODS ###################################################
##############################################################################
sub check_tables {&Apiis::Auth::AR_Auth::DatabaseTask::_check_tables;}
sub check_columns {&Apiis::Auth::AR_Auth::DatabaseTask::_check_columns;}
sub check_descriptors {&Apiis::Auth::AR_Auth::DatabaseTask::_check_descriptors;}
sub descriptor_fulfiled {&Apiis::Auth::AR_Auth::DatabaseTask::_descriptor_fulfiled;}
sub check_sql_statement {&Apiis::Auth::AR_Auth::DatabaseTask::_check_sql_statement;}

##############################################################################
### GENERAL PUBLIC METHODS ###################################################
##############################################################################
sub user_disabled {
  return $_[0]->{'_user_disabled'} if exists $_[0]->{'_user_disabled'};
  return $_[0]->_get_user_disabled; 
}

sub user_id {
  return $_[0]->{'_user_id'} if exists $_[0]->{'_user_id'};
  return $_[0]->_get_user_id; 
}
##############################################################################

1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

__END__

