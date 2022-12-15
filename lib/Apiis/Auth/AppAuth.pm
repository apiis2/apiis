##############################################################################
# $Id: AppAuth.pm,v 1.9 2005/04/11 07:44:39 marek Exp $
##############################################################################
package Apiis::Auth::AppAuth;
$VERSION = '$Revision ';
##############################################################################

=head1 NAME

Apiis::Auth::AppAuth -- object for provading data about user access rights for the applications

=head1 SYNOPSIS

This object is used to check user access right for the applications which ara curentlly defined in the database.

=head1 DESCRIPTION

Object is created by the one of Apiis object method ($apiis->join_auth('user_login')). This creates Auth object
for the user which is curently log-in and join it to the $apiis structure.

=head1 METHODS

=cut

##############################################################################

use strict;
use warnings;
use Carp;
use Apiis::Init;
use Apiis::DataBase::Record;
use Data::Dumper;

@Apiis::Auth::AppAuth::ISA = qw / Apiis::Init /;


{    # private class data and methods to leave the closure:
  my %_attr_data = (
         __app_user            => undef,    # scalar 
	 __user_id             => undef,    # scalar
	 __role_id             => undef,    # array
	 __role_numbers        => undef,    # scalar
	 __policy_id           => undef,    # array
	 __applications	       => undef,    # array
   );
   sub _standard_keys { keys %_attr_data; }
   #sub _get_user_id {}

}    # end private class data:
##############################################################################

=head2 new (public)
 
  returns an object reference for a new Auth object.

=cut

sub new {
   my ( $invocant, %args ) = @_;
   my ( $local_status, @errors );
   croak __("Missing initialisation in main file ([_1]).", __PACKAGE__ ) . "\n"
     unless defined $apiis;
   my ( $package, $file, $line ) = caller;

   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   
   if ( not exists $args{app_user} ) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'AUTH',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::AppAuth',
				      msg_short => __("No key 'user' passed to Apiis::Auth::AppAuth"),
				     )
		  );  	  
     die __("No key 'user' passed");
     
   }else{
     $self->{'__app_user'}=$args{app_user}; 
     $self->check_status;
     $self->__get_user_id;
     $self->__get_user_roles;
     $self->__get_policy_ids;
     $self->__get_all_policies;
   
 
     if ( $self->status ) {
       $apiis->status( $self->status );
       $apiis->errors( $self->errors );
       return undef;
     }else{      
       return $self ;
     }
   }#end of not exists $args{app_user}
}

##############################################################################


=head2 _get_user_roles (internal)
 
  retrieves all role_id from table 'roles' for current user

=cut

sub __get_user_roles {
   my $self = shift;
   my $role_numbers=0;
   
   my $user_roles = Apiis::DataBase::Record->new(
      tablename => 'user_roles',
   );
   $user_roles->check_status;
   $user_roles->column('user_id')->extdata($self->{'__user_id'});
   my @query_records = $user_roles->fetch(
      expect_rows    => 'many',
      expect_columns => [qw( role_id )],
   );
   unless (@query_records){
     $user_roles->status(1);
     $user_roles->errors(
		   Apiis::Errors->new(
				      type      => 'AUTH',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::AppAuth::get_user_roles',
				      msg_short => __("No any role defined for the user"),
				     )
		  );  	  
     die __("No any role defined for the user");
   }
   foreach my $record (@query_records) {
     $record->decode_record;      
     if ( $record->column('role_id')->extdata ){
          my $value = join ( ' ', $record->column('role_id')->extdata );
          $self->{'__role_id'}{ $role_numbers } = $value;
     }
     $role_numbers++;
   }
   $self->{'__role_numbers'} = $role_numbers;
}
##############################################################################

=head2 _get_user_id (internal)
   
  retrieves current user id

=cut

 sub __get_user_id {
   my $self = shift;
   my $user = Apiis::DataBase::Record->new(
      tablename => 'users',
   );
   $user->column('login')->extdata($self->{'__app_user'});
   my @query_records = $user->fetch(
      expect_rows    => 'one',
      expect_columns => [qw( user_id )],
   );
   unless (@query_records){
     $user->status(1);
     $user->errors(
		   Apiis::Errors->new(
				      type      => 'AUTH',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::AppAuth::get_user_id',
				      msg_short => __("No such user in the database user: \"[_1]\"",$self->{'__app_user'}),
				     )
		  );  	  
     die __("No such user in the database: \"[_1]\"",$self->{'__app_user'});
   }
   
   foreach my $record (@query_records) {
      $record->decode_record;
      $self->{'__user_id'} = join ( ' ',$record->column('user_id')->extdata)  if $record->column('user_id')->extdata;
   }
}
##############################################################################

=head2 _get_policy_ids (internal)

  retrieves all policies for current role

=cut

sub __get_policy_ids {
   my $self = shift;
   my @policies;
   
   my $policy_id = Apiis::DataBase::Record->new(
      tablename => 'role_policies_app',
   );
   $policy_id->check_status;
   for (my $i=0; $i<$self->{'__role_numbers'}; $i++){
  
     $policy_id->column('role_id')->extdata($self->{'__role_id'}{ $i });
     my @query_records = $policy_id->fetch(
       expect_rows    => 'many',
       expect_columns => [qw( app_policy_id )],
     );
     
     foreach my $record (@query_records) {
       $record->decode_record;
       
       if ( $record->column('app_policy_id')->extdata ){
          my $value = join ( ' ', $record->column('app_policy_id')->extdata );
          push @policies, $value unless (grep /^$value$/, @policies);
       }
     }
   } 
   unless (@policies){
     $policy_id->status(1);
     $policy_id->errors(
		   Apiis::Errors->new(
				      type      => 'AUTH',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::AppAuth::get_policy_ids',
				      msg_short => __("No any system role granted to the user: \"[_1]\"",$self->{'__app_user'}),
				     )
		  );  	  
     die __("No any system role granted to the user: \"[_1]\"",$self->{'__app_user'});
   }
   $self->{'__policy_id'} = \@policies;     
}
##############################################################################
=head2 _get_policy_desc (internal) 

  retrieves list of applications to which user has access rights 

=cut

sub __get_all_policies {
   my $self = shift;
   my (@policies,@all_app_name,@app_class);
   my $counter=0;
  
   my $policy_desc = Apiis::DataBase::Record->new(
      tablename => 'policies_app',
   );

   $policy_desc->check_status;
   foreach my $pid (@{$self->{'__policy_id'}}){
     
     $policy_desc->column('app_policy_id')->extdata($pid);
     my @query_records = $policy_desc->fetch(
       expect_rows    => 'one',
       expect_columns => [qw( app_name app_class )],
     );
     foreach my $record (@query_records) {
       $record->decode_record;
       my @value;
       my $k=0;
       for my $col (qw/ app_name app_class /) {
       	  if ( $record->column($col)->extdata ){
            $value[$k] = join ( ' ', $record->column($col)->extdata ); 	    
          }
	  $k++;
       }
       $self->{'__app_name'}{$value[1]}{$pid}= $value[0]; 
       $self->{'__app_class'}{$pid} = $value[1];
       push @all_app_name,$value[0];    
     }
   $counter++;
   } 
   $self->{'__app_numbers'} = $counter ;
   $self->{'__applications'} = \@all_app_name ;   
}
##############################################################################

=head2 print_os_actions (public)
 
  prints all applications or actions with their classes which user can execut
  
      example: $apiis->Auth->print_os_actions; 

=cut

sub print_os_actions{
  my $self = shift;
  
  foreach my $policyid (@{$self->{'__policy_id'}}){
    foreach my $app_type ($apiis->Auth->types_of_actions){
      if ($self->{'__app_name'}{$app_type}{$policyid}){
         print __("\n<<ACTION>> [_1] <<TYPE>> [_2] <<>>\n",$self->{'__app_name'}{$app_type}{$policyid},$app_type);
      }    
    }
  }

}
##############################################################################

##############################################################################

=head2 os_actions 

  method return list of all actions which are allowed for the user (if you run it without any parameter).
  If you run it with the parameter "action type" then you can get the list of allowed actions for this specified action type. 
  You can use following action type: program, form, rapor,t subroutine, www, action. Curently the action types are hard-coded 
  in the AccessControl.pm  

      example: $apiis->Auth->os_actions
               $apiis->Auth->os_actions('program')		 		 
		  
=cut

sub os_actions{ 
 my ($self,$type) = @_;
 my @allowed_list;
 
 if ($type){
    foreach my $policyid (@{$self->{'__policy_id'}}){
       if ( $self->{'__app_name'}{$type}{$policyid} ){
          my $value = $self->{'__app_name'}{$type}{$policyid};
          push @allowed_list, $value; 
       }
    }
    return @allowed_list;   
 }else{
    return @{$self->{'__applications'} }
 }   
}
##############################################################################

##############################################################################

=head2 types_of_actions (public)

  returns all type of actions which are curently allowed for the user. 

      example: $apiis->Auth->types_of_actions

=cut

sub types_of_actions{ 
 my $self = shift;
 my @list_of_types;
 
 foreach my $policyid (@{$self->{'__policy_id'}}){
    if ( $self->{'__app_class'}{$policyid} ){
       my $value = $self->{'__app_class'}{$policyid};
       push @list_of_types, $value unless (grep /^$value$/,@list_of_types) ; 
    }
 }
 return @list_of_types;   
    
}
##############################################################################

##############################################################################

=head2 check_os_action (public)

  check that user can executs action (action name is defined as a parameter). 

      example: $apiis->Auth->check_os_action('runall_ar.pl','program'); 

=cut

sub check_os_action{ 
 my ($self,$name,$type) = @_;
 my $status=1;
 
 if ($type && $name){

    EXIT:{     
      foreach my $policyid (@{$self->{'__policy_id'}}){
        if ( $self->{'__app_name'}{$type}{$policyid} ){
           my $value = $self->{'__app_name'}{$type}{$policyid};
	   if ($value eq $name){
	      $status=0;
	      last EXIT;      
	   }
        }
      }
    }# EXIT 
 }
 if ($status){
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'AUTH',
				      severity  => 'CRIT',
				      from      => 'Apiis::Auth::AppAuth::check_os_action',
				      msg_short => __("NO ACCESS RIGHTS"),
				      msg_long  => __("No access rights to execut action '[_1]' or this action is not defined as a '[_2]'",$name,$type),
				     )
		  );
    die __("No access rights to execut action '[_1]' or this action is not defined as a '[_2]'",$name,$type);	    	  
 }
 
}
##############################################################################

1;

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de>

=cut

__END__

