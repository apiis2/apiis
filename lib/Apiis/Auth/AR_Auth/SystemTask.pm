##############################################################################
# $Id: SystemTask.pm,v 1.3 2006/01/05 16:14:43 marek Exp $
##############################################################################
package Apiis::Auth::AR_Auth::SystemTask;
$VERSION = '$Revision ';
##############################################################################

=head1 NAME

Apiis::Auth::Auth::SystemTask -- 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut

##############################################################################

use strict;
use warnings;
use Carp;
use Apiis::Init;
use Data::Dumper;


##############################################################################
### SYSTEM TASKS METHODS #####################################################
##############################################################################

=head2 _check_system_tasks 

  method return list of all actions which are allowed for the user (if you run it without any parameter).
  If you run it with the parameter "action type" then you can get the list of allowed actions for this specified action type. 
  You can use following action type: program, form, rapor,t subroutine, www, action. Curently the action types are hard-coded 
  in the AccessControl.pm  

      example: $apiis->Auth->check_system_tasks
               $apiis->Auth->check_system_tasks('action')
               $apiis->Auth->check_system_tasks('program','access_control.pl')		 		 
		  
=cut

sub _check_system_tasks{ 
  my ($self,@args) = @_;
  my @st_list;
  my $tmp_type_status=1;
  my $tmp_name_status=1;

 EXIT:{
  unless ($self->_exists_st) {
    my $msg = __("Method can not be executed.");
    my $msg_long = __("Object Auth was not initialized for the system tasks.");
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::SystemTask::_check_system_tasks',
        msg_short => $msg,
        msg_long  => $msg_long,
      )
    );
    last EXIT;
  }

  if ((not defined $args[0]) and (not defined $args[1])){
    $tmp_type_status=0;
    $tmp_name_status=0;
    while ( my ($st_type,$st_names) =  each %{$self->{'_st_ar'}}){
      foreach (@{$st_names}){
        my $tmp_value = "(".$st_type.")->".$_; 
        push @st_list, $tmp_value;
      }
    } 
  }elsif ((defined $args[0]) and (not defined $args[1])){
    $tmp_name_status=0;
    while ( my ($st_type,$st_names) =  each %{$self->{'_st_ar'}}){
      if ($st_type eq $args[0]){
        $tmp_type_status=0;
        foreach (@{$st_names}){
          #my $tmp_value = "(".$st_type.")->".$_; #del me I return following format: (www)->task
          my $tmp_value = $_; 
          push @st_list, $tmp_value;
        }
      }
    }
  }elsif ((defined $args[0]) and (defined $args[1])){
    my %tmp_hash = %{$self->{'_st_ar'}};
    while ( my ($st_type,$st_names) =  each %tmp_hash){
      if ($st_type eq $args[0]){
        $tmp_type_status=0;
        foreach (@{$st_names}){
          if ($_ eq $args[1]){ 
            $tmp_name_status=0;
            push @st_list, 1;
            last EXIT;
          }
        }
      }
    }
  }

  if ($tmp_type_status){
    my $msg_sh = __("NO ACCESS RIGHTS");
    my $msg_ln = __("User '[_1]' has not any system task defined in '[_2]' type",$self->{'_object_user'},$args[0]);
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::SystemTask::_check_system_tasks',
        msg_short => $msg_sh,
        msg_long  => $msg_ln,
      )
    );
    last EXIT;
  }
  if ($tmp_name_status){
    my $msg_sh = __("NO ACCESS RIGHTS");
    my $msg_ln = __("User '[_1]' has not access rights to system task '[_2]' defined for '[_3]' type or maybe this task is defined for the different type.",$self->{'_object_user'},$args[1],$args[0]);
    $self->status(1);
    $self->errors(
      Apiis::Errors->new(
        type      => 'AUTH',
        severity  => 'CRIT',
        from      => 'Apiis::Auth::Auth::SystemTask::_check_system_tasks',
        msg_short => $msg_sh,
        msg_long  => $msg_ln,
      )
    );
    last EXIT;
  } 
 }#EXIT
 return @st_list;
}
##############################################################################

1;

=head1 AUTHOR

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

__END__

