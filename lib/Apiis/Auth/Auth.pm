#################################################################################
# $Id: Auth.pm,v 1.28 2005/12/14 13:00:11 marek Exp $
#################################################################################
package Apiis::Auth::Auth;
=head1 NAME

Apiis::Auth::Auth.pm

=cut

=head1 DESCRIPTION

Auth.pm is method of record object and contains subroutines needed for the authentication process.

=cut

=head1 SUBROUTINES


=cut


use strict;
use Data::Dumper;
use Apiis::Init;
##############################################################################
################## MAIN AUTHENTICATION SUBROUTINE ############################
##############################################################################

=head2 _auth

  This subroutine is responsible for whole authentication process.
  1.Get access rights from the database
  2.Dependant from sql action type
    (a) if DELETE then only recreates list of all clases on which user can 
        executed delete operations.This list is returned by "get_ar" and is 
        recreated to the hash structure.
    (b) if INSERT or UPDATE then checks access rights for the columns 
        defined in this statement

=cut

sub _auth {
  my ( $self, %args ) = @_;
  our $sqlaction =$self->action;
  our $table_name =$self->name;
  my $extension;
  my $system_user=$apiis->Model->db_user;
  my $user=$apiis->User->id;

if($user ne $system_user){
 EXIT:{
    my  ($access_array, $classes_array) = get_ar($self,$sqlaction,$table_name);
    last EXIT if $self->status;

    my @access_array=@$access_array;
    my @classes_array = @$classes_array;

    if ($sqlaction eq 'delete'){
      $extension =  redo_clases(@classes_array);
    }
    elsif (($sqlaction eq 'update') or ($sqlaction eq 'insert') or ($sqlaction eq 'select')){
      $extension =  check_ar($self,$sqlaction,$table_name,$access_array, $classes_array);
      last EXIT if $self->status;
    }
    else{
      $self->status(1);
      my $msg_short="unknown definition sql action type: $sqlaction";
      $self->errors(
		  Apiis::Errors->new(
				     type      => 'AUTH',
				     severity  => 'ERR',
				     from      => 'Apiis::Auth::Auth::_auth',
				     msg_short => __($msg_short),
				    )
		   );
      last EXIT;
    }
    return $extension;
  }
 }#if
}
#############################################################################

#############################################################################
################# GETING ACCESS RIGHTS ######################################
#############################################################################
=head2 get_ar

Subroutine gets access rights from the database (user access view) and returns
hash ('access hash') and array. 'Access hash' contains allowed column names and ascribed to them clases.
Array contains only list of unique clases in which user can executed this sql 
statement. Access rights are taken only for table and action on which user curentlly is executing his SQL statement. 

=cut

sub get_ar{
  my ($self,$sqlaction,$table_name) = @_;
  my @ar_array;
  my @cl_array;
  my $status_noaccess=1;
  my $user = $apiis->User->id;

EXIT: {
  # creates where clause:
  my $where_clause ='tablename=\''.$table_name.'\' AND action=\''.$sqlaction.'\'';
  #checks that parameters for the where clause that  are not NULL
  if (($self->name eq '') or ($sqlaction eq '' )){
    my $msg_long="No parameters for the WHERE clause to get access rights";
    $self->status(1);                                                          
    $self->errors(
	Apiis::Errors->new(
	  type      => 'AUTH',
	  severity  => 'ERR',
	  from      => 'Apiis::Auth::Auth::get_ar',
	  msg_short => __($msg_long),
	)
    );
    last EXIT;
  }else{
    ### creates and execute sql:
    my $query_table ="$user.v_ar_$user";
    my $retrieve_cols = 'columns,class';
    my $sqltext = sprintf "SELECT %s FROM %s where %s",$retrieve_cols,$query_table, $where_clause;
    my $fetched = $apiis->DataBase->sys_sql($sqltext);
    if ( $fetched->status ) {
      my $msg_long ="No access view for user $user";
      $self->errors( $fetched->errors );
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
	      type      => 'AUTH',
	      severity  => 'ERR',
	      from      => 'Apiis::Auth::Auth::get_ar',
	      msg_short => __('NO ACCESS VIEW'),
	      msg_long=>__($msg_long),
	)
      );
      #${$self->errors}[-1]->print;
      $apiis->log( 'debug', 'access rights (get_ar) -  record select failed' );
      last EXIT;
    }
    while ( my ($columns,$class)  = $fetched->handle->fetchrow_array() ) {
      #changes status -  some records  are existing
      $status_noaccess=0;
      #creates array with allowed columns and classes
      my %tmp_hash;
      %tmp_hash = 
	( COLUMNS => $columns,
	  CLASS   => $class,
	);
      push @ar_array, \%tmp_hash;
      #creates separate array with unique clases
      push @cl_array,$class unless (grep /^$class$/, @cl_array);
    }#while end
    #this error is returned when the user have no access rights for this action and this table
    if ($status_noaccess) {
      my $msg_long="No access rights for the action  $sqlaction on the table  $table_name";
      $self->status(1);
      $self->errors(
        Apiis::Errors->new(
	  type      => 'AUTH',
	  severity  => 'ERR',
	  from      => 'Apiis::Auth::Auth::get_ar',
	  msg_short => __('NO ACCESS RIGHTS'),
	  msg_long => __($msg_long),
        )
      );
      last EXIT;
    }
   }# else end
   return \@ar_array, \@cl_array;
  }#end label EXIT
 }
##############################################################################


##############################################################################
################# CHECKING ACCESS RIGTS FOR THE COLUMNS #########################
##############################################################################

=head2 check_ar

Subroutine checks access rights for the columns.
Algorithm copmares column names from the sql statement to column names defined 
in the access hash and returns hash with clases in which user can executed this 
sql statement. Class is added to this hash only if user have defined access rights 
for all columns (from sql statement) in this class.

Returned hash for expand the where clause:

     @ext =(
		  (
		   COLUMN   => "class",
		   OPERATOR => "=",
		   VALUE    => PL,
		  ),

		  (
		   COLUMN   => "class",
		   OPERATOR => "=",
		   VALUE    => DE,
		  )
                 )

=cut

sub check_ar{
  my ($self,$sqlaction,$table_name,$access_array,$classes_array)=@_;
  my @sqlcolumns_array;
  my $actual_status;
  my $class_status=1;
  my @temp_array;
  my @ext; 
  my $error_column;
  my $error_class;
  my $where_string;
  my $count=1;
  my @system_columns = qw / guid oid last_change_user last_change_dt version creation_dt creation_user opening_dt/;

  ###Creates array with columns form sql statement ####
  foreach my $sqlcolumn ($self->columns){
    if($self->action eq 'update'){
      if (( $self->column($sqlcolumn)->updated()) and !(grep /^$sqlcolumn$/, @system_columns)){
	push @sqlcolumns_array, $sqlcolumn;
      }
    }
    else{
      if ( ($self->column($sqlcolumn)->extdata or defined $self->column($sqlcolumn)->intdata) and ($sqlcolumn ne 'oid')  ){
	push @sqlcolumns_array, $sqlcolumn;
      }
    }
  }
EXIT_0:{
  #chceck status of the record - print error if there is no any column to update 
  #(in case when you put the same values which are currently in the database)
  if (not @sqlcolumns_array){
    my $msg_long="Values introduced through the update statement are exactly the same like the values existing in the database";
    $self->status(1);
    $self->errors(
	   Apiis::Errors->new(
	      type      => 'AUTH',
	      severity  => 'ERR',
	      from      => 'Apiis::Auth::Auth::check_ar',
	      msg_short => __('UPDATE NOT EXECUTED'),
	      msg_long => __($msg_long),
	   )
    );
    $where_string=0;
    last EXIT_0;  
  }
  #this first "for" takes each unique class name
  foreach my $mainclass (@{$classes_array}){
    $actual_status=1;
  EXIT_1:{
      #this second "for" takes each column name from sql statement
      foreach my $sqlcolumn (@sqlcolumns_array){
	$actual_status=1;
      EXIT_2:{
	  #this third "for" takes column names defined in the access rights table, 
	  foreach my $access(@{$access_array}){
	    my $allowed_column=$access->{COLUMNS};
	    my $allowed_class =$access->{CLASS};
	    if ( ($allowed_column=~ m/\|$sqlcolumn\|/) and ($allowed_class eq $mainclass)){ 
	      $actual_status=0;
	      last EXIT_2;
	    }
	  }
	}#EXIT_2
	if ($actual_status){
	  $error_column=$sqlcolumn;
	  $error_class=$mainclass;
	  last EXIT_1;
	}
       }
    }#EXIT_1
    if (!$actual_status){
      $class_status=0;
      if ($count){
	$where_string="and (owner='$mainclass'";
	$count=0;
      }else{
	$where_string= join(' or owner=\'',$where_string,$mainclass);
	$where_string="$where_string'";
      }
    }
  }
  #This error is returned when user have no access rights for the columns tight in SQL statement (defined in one class) 
  if($class_status){
    my $msg_long="No access rights for the column '$error_column' from the table '$table_name'";
    $self->status(1);
    $self->errors(
	Apiis::Errors->new(
	  type      => 'AUTH',
	  severity  => 'ERR',
	  from      => 'Apiis::Auth::check_ar',
	  msg_short => __('NO ACCESS RIGHTS' ),
	  msg_long=>__($msg_long ),
	  ext_fields => $self->column($error_column)->ext_fields || undef,
	)
    );
    $where_string=0;
  }elsif (!$class_status){ 
    $where_string="$where_string)";
    return $where_string;
  }
 }#EXIT_0
  return $where_string;
}
##############################################################################

##############################################################################


=head2 redo_clases


=cut

sub redo_clases{
my @classes=@_;
my $ext;
my $count=1;
foreach my $class (@classes){
  if ($count){
    $ext="and (owner='$class'";
    $count=0;
  }else{
    $ext= join(' or owner=\'',$ext,$class);
    $ext="$ext'";
  }
     #   my %tmp_hash;
     #	   %tmp_hash =
    #	     ( COLUMN   => "class",
    #	       OPERATOR => "=",
    #	       VALUE    => $class,
   #	     );
   #	push @ext, \%tmp_hash;
}
$ext="$ext)";
return $ext;
}
##############################################################################
1;

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de>

=cut

__END__
# vim: expandtab:tw=100


