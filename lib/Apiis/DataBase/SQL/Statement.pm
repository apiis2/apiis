##############################################################################
# 
# the SQL module for creating parsed sql object.
##############################################################################

=head1 NAME

Statement

=head1 SYNOPSIS

    $statement = Apiis::DataBase::SQL::Statement->new(
	 sql     => $sqltext
   );


This is the module for creating an object for parsed normal SQL. This module is intended for parsing simple SQL statements: INSERT,UPDATE,DELETE,SELECT (without aggregate functions).

=head1 DESCRIPTION

Creates the internal structure for important elements of SQL statement and provides methods for accessing them


Public and internal methods are:

=head1 PUBLIC METHODS

=head2 actionname

- returns the sql action

=cut

=head2 tablename 

- returns the table name used in the statement - only one table is allowed per statement!

=cut

=head2 columns

 - returns list of column names

=cut

=head2 values 

- returns list of column values

=cut

=head2 value 

- returns the value of the supplied column

=cut

=head2 whereclause 

- returns the where part of the statement

=cut

=head2 status 

- returns the object status - inherited from apiis

=cut

=head2 errors 

- returns list of error object - inherited from apiis

=cut

##############################################################################

package Apiis::DataBase::SQL::Statement;
$VERSION = '$Id ';

use strict;
use Carp;
use warnings;
use Data::Dumper;
use Apiis::Init;
require SQL::Statement;

@Apiis::DataBase::SQL::Statement::ISA = qw(
  Apiis::Init
);

# for debugging:
# use Class::ISA;
# print "Apiis::DataBase::Record path is:\n ",
  # join ( ", ", Class::ISA::super_path('Apiis::DataBase::Record') ), "\n";



{    # private class data and methods to leave the closure:
   my %_attr_data = (
      _actionname       => 'ro',
      _tablename        => 'ro',
      _columns          => 'ro',
      _values           => 'ro',
      _whereclause      => 'ro',
    );

=head2 _standard_keys (internal)

encapsulates the names of the automatically created methods

=cut

   sub _standard_keys { keys %_attr_data; }    # attribut names:

   # is a certain object attribute accessible with this method:
   # $_[1]: attribut name/key, $_[2]: value

=head2 _accessible (internal)

checks if the method is read-only or read-write

=cut

   sub _accessible { $_attr_data{ $_[1] } =~ /$_[2]/; }

}

##############################################################################

=head2 new 

- creates the parsed sql object

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

- parses the SQL and fills the structure

=cut

sub _init {
   my $self = shift;
   my %args = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++; # Conway p. 243  
   if ( not exists $args{sql} ) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase::SQL::Statement',
				      msg_short => "No key 'sql' passed to Apiis::DataBase::SQL::Statement",
				     )
		  );
   } else {
     $self->{"_sqltext"}=$args{sql};
     my($parser) = SQL::Parser->new('Ansi'); # Create a parser
     my ($stmt) = eval {
       SQL::Statement->new($args{sql},$parser);
     };
     if ($@) {
       $self->status(1);
       $self->errors(
		     Apiis::Errors->new(
					type      => 'UNKNOWN',
					severity  => 'CRIT',
					from      => 'Apiis::DataBase::SQL::Statement',
					msg_short => "Cannot create parser: $@",
				       )
		    );

     }
     eval {
       my $action=$stmt->command();
       $self->{"_actionname"}=$action;
       my @tables = $stmt->tables();      # Array context
       if (@tables>1) {
	 if ($action eq "SELECT") {
	   $self->status(1);
	   $self->errors(
			 Apiis::Errors->new(
					    type      => 'DATA',
					    severity  => 'WARNING',
					    from      => 'Apiis::DataBase::SQL::Statement',
					    msg_short => "More then one table in SELECT statement - only the first will be stored",
					   )
		      );
	 }
       }
       $self->{"_tablename"}= lc $tables[0]->name;
       
       my @columns = $stmt->columns();    # Array context
       my @column_names;
       foreach (@columns) {
	 foreach my $col (@column_names) {
	   if($col eq (lc $_->name)) {
	     if (($action eq "INSERT") or ($action eq "UPDATE")) {
	       $self->status(1);
	       $self->errors(
			     Apiis::Errors->new(
						type      => 'DATA',
						severity  => 'CRIT',
						from      => 'Apiis::DataBase::SQL::Statement',
						msg_short => "Duplicated column name: $col",
					       )
			    );
	     }
	   }
	 }
	 push @column_names, lc $_->name;
       }
       $self->{"_columns"}=\@column_names;
       my @column_values;
       if (($action eq "INSERT") or ($action eq "UPDATE")) {
	 @column_values=$stmt->row_values();
       }
       $self->{"_values"}=\@column_values;
       my $where_clause;
       if (($action eq "UPDATE") or ($action eq "DELETE") or ($action eq "SELECT")) {
	 $args{sql}=~/WHERE\s*(.*)\s*$/i;
	 $where_clause=$1;
	 warn "Empty where clause!\n" unless ($where_clause);
       }
       $self->{"_whereclause"}=$where_clause;
     };
     if ($@) {
       $self->status(1);
       $self->errors(
		     Apiis::Errors->new(
					type      => 'PARSE',
					severity  => 'CRIT',
					from      => 'Apiis::DataBase::SQL::Statement',
					msg_short => "Error in parsing SQL: $@",
				       )
		    );
       
     }
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
 }
}




##############################################################################
sub value {
  my $self = shift;
  my $column=shift;
  my @columns=$self->columns;
  my @values=$self->values;
  for (my $i=0;$i<@columns;$i++) {
    return $values[$i] if ($column eq $columns[$i]);
  }
  return undef;
}



##############################################################################
1;

=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>

=cut

__END__
