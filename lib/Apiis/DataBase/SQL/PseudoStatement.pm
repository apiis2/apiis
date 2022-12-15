##############################################################################
# 
# the SQL module for creating parsed pseudo sql object.
##############################################################################

=head1 NAME

PseudoStatement

=head1 SYNOPSIS

    $statement = Apiis::DataBase::SQL::PseudoStatement->new(
	 pseudosql     => $sqltext,
	 data_hash     => \%data_hash
   );


This is the module for creating an object for parsed PseudoSQL. 

=head1 DESCRIPTION

Creates the internal structure for the important elements of an PseudoSQL statement and provides methods for accessing them.
For parsing the PseudoSQL, the original parser written by Helmut Lichtenberg <heli@tzv.fal.de> was used.



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

=head2 extfields

- returns list of external fields that are targeted for errors

=cut

=head2 value 

- returns the value of the supplied column

=cut

=head2 column_extfields

- returns list of external fields for a certain column

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

package Apiis::DataBase::SQL::PseudoStatement;
$VERSION = '$Id ';

use strict;
use Carp;
use warnings;
use Data::Dumper;
use Apiis::Init;
require Apiis::DataBase::SQL::Statement;
use Text::ParseWords;
use Apiis::DataBase::Record;

@Apiis::DataBase::SQL::PseudoStatement::ISA = qw(
  Apiis::Init
);

# for debugging:
# use Class::ISA;
# print "Apiis::DataBase::Record path is:\n ",
  # join ( ", ", Class::ISA::super_path('Apiis::DataBase::Record') ), "\n";

our($apiis);

{    # private class data and methods to leave the closure:
   my %_attr_data = (
      _actionname       => 'ro',
      _tablename        => 'ro',
      _columns          => 'ro',
      _values           => 'ro',
      _extfields        => 'ro',
      _whereclause      => 'ro',
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

- calls _ParsePseudoSQL for parsing of the SQL and fills the structure

=cut

sub _init {
   my $self = shift;
   my %args = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++; # Conway p. 243  
   if ( not exists $args{pseudosql} ) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase::SQL::PseudoStatement',
				      msg_short => "No key 'pseudosql' passed",
				     )
		  );
   } elsif ( not exists $args{data_hash} ) {
     $self->status(1);
     $self->errors(
		   Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase::SQL::PseudoStatement',
				      msg_short => "No key 'data_hash' passed",
				     )
		  );
   } else {
     $self->{"_sqltext"}=$args{pseudosql};
     my $string=$args{pseudosql};
     my ($parse_status, $parse_err_ref, $dbactions_ref) = _ParsePseudoSQL( $args{pseudosql}, $args{data_hash} );
     if ($parse_status) {
       $self->status(1);
       foreach (@$parse_err_ref) {
	 $self->errors($_);
       }
     }
     $self->{"_actionname"}=$$dbactions_ref{TYPE};
     $self->{"_tablename"}=$$dbactions_ref{TABLE};
     $self->{"_whereclause"}=$$dbactions_ref{WHERE};
     my(@db_columns,@values,@ext_fields);
     foreach (@{$$dbactions_ref{DATA}}) {
       push @db_columns, $_->{DB_COLUMN};
       push @values, $_->{VALUE};
       push @ext_fields, $_->{EXT_FIELDS};
     }
     $self->{"_columns"}=\@db_columns;
     $self->{"_values"}=\@values;
     $self->{"_extfields"}=\@ext_fields;
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
sub column_extfields {
  my $self = shift;
  my $column=shift;
  my @columns=$self->columns;
  my @ext_fields=$self->extfields;
  for (my $i=0;$i<@columns;$i++) {
    return $ext_fields[$i] if ($column eq $columns[$i]);
  }
  return undef;
}

##############################################################################
=head2 _ParsePseudoSQL (internal)

- Does the actual parsing of the PseudoSQL

=cut

sub _ParsePseudoSQL {
   my $pseudo_sql =  shift() ;
   my $data_ref   = shift();

   my ( $method, $table, @db_columns, @ext_fields, @values, @wheres, $string );
   my ($debug, $profiling, $whole_where, $max_prof_string, $whole_str, $db_col,$thisaction);
   my ( @dbactions, @error_objects );
   $debug=1;
      
   MAIN_LOOP:
   {
      my $i = 0;
      my %thisaction;
      # reset some vars:
      $method = $table = $string = '';
      @db_columns = @ext_fields = @values = ();
   
      my $string = join(' ', split /\s+/, $pseudo_sql);
      my $whole_string = $string; # for testing later (include something)

      if ( $debug > 6 ){
         print "\n", '#' x 70, "\n",
            "Debug level $debug in ParsePseudoSQL:\n",
            "Original: $string\n";
      }
   
      # get the method (insert, update, delete):
      $string =~ /^\s*(insert|update|delete|select)\s+/i && do {
         $method = uc $1; $string = $';
         print "\n\tfound method '$method'\n" if $debug >6;
      };
     
      ######## INSERT ###########
      if ( $method eq 'INSERT' ){
         my @before_insert = Now() if $profiling;
         INS_LOOP:
         while ( $string ){  # unless $string is empty
                             # I always try to match the first expression in string. If this succeeds
                             # somewhere, $' (which is the rest of $string *after* the found expression)
                             # will be reassigned to $string until everything is found (hopefully). It
                             # acts like a case statement.
            $_ = $string;
            print "\nremaining string: '$_'\n" if $debug >6;
      
      
            # get the tablename (only insert):
            /^\s*into\s+(\w+)/i
               && do {  $table = lc $1;
                        print "\n\tfound tablename: '$table'\n" if $debug >6;
                        $string = $';
                        next INS_LOOP;
                  };
      
            # get the db_columns:
            /^\s*\(\s*([^)]*)\s*\)\s*(values)/i
               && do {  @db_columns = parse_line('\s*,\s*', 0, $1);
                        $string = $2 . $'; # save $' before next s/// !!!:
                        $db_columns[$#db_columns] =~ s/\s*$//; # remove trailing blanks from last element
                        print "\n\tfound db_columns: '", join(' - ',@db_columns),"'\n" if $debug >6;
                        next INS_LOOP;
                  };
      
            # get the ext_fields/values (special case 'concat'):
            # example: concat( "society|sex", $dam_society ."|2", $piglet["start_notch_no, born_alive_no"])
             /^\s*values\s*\(\s*concat\s*\(\s*([^)]*)\s*\)\s*,?/i && do {
# rffr       /^\s*values\s*\(\s*concat\s*\(\s*(.*?*)\s*\)\s*,?/i && do {
# print "++++++>$1=>$2<+++++++++++\n";
#	       
# 	    $string = $_;
# 	       @str = pull_quotes($string, '()');
# 	      $1 = $str[0];
               my @tmp = parse_line('\s*,\s*', 0, $1);
               print "\n\tfound concat: '", join('\', \'',@tmp),"'\n" if $debug >6;
      
               @tmp = map { s/^\s*//; s/\s*$//; $_ } @tmp if  @tmp; # remove whitespace

               # ext_fields:
               my @tmp2;
               print "\t\t(First loop for finding variables/ext_fields.)\n" if $debug >6;
               foreach my $thisfield ( @tmp ){
                  $_ = $thisfield;

                  # find variables ( $ with \w+ in word boundaries \b ) in $1 with following
                  # square brackets. Contents of [] is in $2 and will be split by comma,
                  # it has to be surrounded by double quotes to satisfy parse_line.
                  # example: $piglet["start_notch_no, born_alive_no"]
                  /\$(\b\w+\b)(?=\s*\[)\s*\[([^\]]+)\]\s*,?/i &&
                     do {
                        push @tmp2, split /\s*,\s*/, $2;
                        print "\t\tVariables with brackets []:\n",
                              "\t\t\tfound \$var[]: ", join('-',@tmp2),"\n" if $debug >6;
                     };
      
                  # find variables ( $ with \w+ in word boundaries \b ) in $1 without
                  # following square brackets. These are simple vars.
                  # /\$(\b\w+\b)(?!\s*\[)\s*,?/i && # doesn't catch multiple with . concatenated vars
                  my $not_ready = 1;
                  while ( $not_ready ) {
                     /\$(\b\w+\b)(?![^\[]*\[)\s*,?/i && do {
                           print "\t\tVariables without brackets []:\n" if $debug >6;
                           print "\t\t\t\$_ at start of loop: '$_'\n" if $debug >6;
                           push @tmp2, $1;
                           print "\t\t\tfound: '", $tmp2[$#tmp2], "'\n" if $debug >6;
                           if ( grep /\$/, $' ){
                              print "\t\t\t\tremaining in loop: '", $', "'\n" if $debug >6;
                              $_ = $';
                              next;
                           } else {
                              $not_ready = 0;
                           }
                     };
                     $not_ready = 0;
                  }
               }
               @tmp2 = map { s/^\s*//; s/\s*$//; $_ } @tmp2 if  @tmp2;
               push @ext_fields, \@tmp2; # only push the ref of @tmp2 to keep the order with db_columns
               print "\n\t\text_fields: '", join('-',@tmp2),"'\n\n" if $debug >6;
      
               # values:
               print "\t\t(Second loop for finding values.)\n" if $debug >6;
               foreach my $thispart ( @tmp ){
                  print "\t\tvalue of part '$thispart' is " if $debug >6;
                  # substitute the variables and delete . for concatenation:
                  if ( $thispart =~ /\$(\b\w+\b)(?=\s*\[)\s*\[([^\]]+)\]/i ){
                     # like $piglet["start_notch_no, born_alive_no"]
                     # contents of [...] (including the brackets) has to be ignored:
                     if ( exists $data_ref->{$1} ){
                        $thispart = $data_ref->{$1};
                     } else {
                        $thispart = ">>>Error in LoadObject: No key/value for $1 in passed hash!<<<";
                     }
                  } else {
                     # anything else, including concatenation with . :
                     # example: '$dam_hb_nr . | . $notch_nr'
                     # split for concatenation . (if any):
                     my @part_parts = split /\s*\.\s*/, $thispart;
                     # print STDERR join('-',@part_parts),"\n";
                     foreach my $this_p_p ( @part_parts ){
                        ( $this_p_p =~ /\s*\$(\b\w+\b)\s*/ ) && do {
                           if ( exists $data_ref->{$1} ){
                              $this_p_p = $data_ref->{$1};
                           } else {
                              $this_p_p = ">>>Error in LoadObject: No key/value for $1 in passed hash!<<<";
                           }
                        };
                     }
                     $thispart = join('',@part_parts);
                  }
                  print "'$thispart'\n" if $debug >6;
               }

               push @values, join( $apiis->reserved_strings ->{v_concat}, @tmp);
      
               $' ? ($string = 'values (' . $' ) : ($string = '');
               next INS_LOOP;
            }; # end special case concat
      
            # get the ext_fields/values (special case: scalar variable with
            # trailing [...] expression to indicate ext_fields):
            # $1 is the variable without $
            # $2 is the contents of the [...]
            # the trailing \s*[,|\)] expression is needed to empty $' if
            # this is the last expression.
            # vorher:
            # /^\s*values\s*\(\s*\$(\b\w+\b)(?=\s*\[)\s*\[([^\]]*)\]\s*[,|\)]/i
            /                   # extended RE syntax, start:
               ^\s*values\s*    # match the word values in front of the string, optionally
                                # surrounded by whitespace
               \(\s*            # opening brace with opt. whitespace following
               \$(\b\w+\b)      # a dollar char followed by a word, first group -> $1 (without the $)
               (?=\s*\[)        # followed by opt. spaces and an opening bracket [
               \s*\[            # match these opt. spaces and the [
               ([^\]]*)         # next group ($2): everything from the [ which is not a ]
               \]\s*            # closing ] and optional whitespace
               [,|\)]           # followed by a comma or a closing )
            /ix && do {
               print "\n\t\$var with []: '$1' " if $debug >6;
               if ( exists $data_ref->{$1} ){
                  push @values, $data_ref->{$1};
               } else {
                  push @values, ">>>Error in LoadObject: No key/value for $1 in passed hash!<<<";
               }
               my $remaining_string = $';
      
               # extract ext_fields from $2:
               # my @tmp_array = parse_line('\s*,\s*', 0, $2);
               my $tmp_string = $2;
               $tmp_string =~ s/^["']//;
               $tmp_string =~ s/["']$//;
               my @tmp_array = split /\s*,\s*/, $tmp_string;
               scalar @tmp_array ?  push @ext_fields, \@tmp_array : push @ext_fields, [];
               # note: the 'if scalar @tmp_array' condition makes it possible to add
               #       variables without assigning them to ext_fields.
               #       Example: $today or $now are internal variables without external
               #                representation in the data stream. So you have to write
               #                $today[] or $now[] in the pseudo SQL statement. In this case
               #                the @ext_fields are set to [].
      
               print "value: '$values[$#values]' " if $debug >6;
               print "ext_fields: '", join('-',@tmp_array), "'\n" if $debug >6;
               $remaining_string ? ($string = 'values (' . $remaining_string) : ($string = '');
               next INS_LOOP;
            };
      
            # get the ext_fields/values (common scalar variables without trailing [...]):
            /^\s*values\s*\(\s*\$(\w+)(?!\s*\[)\s*[,|\)]/i && do {
               print "\n\t\$var without []: '$1' " if $debug >6;
               push @ext_fields, [ $1 ];
               if ( exists $data_ref->{$1} ){
                  push @values, $data_ref->{$1};
               } else {
                  push @values, ">>>Error in LoadObject: No key/value for $1 in passed hash!<<<";
               }
               print "value: '$values[$#values]' " if $debug >6;
               print "ext_fields: '", join('-',@{$ext_fields[$#ext_fields]}), "'\n" if $debug >6;

               $' ? ($string = 'values (' . $') : ($string = '');
               next INS_LOOP;
            };
      
            # get fixed strings (delimited by "..." or \'...\'):
            /^\s*values\s*\(\s*[\\'|"]\s*(\w+)\s*[\\'|"]\s*[,|\)]/i && do {
               push @values, $1;
               print "\n\tfixed string\n\t\tfound: '$1'\n" if $debug >6;
               push @ext_fields, []; # to keep the order
               $' ? ($string = 'values (' . $') : ($string = '');
               next INS_LOOP;
            };
      
            if ( $i > 100 ){
               print "\ntoo much trials, string remains: $string\n" if $debug >6;
               my $err = Apiis::Errors->new( type        => 'PARSE',
					     severity    => 'CRIT',
					     action      => $method,
					     from        => 'ParsePseudoSQL',
					     msg_short   => __("Cannot parse PseudoSQL"),
					     msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
					   );
               push @error_objects, $err;
               last INS_LOOP;
            }
            $i++;
         }
         # successful parsing if we reach here (puuh).
         my @tmp_data;

         BUILDHASH:
         for ($i = 0; $i <= $#db_columns; $i++){

            unless ( defined $db_columns[$i] ){
               my $err = Apiis::Errors->new( type        => 'PARSE',
                                      severity    => 'CRIT',
                                      action      => $method,
                                      from        => 'ParsePseudoSQL',
                                      msg_long    => "Undefined database column in $method/$table."
                                                     . " (Maybe a comma too much.)",
                                    );
               push @error_objects, $err;
               next BUILDHASH;
            }
            my %tmp_hash;
            $tmp_hash{DB_COLUMN} = $db_columns[$i] || '';
            $tmp_hash{VALUE}     = $values[$i];
            $tmp_hash{EXT_FIELDS} = $ext_fields[$i] || [];
            push @tmp_data, \%tmp_hash;
         }
         %thisaction = (
            TYPE => $method,
            TABLE => $table,
            DATA => \@tmp_data,
         );
         if ($profiling) {
            print "elapsed in Insert: ",
              ' ' x
              ( $max_prof_string - length("elapsed in Insert: ") ),
              elapsed( \@before_insert ), "\n";
         }
      } # end Insert

      ######## UPDATE ###########
      elsif ( $method eq 'UPDATE' ) {
	my @before_update = Now() if $profiling;
	my $operator1;
      UPD_LOOP:
	while ( $string ){  # unless $string is empty
	  $_ = $string;
	  print "\nremaining string: '$_'\n" if $debug >6;
	  
	  # get the tablename:
	  /^\s*(\b\w+\b)\s+SET/i
	    && do {  $table = lc $1;
		     $string = $';
		     print "\n\tfound tablename: '$table'\n" if $debug >6;
		     next UPD_LOOP;
		   };

	  # get the 'db_column = value' sets:
	  /^\s*(.*)\s+where/i
	    && do {
	      my $all_sets = $1;
	      my @sets;
	      # New part for allowing concatenation in the SET part of the UPDATE statement 
	      $whole_where = $';
	      
	      my $str = $1;
	      while ( $str =~ /concat\s*\(([^)]*)\)/i ) {
	      # e.g.: SET db_animal = concat( "society|sex", $dam_society."|2", $dam_hb_nr."|".$notch_nr )
	      my $before = $`;
	      my $after  = $';
	      my @parts  = parse_line( '\s*,\s*', 0, $1 );
	      print "\n\tfound concat: '", join('\', \'',@parts),"'\n" if $debug>6;
	      if (@parts) {
		foreach my $thispart (@parts) {
		  print "\t\tworking on part $thispart..." if $debug > 6;
		  $thispart =~ s/^\s*//;    # remove leading blanks
		  $thispart =~ s/\s*$//;    # remove trailing blanks
		  my @part_parts = split /\s*\.\s*/, $thispart;
		  foreach my $this_p_p (@part_parts) {
                    ( $this_p_p =~ /\s*\$(\b\w+\b)(?=\s*\[)\s*\[([^\]]+)\]/i ) && do {
		      print ">>>$2 is ignored <<<<<\n" if $debug>6;
		      if ( exists $data_ref->{$1} ) {
			$this_p_p = $data_ref->{$1};
		      } else {
			    my $err = Apiis::Errors->new( type        => 'CODE',
							  severity    => 'CRIT',
							  action      => $method,
							  from        => 'ParsePseudoSQL',
							  msg_long    => "No key/value for $1 in passed hash!",
							);
			    push @error_objects, $err;
			    last UPD_LOOP;
		      }
		    };
                    ( $this_p_p =~ /\s*\$(\b\w+\b)\s*/ ) && do {
		      if ( exists $data_ref->{$1} ) {
			$this_p_p = $data_ref->{$1};
		      } else {
			    my $err = Apiis::Errors->new( type        => 'CODE',
							  severity    => 'CRIT',
							  action      => $method,
							  from        => 'ParsePseudoSQL',
							  msg_long    => "No key/value for $1 in passed hash!",
							);
			    push @error_objects, $err;
			    last UPD_LOOP;
		      }
		    };
		  }
		  $thispart = join ( '', @part_parts );
		  print " => $thispart\n" if $debug > 6;
		}

		$str =
		  $before . "'"
		    . join ( "${$apiis->reserved_strings}{v_concat}", @parts ) . "'"
		      . $after;
		print "\n\tfound: $str\n" if $debug > 6;
	      }
	    } #end while concat
	  $all_sets=$str;
	  #           print "_____________$'_______$string______";
	  $_ = $whole_str;

	  ## end of the new Part
	    
	  push @sets,parse_line('\s*,\s*', 0, $all_sets);
	  foreach my $thisset ( @sets ){
	    $thisset =~ s/${ $apiis->reserved_strings }{v_concat}/\|\*\|/g; #change the separator to '|*|' needed for the splitting
	  my ($db_col, $val) = split /\s*=\s*/, $thisset
	    if defined $thisset; # $thisset could be undefined in case of syntax
	  # errors in pseudo sql (e.g. a comma at the end)

	  if ( defined $db_col and defined $val ) {
	    $val =~ s/\|\*\|/${ $apiis->reserved_strings }{v_concat}/g; #changing back to ordinary separator

	  if ( $val =~ /^\s*\$/ ){ # value is a variable
	    my @tmp_ext=();
	    if ($val=~/\s*\$(\b\w+\b)(?=\s*\[)\s*\[([^\]]+)\]/i) {
	      @tmp_ext = split /\s*,\s*/, $2;
	      $val=$1;
	    }
	    $val =~ s/^\s*\$//;  # remove leading $ from variables
	    push @ext_fields, [ $val ] unless @tmp_ext;
	    push @ext_fields, \@tmp_ext if @tmp_ext;
	    if ( exists $data_ref->{$val} ){
	      push @values, $data_ref->{$val};
	    } else {
			    my $err = Apiis::Errors->new( type        => 'CODE',
							  severity    => 'CRIT',
							  action      => $method,
							  from        => 'ParsePseudoSQL',
							  msg_long    => "No key/value for $val in passed hash!",
							);
			    push @error_objects, $err;
			    last UPD_LOOP;
	    };
	  } else {
	    # fixed string
	    push @values, $val;
	    push @ext_fields, [];
	  }
	  push @db_columns, $db_col;
	  print "\n\tfound SET: $db_col = $values[ $#values ]\n" if $debug >6;
	} else {
	  my $err = Apiis::Errors->new( type        => 'PARSE',
					severity    => 'CRIT',
					action      => $method,
					from        => 'ParsePseudoSQL',
					msg_short   => __("Cannot parse PseudoSQL"),
					msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
				      );
	  push @error_objects, $err;
	}
      }
	       #                   $' ? ($string = 'where ' . $') : ($string = '');
	       $whole_where ? ($string = 'where ' . $whole_where) : ($string = '');
	       next UPD_LOOP;
	     };
      
      
      # getting the WHERE clause:
             /^\s*where\s+(.*)/i &&
               do {
		 @wheres = ();
                  my $str = $1;
                  if ( $str =~ /concat\s*\(([^)]*)\)/i ) {
                     # e.g.: WHERE db_animal = concat( "society|sex", $dam_society."|2", $dam_hb_nr."|".$notch_nr )
                     my $before = $`;
                     my $after  = $';
                     my @parts  = parse_line( '\s*,\s*', 0, $1 );
                     if (@parts) {
                        foreach my $thispart (@parts) {
                           print "\t\tworking on part $thispart..."
                             if $debug > 6;
                           $thispart =~ s/^\s*//;    # remove leading blanks
                           $thispart =~ s/\s*$//;    # remove trailing blanks
                           my @part_parts = split /\s*\.\s*/, $thispart;
                           foreach my $this_p_p (@part_parts) {
                              ( $this_p_p =~ /\s*\$(\b\w+\b)\s*/ ) && do {
                                 if ( exists $data_ref->{$1} ) {
                                    $this_p_p = $data_ref->{$1};
                                 } else {
                                    $this_p_p = ">>>Error in LoadObject: No key/value for $1 in passed hash!<<<";
                                 }
                              };
                           }
                           $thispart = join ( '', @part_parts );
                           print " => $thispart\n" if $debug > 6;
                        }

                        $str =
                          $before . "'"
                          . join ( "${ $apiis->reserved_strings }{v_concat}", @parts ) . "'"
                          . $after;
                        print "\n\tfound: $str\n" if $debug > 6;
                     }
                  }
                  # ok, now we have the (concatenated) *external* value. Check if it is a coded column
                  # (if it has a db_ name) and get the internal value from the according view.
                  # Unfortunately we have to parse the where-clause now. To reduce the complexity
                  # I assume that only one WHERE condition exists (no AND/OR, NOT NULL, only col = val).
                  # Slow and dirty. :^(
		  # rffr (28.02.02) 'and' and 'or' probably run
		  # rffr if concat -- this clause have to be the end of total where(?)
		my  @str_val = ();
		 if ( $str =~ /\s+(AND|and|OR|or)\s+/ ) {
		   if ($str=~ /\s+AND\s+/) {
		     $operator1=' AND ';
		   } elsif ($str=~ /\s+and\s+/) {
		     $operator1=' and ';
		   } elsif ($str=~ /\s+or\s+/) {
		     $operator1=' or ';
		   } elsif ($str=~ /\s+OR\s+/) {
		     $operator1=' OR ';
		   }
		   @str_val = split(/\s+AND\s+|\s+and\s+|\s+OR\s+|\s+or\s+/, $str);
		 } else { push @str_val, $str; }
		 foreach my $str_v ( @str_val ) {
		   my $str = $str_v;


		   $str =~ s/${ $apiis->reserved_strings }{v_concat}/\|\*\|/g; #change the separator to '|*|' needed for the splitting
		   my ($operator, $delim);
		   map {if ($str =~/$_/) {$operator=' '.$_.' '; $delim='\s*'.$_.'\s*';}} ("=","\<","\>","\<=","\>=");
		   my ( $where_db_col, $where_val ) = parse_line( $delim, 0, $str );
		   print "column|$where_db_col| value|$where_val|\n" if $debug >6;
		  $where_val =~ s/\|\*\|/${ $apiis->reserved_strings }{v_concat}/g; #changing back to ordinary separator

		  $where_db_col =~ s/^\s*//;    # remove leading blanks
		  $where_db_col =~ s/\s*$//;    # remove trailing blanks
		  $where_val =~ s/^\s*//;    # remove leading blanks
		  $where_val =~ s/\s*$//;    # remove trailing blank

#now column name is $where_db_col and column value is in $where_val



                  my (@vals);
                  my $where_db_val;
                  if ( $where_val =~ /${$apiis->reserved_strings }{v_concat}/ ) {
                    @vals = split /${ $apiis->reserved_strings }{v_concat}/,$where_val;
                  } else {
                    my $val = $where_val;
		    if ( defined $val ){
                        if ( $val =~ /^\s*\$/ ){ # value is a variable
			  $val =~ s/^\s*\$//;  # remove leading $ from variables
			  $val =~ s/\s*$//;   # remove trailing
			  if ( exists $data_ref->{$val} ){
			    push @vals, $data_ref->{$val};
			  } else {
			    my $err = Apiis::Errors->new( type        => 'CODE',
							  severity    => 'CRIT',
							  action      => $method,
							  from        => 'ParsePseudoSQL',
							  msg_long    => "No key/value for $val in passed hash!",
							);
			    $apiis->log('debug',"ParsePseudoSQL: No key/value for $val in passed hash!");
			    push @error_objects, $err;
			    last UPD_LOOP;
			  }
                        } else {
			  # fixed string
			  push @vals, $val;
			}
		      } else {
                        my $err = Errors->new( type        => 'PARSE',
                                               severity    => 'CRITICAL',
                                               action      => $method,
                                               from        => 'ParsePseudoSQL',
					       msg_short   => __("Cannot parse PseudoSQL"),
					       msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
                                             );
			$apiis->log('debug',"ParsePseudoSQL: Cannot parse PseudoSQL part $string!");
                        push @error_objects, $err;
			last UPD_LOOP;
		      }
                  } 
		  my $record = Apiis::DataBase::Record->new( tablename => $table);
		  $record->column($where_db_col)->extdata(@vals);
		  $record->encode_column($where_db_col);
		  if ( $record->status ) {
		    foreach ( @{ $record->errors} ) {
		      $_->from( 'PseudoStatement->ParsePseudoSQL::' . $_->from );
		      $_->action($method)  unless $_->action;
		      $_->db_table($table) unless $_->db_table;
		      $_->db_column($where_db_col) unless $_->db_column;
		    }
		    push @error_objects, @{ $record->errors };
		    last UPD_LOOP;
		  } else {
		    $where_db_val = $record->column($where_db_col)->intdata;
		  }

		  print "\n\tfound WHERE SET: $where_db_col $operator $where_db_val\n" if $debug >6;
#                  $str = $where_db_col . ' = ' . $apiis->DataBase->dbh->quote($where_db_val);
                  $str = $where_db_col . $operator . $apiis->DataBase->dbh->quote($where_db_val);
                   if ( $str =~ /NULL/ ) { # NULL value is wrong in where statement
 		     my $err_n1 = Apiis::Errors->new( type        => 'DATA',
						      severity    => 'CRIT',
						      action      => 'UPDATE',
						      from        => 'UPDATE',
						      msg_short   => 'Found NULL in where clause',
						      msg_long    => " NULL is not implemented in where clause"
 				     );
            	      push @error_objects, $err_n1;
 	              last UPD_LOOP;
		   }
                  push @wheres, $str;
                  $string = '';
               } # foreach @str_val
		 # rffr (28.02.03) special table transfer adding *_dt notnull
 		 if ( $table =~ /transfer/ ) { # special table transfer
		   # if ( $whole_string =~ /exit_dt/ ) { # adding exit_dt isnull to where
		   #  my $str = 'exit_dt isnull';
		   #  push @wheres, $str;
		   # }
		   if ( $whole_string =~ /closing_dt/ ) {
		     my $str = 'closing_dt isnull';
		     push @wheres, $str;
		   }
		 }
               };
   
            if ( $i > 100 ){
               my $err = Apiis::Errors->new( type        => 'PARSE',
					     severity    => 'CRIT',
					     action      => $method,
					     from        => 'ParsePseudoSQL',
					     msg_short   => __("Cannot parse PseudoSQL"),
					     msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
					   );
               push @error_objects, $err;
               last UPD_LOOP;
            }
            $i++;
         }
         # successfull parsing done:
         my @tmp_data;
         for ($i = 0; $i <= $#db_columns; $i++){
            # remove leading and trailing whitespace
            # @{$ext_fields[$i]} = map { s/^\s*//; s/\s*$//; $_ } @{$ext_fields[$i]};
            my %tmp_hash;
            $tmp_hash{DB_COLUMN} = $db_columns[$i] || '';
            $tmp_hash{VALUE}     = $values[$i];
            $tmp_hash{EXT_FIELDS} = $ext_fields[$i] || [];
            push @tmp_data, \%tmp_hash;
         }
         %thisaction = (
            TYPE => $method,
            TABLE => $table,
            DATA => \@tmp_data,
         );
	 $operator1=' AND ' if (! $operator1);
         $thisaction{WHERE} = join($operator1, @wheres) if @wheres;
         if ($profiling) {
            print "elapsed in Update: ",
              ' ' x
              ( $max_prof_string - length("elapsed in Update: ") ),
              elapsed( \@before_update ), "\n";
         }
      } # end Update

      ######## DELETE ###########
      elsif ( $method eq 'DELETE' ){
	my @before_delete = Now() if $profiling;
	@wheres = ();
	my $operator1;
      DEL_LOOP:
	while ( $string ){  # unless $string is empty
	  $_ = $string;
	  print "\nremaining string: '$_'\n" if $debug >6;
	  # get the tablename:
	  /^from\s*(\w+)\s*(where)/i
	    && do {  $table = lc $1;
		     print "\n\tfound tablename: '$table'\n" if $debug >6;
		     $string = $2 . $'; # save $' before next s/// !!!:
		     next DEL_LOOP;
		   };
            # getting the WHERE clause:
            /^\s*where\s+(.*)/i &&
               do {
                  my $str = $1;
                  if ( $str =~ /concat\s*\(([^)]*)\)/i ) {
                     # e.g.: WHERE db_animal = concat( "society|sex", $dam_society."|2", $dam_hb_nr."|".$notch_nr )
                     my $before = $`;
                     my $after  = $';
                     my @parts  = parse_line( '\s*,\s*', 0, $1 );
                     if (@parts) {
                        foreach my $thispart (@parts) {
                           print "\t\tworking on part $thispart..."
                             if $debug > 6;
                           $thispart =~ s/^\s*//;    # remove leading blanks
                           $thispart =~ s/\s*$//;    # remove trailing blanks
                           my @part_parts = split /\s*\.\s*/, $thispart;
                           foreach my $this_p_p (@part_parts) {
                              ( $this_p_p =~ /\s*\$(\b\w+\b)\s*/ ) && do {
                                 if ( exists $data_ref->{$1} ) {
                                    $this_p_p = $data_ref->{$1};
                                 } else {
                                    $this_p_p = ">>>Error in LoadObject: No key/value for $1 in passed hash!<<<";
                                 }
                              };
                           }
                           $thispart = join ( '', @part_parts );
                           print " => $thispart\n" if $debug > 6;
                        }

                        $str =
                          $before . "'"
                          . join ( "${ $apiis->reserved_strings }{v_concat}", @parts ) . "'"
                          . $after;
                        print "\n\tfound: $str\n" if $debug > 6;
                     }
                  }

	    # ok, now we have the (concatenated) *external* value. Check if it is a coded column
	    # (if it has a db_ name) and get the internal value from the according view.
	    # Unfortunately we have to parse the where-clause now. To reduce the complexity
	    # only simple and|or statements possible ( no join... )
	    # ex: select $birth_dt, $db_sex from
	    #     WHERE db_animal =
	    # concat( "society|sex", $dam_society."|2", $dam_hb_nr."|".$notch_nr )';
	    # or: select $db_code from codes
	    #     where ext_code = $sex and class = "SEX"';
		
	    my @multwhere = ();
	    $multwhere[0] = $str;
            if ( $str =~ /\s+(AND|and|OR|or)\s+/ ) {
	      if ($str=~ /\s+AND\s+/) {
		$operator1=' AND ';
	      } elsif ($str=~ /\s+and\s+/) {
		$operator1=' and ';
	      } elsif ($str=~ /\s+or\s+/) {
		$operator1=' or ';
	      } elsif ($str=~ /\s+OR\s+/) {
		$operator1=' OR ';
	      }
	      @multwhere = split( /\s+AND\s+|\s+and\s+|\s+OR\s+|\s+or\s+/, $str );
	    }
	    foreach $str ( @multwhere ) {
	      $str =~ s/^\s*//;    # remove leading blanks
	      $str =~ s/\s*$//;    # remove trailing blanks
	      if ( $str =~ /NULL/ ) { # NULL value is wrong in where statement
		my $err_n2 = Apiis::Errors->new( type        => 'DATA',
						 severity    => 'CRIT',
						 action      => 'DELETE',
						 from        => 'DELETE',
						 msg_short   => 'Found NULL in where clause',
						 msg_long    => " NULL is not implemented in where clause"
					       );
		push @error_objects, $err_n2;
		last DEL_LOOP;
	      }
	      $str =~ s/${ $apiis->reserved_strings }{v_concat}/\|\*\|/g; #change the separator to '|*|' needed for the splitting
	      my ($operator, $delim);
	      map {if ($str =~/$_/) {$operator=' '.$_.' '; $delim='\s*'.$_.'\s*';}} ("=","\<","\>","\<=","\>=");
	      my ( $where_db_col, $where_val ) = parse_line( $delim, 0, $str );
	      print "column|$where_db_col| value|$where_val|\n" if $debug >6; 		  
	      
		  $where_val =~ s/\|\*\|/${ $apiis->reserved_strings }{v_concat}/g; #changing back to ordinary separator
		  $where_db_col =~ s/^\s*//;    # remove leading blanks
		  $where_db_col =~ s/\s*$//;    # remove trailing blanks
		  $where_val =~ s/^\s*//;    # remove leading blanks
		  $where_val =~ s/\s*$//;    # remove trailing blank

                  my (@vals);
                  my $where_db_val;
                  if ( $where_val =~ /${$apiis->reserved_strings }{v_concat}/ ) {
                    @vals = split /${ $apiis->reserved_strings }{v_concat}/,$where_val;
                  } else {
                    my $val = $where_val;
		    if ( defined $val ){
                        if ( $val =~ /^\s*\$/ ){ # value is a variable
			  $val =~ s/^\s*\$//;  # remove leading $ from variables
			  $val =~ s/\s*$//;   # remove trailing
			  if ( exists $data_ref->{$val} ){
			    push @vals, $data_ref->{$val};
			  } else {
			    my $err = Apiis::Errors->new( type        => 'CODE',
							  severity    => 'CRIT',
							  action      => $method,
							  from        => 'ParsePseudoSQL',
							  msg_long    => "No key/value for $val in passed hash!",
							);
			    push @error_objects, $err;
			    last DEL_LOOP;
			  }
                        } else {
			  # fixed string
			  push @vals, $val;
			}
		      } else {
                        my $err = Errors->new( type        => 'PARSE',
                                               severity    => 'CRITICAL',
                                               action      => $method,
                                               from        => 'ParsePseudoSQL',
					       msg_short   => __("Cannot parse PseudoSQL"),
					       msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
                                             );
                        push @error_objects, $err;
			last DEL_LOOP;
		      }
                  }
		  my $record = Apiis::DataBase::Record->new( tablename => $table);
		  $record->column($where_db_col)->extdata(@vals);
		  $record->encode_column($where_db_col);
		  if ( $record->status ) {
		    foreach ( @{ $record->errors} ) {
		      $_->from( 'PseudoStatement->ParsePseudoSQL::' . $_->from );
		      $_->action($method)  unless $_->action;
		      $_->db_table($table) unless $_->db_table;
		      $_->db_column($where_db_col) unless $_->db_column;
		    }
		    push @error_objects, @{ $record->errors };
		    last DEL_LOOP;
		  } else {
		    $where_db_val = $record->column($where_db_col)->intdata;
		  }

		  print "\n\tfound SET: $where_db_col $operator $where_db_val\n" if $debug >6;
                  $str = $where_db_col . $operator . $apiis->DataBase->dbh->quote($where_db_val);

	    if ( $str =~ /NULL/ ) { # NULL value is wrong in where statement
	      my $err_n = Apiis::Errors->new( type        => 'DATA',
					      severity    => 'CRIT',
					      action      => $method,
					      from        => 'DELETE',
					      msg_short   => 'Return VALUE = NULL in Delete (where)',
					      msg_long    => "Return VALUE = NULL in Delete (where)"
				     );
	      push @error_objects, $err_n;
	      last DEL_LOOP;
	    }
	    push @wheres, $str;
	    $string = '';
	    }
       };

            if ( $i > 100 ){
               my $err = Apiis::Errors->new( type        => 'PARSE',
					     severity    => 'CRIT',
					     action      => $method,
					     from        => 'ParsePseudoSQL',
					     msg_short   => __("Cannot parse PseudoSQL"),
					     msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
					   );
               push @error_objects, $err;
               last DEL_LOOP;
            }
            $i++;
         }

         # successfull parsing done:
         my @tmp_data;
         for ($i = 0; $i <= $#db_columns; $i++){
            # remove leading and trailing whitespace
            # @{$ext_fields[$i]} = map { s/^\s*//; s/\s*$//; $_ } @{$ext_fields[$i]};
            my %tmp_hash;
            $tmp_hash{DB_COLUMN} = $db_columns[$i] || '';
            $tmp_hash{VALUE}     = $values[$i];
            $tmp_hash{EXT_FIELDS} = $ext_fields[$i] || [];
            push @tmp_data, \%tmp_hash;
         }
         %thisaction = (
            TYPE => $method,
            TABLE => $table,
            DATA => \@tmp_data,
         );
	$operator1=' AND ' if (! $operator1);
	$thisaction{WHERE} = join($operator1, @wheres) if @wheres;
         if ($profiling) {
            print "elapsed in Delete: ",
              ' ' x
              ( $max_prof_string - length("elapsed in Delete: ") ),
              elapsed( \@before_delete ), "\n";
         }
      } # end Delete

      ######## Select ###########
      elsif ( $method eq 'SELECT' ){
         my @before_select = Now() if $profiling;
	 @wheres = ();
	 my $operator1;
         SEL_LOOP:
         while ( $string ){  # unless $string is empty
            $_ = $string;
            print "\nremaining string: '$_'\n" if $debug >6;

            # get the db_columns:
            /^\s*([\$a-zA-Z0-9_,\s]+)\s*(from)/i
               && do {  @db_columns = parse_line('\s*,\s*', 0, $1);
                        $string = $2 . $'; # save $' before next s/// !!!:
                        $db_columns[$#db_columns] =~ s/\s*$//; # remove trailing blanks from last element
                        print "\n\tfound db_columns: '", join(' - ',@db_columns),"'\n" if $debug >6;
			map { s/\$//g; } @db_columns; # remove $-signs
                        next SEL_LOOP;
                  };

            # get the tablename:
            /^from\s*(\w+)\s*(where)/i
               && do {  $table = lc $1;
                        print "\n\tfound tablename: '$table'\n" if $debug >6;
                        $string = $2 . $'; # save $' before next s/// !!!:
                        next SEL_LOOP;
                  };

            # getting the WHERE clause:
            /^\s*where\s+(.*)/i &&
               do {
                  my $str = $1;
                  if ( $str =~ /concat\s*\(([^)]*)\)/i ) {
                     # e.g.: WHERE db_animal = concat( "society|sex", $dam_society."|2", $dam_hb_nr."|".$notch_nr )
                     my $before = $`;
                     my $after  = $';
                     my @parts  = parse_line( '\s*,\s*', 0, $1 );
                     if (@parts) {
                        foreach my $thispart (@parts) {
                           print "\t\tworking on part $thispart..."
                             if $debug > 6;
                           $thispart =~ s/^\s*//;    # remove leading blanks
                           $thispart =~ s/\s*$//;    # remove trailing blanks
                           my @part_parts = split /\s*\.\s*/, $thispart;
                           foreach my $this_p_p (@part_parts) {
                              ( $this_p_p =~ /\s*\$(\b\w+\b)\s*/ ) && do {
                                 if ( exists $data_ref->{$1} ) {
                                    $this_p_p = $data_ref->{$1};
                                 } else {
                                    $this_p_p = ">>>Error in LoadObject: No key/value for $1 in passed hash!<<<";
                                 }
                              };
                           }
                           $thispart = join ( '', @part_parts );
                           print " => $thispart\n" if $debug > 6;
                        }

                        $str =
                          $before . "'"
                          . join ( "${ $apiis->reserved_strings }{v_concat}", @parts ) . "'"
                          . $after;
                        print "\n\tfound: $str\n" if $debug > 6;
                     }
                  }

	    # ok, now we have the (concatenated) *external* value. Check if it is a coded column
	    # (if it has a db_ name) and get the internal value from the according view.
	    # Unfortunately we have to parse the where-clause now. To reduce the complexity
	    # only simple and|or statements possible ( no join... )
	    # ex: select $birth_dt, $db_sex from
	    #     WHERE db_animal =
	    # concat( "society|sex", $dam_society."|2", $dam_hb_nr."|".$notch_nr )';
	    # or: select $db_code from codes
	    #     where ext_code = $sex and class = "SEX"';
	    
	    my @multwhere = ();
	    $multwhere[0] = $str;
	    if ( $str =~ /\s+(AND|and|OR|or)\s+/ ) {
	      if ($str=~ /\s+AND\s+/) {
		$operator1=' AND ';
	      } elsif ($str=~ /\s+and\s+/) {
		$operator1=' and ';
	      } elsif ($str=~ /\s+or\s+/) {
		$operator1=' or ';
	      } elsif ($str=~ /\s+OR\s+/) {
		$operator1=' OR ';
	      }
	      @multwhere = split( /\s+AND\s+|\s+and\s+|\s+OR\s+|\s+or\s+/, $str );
	    }
	    foreach $str ( @multwhere ) {
	      $str =~ s/^\s*//;    # remove leading blanks
	      $str =~ s/\s*$//;    # remove trailing blanks
	      next if (defined $operator1 and $operator1=~/$str/i);
	      if ( $str =~ /NULL/ ) { # NULL value is wrong in where statement
		my $err_n2 = Apiis::Errors->new( type        => 'DATA',
						 severity    => 'CRIT',
						 action      => 'SELECT',
						 from        => 'SELECT',
						 msg_short   => 'Found NULL in where clause',
						 msg_long    => " NULL is not implemented in where clause"
					       );
		push @error_objects, $err_n2;
		last SEL_LOOP;
	      }
	      $str =~ s/${ $apiis->reserved_strings }{v_concat}/\|\*\|/g; #change the separator to '|*|' needed for the splitting
	      my ($operator, $delim);
	      map {if ($str =~/$_/) {$operator=' '.$_.' '; $delim='\s*'.$_.'\s*';}} ("=","\<","\>","\<=","\>=");
	      my ( $where_db_col, $where_val ) = parse_line( $delim, 0, $str );
	      print "column|$where_db_col| value|$where_val|\n" if $debug >6; 		  
	      $where_val =~ s/\|\*\|/${ $apiis->reserved_strings }{v_concat}/g; #changing back to ordinary separator
		  $where_db_col =~ s/^\s*//;    # remove leading blanks
		  $where_db_col =~ s/\s*$//;    # remove trailing blanks
		  $where_val =~ s/^\s*//;    # remove leading blanks
		  $where_val =~ s/\s*$//;    # remove trailing blank

                  my (@vals);
                  my $where_db_val;
                  if ( $where_val =~ /${$apiis->reserved_strings }{v_concat}/ ) {
                    @vals = split /${ $apiis->reserved_strings }{v_concat}/,$where_val;
                  } else {
                    my $val = $where_val;
		    if ( defined $val ){
                        if ( $val =~ /^\s*\$/ ){ # value is a variable
			  $val =~ s/^\s*\$//;  # remove leading $ from variables
			  $val =~ s/\s*$//;   # remove trailing
			  if ( exists $data_ref->{$val} ){
			    push @vals, $data_ref->{$val};
			  } else {
			    my $err = Apiis::Errors->new( type        => 'CODE',
							  severity    => 'CRIT',
							  action      => $method,
							  from        => 'ParsePseudoSQL',
							  msg_long    => "No key/value for $val in passed hash!",
							);
			    push @error_objects, $err;
			    last SEL_LOOP;
			  }
                        } else {
			  # fixed string
			  push @vals, $val;
			}
		      } else {
                        my $err = Errors->new( type        => 'PARSE',
                                               severity    => 'CRITICAL',
                                               action      => $method,
                                               from        => 'ParsePseudoSQL',
					       msg_short   => __("Cannot parse PseudoSQL"),
					       msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
                                             );
                        push @error_objects, $err;
			last SEL_LOOP;
		      }
                  }
		  my $record = Apiis::DataBase::Record->new( tablename => $table);
		  $record->column($where_db_col)->extdata(@vals);
		  $record->encode_column($where_db_col);
		  if ( $record->status ) {
		    foreach ( @{ $record->errors} ) {
		      $_->from( 'PseudoStatement->ParsePseudoSQL::' . $_->from );
		      $_->action($method)  unless $_->action;
		      $_->db_table($table) unless $_->db_table;
		      $_->db_column($where_db_col) unless $_->db_column;
		    }
		    push @error_objects, @{ $record->errors };
		    last SEL_LOOP;
		  } else {
		    $where_db_val = $record->column($where_db_col)->intdata;
		  }

		  print "\n\tfound SET: $where_db_col $operator $where_db_val\n" if $debug >6;
                  $str = $where_db_col . $operator . $apiis->DataBase->dbh->quote($where_db_val);
	    if ( $str =~ /NULL/ ) { # NULL value is wrong in where statement
	      my $err_n = Apiis::Errors->new( type        => 'DATA',
					      severity    => 'CRIT',
					      action      => $method,
					      from        => 'SELECT',
					      msg_short   => 'Return VALUE = NULL in Select (where)',
					      msg_long    => "Return VALUE = NULL in Select (where)"
				     );
	      push @error_objects, $err_n;
	      last SEL_LOOP;
	    }
	    push @wheres, $str;
	    $string = '';
	    }
       };

            if ( $i > 100 ){
               my $err = Apiis::Errors->new( type        => 'PARSE',
					     severity    => 'CRIT',
					     action      => $method,
					     from        => 'ParsePseudoSQL',
					     msg_short   => __("Cannot parse PseudoSQL"),
					     msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
					   );
               push @error_objects, $err;
               last SEL_LOOP;
            }
            $i++;
         }

         # successfull parsing done:
         my @tmp_data;
         for ($i = 0; $i <= $#db_columns; $i++){
            # remove leading and trailing whitespace
            # @{$ext_fields[$i]} = map { s/^\s*//; s/\s*$//; $_ } @{$ext_fields[$i]};
            my %tmp_hash;
            $tmp_hash{DB_COLUMN} = $db_columns[$i] || '';
            $tmp_hash{VALUE}     = $values[$i];
            $tmp_hash{EXT_FIELDS} = $ext_fields[$i] || [];
            push @tmp_data, \%tmp_hash;
         }
         %thisaction = (
            TYPE => $method,
            TABLE => $table,
            DATA => \@tmp_data,
         );
	 $operator1=' AND ' if (! $operator1);
         $thisaction{WHERE} = join($operator1, @wheres) if @wheres;
         if ($profiling) {
            print "elapsed in Select: ",
              ' ' x
              ( $max_prof_string - length("elapsed in Select: ") ),
              elapsed( \@before_select ), "\n";
         }
      } # end Select
 else {
         my $err = Apiis::Errors->new( type        => 'PARSE',
				       severity    => 'CRIT',
				       action      => 'UNKNOWN',
				       from        => 'ParsePseudoSQL',
				       msg_long    => "Unknown PseudoSQL method $method",
				     );
         push @error_objects, $err;
      }
      if ( $i > 150 ){
         # last exit
         my $err = Apiis::Errors->new( type        => 'PARSE',
				       severity    => 'CRIT',
				       action      => 'UNKNOWN',
				       from        => 'ParsePseudoSQL',
				       msg_short   => __("Cannot parse PseudoSQL"),
				       msg_long    => __("Cannot parse PseudoSQL part: [_1]",$string)
				     );
         push @error_objects, $err;
         last MAIN_LOOP;
      }
      $i++;
      push @dbactions, \%thisaction if exists $thisaction{TYPE}; # if successfully filled
      $thisaction= \%thisaction if exists $thisaction{TYPE}; # if successfully filled
   } # end while @pseudo_sql
   print "number of error_objects when leaving ParsePseudoSQL: ", scalar @error_objects , "\n" if $debug >6;
#   return ( scalar @error_objects, \@error_objects, \@dbactions );
   return ( scalar @error_objects, \@error_objects, $thisaction );
} # end sub _ParsePseudoSQL


=head2 pull_quotes

 pull_quotes -- tom christiansen, tchrist@convex.com

=cut

sub pull_quotes { # pull_quotes($string, $quotchars) => @quotestrings
    $_=shift;
    my($qchars) = @_;

    my($xlate);

    if ($qchars =~ tr/\173\175/\373\375/) {
	$xlate++;
	tr/\173\175/\373\375/;
    } 

    my($qL, $qR); 		# left and right quote chars, like `' or ()
    my($quote_level);	# current quote level
    my($max_quote);		# deepest we've gotten
    my($qstring);		# tmp space for quote
    my(@quotes);		# list of quotes to return
    my($d) = '\$';		# not sure why this must be here
    my($b) = '\\';		# nor this
    my(@done);		# which quotes we've finished so far

    die "need two just quote chars" if length($qchars) != 2;

    $qL = substr($qchars, 0, 1);
    $qR = substr($qchars, 1, 1);

    s/\\(.)/"\201".ord($1)."\202"/eg;   # protect from backslashes

    $max_quote = $quote_level = $[-1;

    while ( /[$qchars]/ ) {
	if ($& eq $qL) {
	    do { ++$quote_level; } while $done[$quote_level];
	    s/$b$qL/\${QL${quote_level}}/;
	    $max_quote = $quote_level if $max_quote < $quote_level;
	} elsif ($& eq $qR) {
	    s/$b$qR/\${QR${quote_level}}/;
	    $done[$quote_level]++;
	    do { --$quote_level; } while $done[$quote_level];
	} else { 
	    die "unexpected quot char: $&";
	}
    } 
    for ($quote_level = $[; $quote_level <= $max_quote; $quote_level++) {
	($qstring) = /${d}\{QL$quote_level\}([^\000]*)${d}\{QR$quote_level}/;
	$qstring =~ s/\$\{QL\d+\}/$qL/g;
	$qstring =~ s/\$\{QR\d+\}/$qR/g;
	$qstring =~ s/\201(\d+)\202/pack('C',$1)/eg;
	$quotes[$quote_level] = $qstring;
    } 
    grep (tr/\373\375/\173\175/, @quotes) if $xlate;
 #   @quotes;
    return @quotes;
    #print "++(I)++@quotes+++\n";
} # pull_quotas

##############################################################################
1;

=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>
Helmut Lichtenberg <heli@tzv.fal.de>

=cut

__END__
