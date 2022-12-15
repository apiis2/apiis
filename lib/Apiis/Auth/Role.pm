##############################################################################
# $Id: Role.pm,v 1.16 2005/04/11 07:43:26 marek Exp $
##############################################################################

=head1 NAME

Apiis::Auth::Role.pm

=cut

=head1 SYNOPSIS

$role = Apiis::Auth::Role->new(
                                role_shortcut => $role_shortcut,
                               );

=cut

=head1 DESCRIPTION

This is a module for creating an object for handling user roles. These object are used in the authentication process.
All information about roles are taken from the Roles.conf file.

=cut

=head1 METHODS

=cut


package Apiis::Auth::Role;
#$VERSION = '$Revision: 1.16 $';

use strict;
use Carp;
use Data::Dumper;
use warnings;
use Apiis::Init;
use Config::IniFiles;

@Apiis::Auth::Role::ISA = qw( Apiis::Init );
our $apiis;
my $cfg; 
my $pro;
my $roles_file;


{    # private class data and methods to leave the closure:
   my %_attr_data = (
      _role_shortcut               => 'ro',
      _short_name                  => undef,
      _long_name                   => undef,
      _description                 => undef,    
      _role_id                     => undef,
      _db_policies                 => undef,
      _os_policies                 => undef,
      _db_policy                   => undef,
      _os_policy                   => undef,
   );
}

sub new {
   my ( $invocant, %args ) = @_;
   croak __("Missing initialisation in main file ([_1]).\n",__PACKAGE__ )
     unless defined $apiis;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init(%args);

   return $self;
}
sub _init {
   my ( $self, %args ) = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++; 
   my $no_role_status=1;
   $roles_file = $apiis->APIIS_LOCAL."/etc/Roles.conf";

   if ( not exists $args{role_shortcut} ) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::Role',
				      msg_short => __("No key 'role shortcut' passed to Apiis::Auth::Role"),
				     )
		  );
      die __("No key 'role_shortcut' passed");
   } else {
     no strict 'refs';
     my $a = Apiis::CheckFile->new( file => "$roles_file" );
     if ( $a->status ) {
       foreach ( @{ $a->errors } ) {
	 $_->from( 'Apiis::Auth::Role::' . $_->from );
	 $_->print;
       }
       return;
     }else{
       $cfg = new Config::IniFiles( -file   =>  "$roles_file",  -nocase => 1 );
       $self->status(0);
     EXIT:
       foreach my $mainkey ( $cfg->Sections ) {
	 if ($mainkey eq $args{role_shortcut}){
	   $self->{"_role_shortcut"} = $args{role_shortcut};

	   foreach my $subkey ( $cfg->Parameters($mainkey) ) {
	        $self->{"_$subkey"} = $cfg->val( $mainkey, $subkey ); 
	   }
	   $no_role_status=0;
	   last EXIT;
	 }
       }
       if ($no_role_status){
	 $self->status(1);
	 $self->errors(
		       Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::Role',
				      msg_short => __("No role definition finded in [_1]", $roles_file),
				     )
		      );
	 die __("No role definition in [_1]", $roles_file);
       }
       ### method _role_id #####################
       my $newval;
       my $sql = "select nextval ('seq_roles__role_id')";
 
       
       my $sql_ref = $apiis->DataBase->sys_sql($sql);
       $apiis->check_status;
        while( my $arr_ref = $sql_ref->handle->fetch ) {
	  $newval = @{$arr_ref}[0];
        }
       #}
       $self->{"_role_id"} = $newval;

     }#else if $a->status
   }
 }
 
##### public methods ####
#########################################################################

=head2 role_shortcut
 returns the main role name  which is defined in Roles.conf  file

=cut

sub role_shortcut { $_[0]->{_role_shortcut} }
#########################################################################

=head2 short_name
 returns short role name

=cut

sub short_name { $_[0]->{_short_name} }
#########################################################################

=head2 long_name
 returns long role name

=cut

sub long_name { $_[0]->{_long_name} }
#########################################################################

=head2 description
 returns description of role 

=cut

sub description { $_[0]->{_description} }
#########################################################################

=head2 policies
 returns policy numbers; policies number are taken from the role subsectione

=cut

sub policies { $_[0]->{_policies} } 
#########################################################################

=head2 role_type
  returns role type

=cut

sub role_type { $_[0]->{_role_type} }
#########################################################################

=head2 role_id
  get next sequence value 

=cut

sub role_id{
  my$role_id = $_[1];
  if( $role_id){
    $_[0]->{"_role_id"} = $role_id;
  }
  else{
    $_[0]->{_role_id}
  }
  # return $newval;
}
#########################################################################

=head2 db_policy
 get policy for the database from db_policy section

=cut

sub db_policy{
my ($self, $policy)=@_;

my $value =$cfg->val( 'db_policies', $policy );
return $value;
}
#########################################################################

=head2 os_policy
 get policy for the operating system from os_policy section

=cut

sub os_policy{
my ($self, $policy)=@_;

my $value =$cfg->val( 'os_policies', $policy );
return $value;
}
#########################################################3
1;

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de>

=cut
