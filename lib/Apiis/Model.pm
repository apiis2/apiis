##############################################################################
# $Id: Model.pm,v 1.41 2019/10/02 21:58:06 ulf Exp $
##############################################################################
package Apiis::Model;
$VERSION = '$Revision: 1.41 $';
##############################################################################

=head1 NAME

Apiis::Model -- methods to access the model file data via the $apiis
structure

=head1 SYNOPSIS

   $apiis->join_model('breedprg');

The configuration data of the model file is mounted into the $apiis
structure simply by running the join_model method with the model file name
as the only parameter.

=head1 DESCRIPTION

This Model.pm module provides an object and the appropriate access methods.
With join_model they are passed to Apiis::Init.pm and there with _add_obj
added to the global structure

=head1 METHODS

=cut

##############################################################################

use strict;
use warnings;
use Carp;
use Apiis::Init;
use Apiis::CheckFile;
use Apiis::Init::Config;
use Digest::MD5;

@Apiis::Model::ISA = qw( Apiis::Init );
our $apiis;
##############################################################################

=head2 new (mostly internal)

Apiis::Model->new is mainly invoked by Apiis::Init. The user interface is
join_model.

=cut

sub new {
   my ( $invocant, %args ) = @_;
   croak "Missing initialisation in main file (", __PACKAGE__, ").\n"
     unless defined $apiis;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init(%args);
   return $self;
}
##############################################################################

=head2 _init (internal)

_init does the main initialization and creates the internal structure to
keep the model file values.

=cut

sub _init {
   my ( $self, %args ) = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++;    # Conway p. 243

   LOOP: {
      if ( not exists $args{model} ) {
         $self->status(1);
         $self->errors(
            Apiis::Errors->new(
               type      => 'CODE',
               severity  => 'ERR',
               from      => 'Apiis::Model',
               msg_short => "No key 'model' passed to Apiis::Model",
            )
         );
         last LOOP;
      }

      # analyze filename:
      ( $self->{'_basename'}, $self->{'_path'}, $self->{'_ext'} ) =
        $self->Apiis::CheckFile::_disassemble_filename( file => $args{model} );
      if ( $self->{'_ext'} eq '.model' ) {
         $self->status(1);
         $self->errors(
            Apiis::Errors->new(
               type      => 'CODE',
               severity  => 'ERR',
               from      => 'Model::_init',
               msg_short => __( "Please choose the xml-model file" ),
               backtrace => Carp::shortmess('invoked'),
            )
         );
         last LOOP;
      }
      $self->{"_fullname"} = $self->{'_basename'} . '.xml';

      $apiis->APIIS_LOCAL( $apiis->project( $self->basename ) );
      unless ( $apiis->APIIS_LOCAL ) {
         $self->status(1);
         $self->errors(
            Apiis::Errors->new(
               type      => 'CONFIG',
               severity  => 'CRIT',
               from      => 'Model::_init',
               msg_short => __("No such project '[_1]' defined", $self->basename ),
            )
         );
         last LOOP;
      }
      $self->{'_path'} = $apiis->APIIS_LOCAL . '/etc/';

      # load the model file structure:
      my $_complete_name = $self->{'_path'} . $self->{'_fullname'};
      my $href;

      # cache or not:
      my $memcache;
      my $memkey = $pack . q{_}; # create key with package name
      CACHE: {
          last CACHE if !$apiis->Cache->hasMemcached();

          if ( open my $modelfile, '<', $_complete_name ) {
              binmode($modelfile); # in case of UTF-8 characters
              my $ctx = Digest::MD5->new;
              $ctx->addfile(*$modelfile);
              close $modelfile;
              my $digest = $ctx->hexdigest;
              last CACHE if !$digest;
              $memkey .= $digest;
              $memcache = $apiis->Cache->memcache();
              $href   = $memcache->get( $memkey );
              if ($href) {
                  # $main::apiis->log( 'info',
                  #  sprintf "Loaded Model structure %s (%s) from memcached\n",
                  #  $memkey, $_complete_name );
                  last CACHE;
              }
          }
      }

      # cache works but no entry for $href:
      if ( !$href) {
          # parse the xml model file:
          # Note: No variable substitution (e.g. $today, $now, $user) happens
          #       with the xml file. This should be done by triggers or in the
          #       user interfaces.
          eval {
              $href = $self->Apiis::Init::Config::_xml2model(
                  xmlfile => $_complete_name );
          };
          if ($@) {
              $self->status(1);
              $self->errors(
                  Apiis::Errors->new(
                      type      => 'CONFIG',
                      severity  => 'CRIT',
                      from      => 'Model::_init->xml2model',
                      msg_short => __("Error in model file"),
                      msg_long  => scalar $@,
                  )
              );
              last LOOP;
          }

          # store it in cache if memcached is running:
          if ( $memcache ){
              $memcache->set( $memkey, $href, 60*60*24*20 ); #expire in 20 days
              # $main::apiis->log( 'info',
              #    sprintf "Loading Model structure %s (%s) into memcached\n",
              #    $memkey, $_complete_name );
          }
      }

      $self->{"_db_driver"}   = $href->{'general'}->{'dbdriver'};
      $self->{"_db_name"}     = $href->{'general'}->{'dbname'};
      $self->{"_db_host"}     = $href->{'general'}->{'dbhost'};
      $self->{"_db_port"}     = $href->{'general'}->{'dbport'};

      #--mue
      #-- set db_user depends on access_rights in apiisrc and the definition in etc/$model.xml 
      if ((lc($apiis->access_rights) eq 'none') and ( $href->{'general'}->{'dbuser'} eq '')) {
              $self->{"_db_user"}=$apiis->os_user;
      }
      elsif (($apiis->access_rights eq 'AR') and ( $href->{'general'}->{'dbuser'} eq '')) {
              $self->{"_db_user"}='apiis_admin';
      }
      else {
          $self->{"_db_user"}     = $href->{'general'}->{'dbuser'};
      }

      $self->{"_db_password"} = $href->{'general'}->{'dbpassword'};
      $self->{"_db_encoding"} = lc $href->{'general'}->{'dbencoding'};
      $self->{"_db_pg_enable_utf8"} = lc $href->{'general'}->{'dbpg_enable_utf8'};
      
      push @{$self->{"_tables"}}, @{ $href->{'table'}->{'_table_order'} };

      # table based information:
      my $_max_level = 0;
      foreach my $thistable ( @{ $self->{"_tables"} } ) {
         # collect view definitions:
         push @{ $self->{"_views"} },
            $href->{'table'}->{$thistable}->{'pk'}->{'view'}
            if $href->{'table'}->{$thistable}->{'pk'}->{'view'};
         # create table objects and cache them:
         $apiis->Cache->{'tableobjects'}->{$thistable} =
            Apiis::Model::TableObj->new( $thistable, $href->{'table'}->{$thistable} );
         $apiis->log('debug', "Cache: new tableobject for table '$thistable' added");

         # get the max check_level:
         foreach my $thiscol ( @{ $href->{'table'}->{$thistable}->{'_column_order'} } ) {
            for ( my $i = 1 ; $i <= 9 ; $i++ ) {
               if ( exists $href->{'table'}->{$thistable}->{'column'}->{$thiscol}->{ 'CHECK' . $i } ) {
                  $_max_level = $i if $i > $_max_level;
                  $_max_level += 0;    # to remove leading zeros
               }
            }
         }
      }
      $self->{"_max_check_level"}     = $_max_level;
      $self->{"_current_check_level"} = 0
        unless defined $self->{"_current_check_level"};
   };    # end LOOP
}

##############################################################################
# access methods:
##############################################################################

=head2 $apiis->Model->[fullname | basename | ext | path | db_driver | db_name
| db_host | db_port | db_user | db_password | max_check_level] (all public, readonly)

fullname, basename, ext, path provide the fullname (basename.extension),
basename (without extension), extension, and path of the model file.

The db_... methods reflect the database configurations at the top of the
model file.

max_check_level gives you the maximal configured checklevel of this model
file, if anybody really needs it.

=cut

# return the according hash entry for the public methods (readonly):
sub fullname        { return $_[0]->{"_fullname"}; }
sub basename        { return $_[0]->{"_basename"}; }
sub ext             { return $_[0]->{"_ext"}; }
sub path            { return $_[0]->{"_path"}; }
sub db_driver       { return $_[0]->{"_db_driver"}; }
sub db_name         { return $_[0]->{"_db_name"}; }
sub db_host         { return $_[0]->{"_db_host"}; }
sub db_port         { return $_[0]->{"_db_port"}; }
sub db_user         { return $_[0]->{"_db_user"}; }
sub db_password     { return $_[0]->{"_db_password"}; }
sub db_encoding     { return $_[0]->{"_db_encoding"}; }
sub db_pg_enable_utf8 { return $_[0]->{"_db_pg_enable_utf8"}; }
sub max_check_level { return $_[0]->{"_max_check_level"}; }
##############################################################################

=head2 tables (public, readonly)

$apiis-Model->tables returns the names of the defined tables. If you want
an array, it gives you an array of these tables. If you want a scalar, you
also get what you want, a reference to the same array.

=cut

sub tables {
   wantarray && return @{ $_[0]->{"_tables"} };
   return $_[0]->{"_tables"};
}

# views may disappear in the future, so they stay undocumented.
sub views {
   wantarray && return @{ $_[0]->{"_views"} };
   return $_[0]->{"_views"};
}

##############################################################################

=head2 table (public, readonly)

   $apiis->Model->table( $tablename );

returns an object of Apiis::Model::TableObj for this tablename.

=cut

sub table {
   my ( $self, $table ) = @_;
   return unless defined $table;
   if ( grep /^${table}$/, $self->tables ){
      return $apiis->Cache->{'tableobjects'}->{$table};
   } else {
      $self->status(1);
      $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'Apiis::Model::table',
            msg_short => __("Unknown table [_1]", $table),
         )
      );
   }
   return undef;
}

##############################################################################

=head2 check_level (public, read/write)

   my $current_level = $apiis->Model->check_level;
   my $old_level = $apiis->Model->check_level(2);
      ... do some work
   $apiis->Model->check_level( $old_level );

Without an parameter check_level returns the current check level. You can
change the current check level by passing the new level to check_level,
which then returns the old check level.

check_level also tests, if a passed new level is numeric and does not
exceed the maximum defined level in the model file.

=cut

sub check_level {
   my ( $self, $level ) = @_;

   # test for defined $level leads to wrong results as also undef can
   # be passed, e.g. from a database value.  Undef acts like 0.
   # So better ask for the number of arguments:
   if ( $#_ == 1 ) {
      $level = 0 unless defined $level;
      croak('level must be numeric') if $level =~ /\D/;
      croak( 'max allowed level in model file is ' . $self->max_check_level )
        if $level > $self->max_check_level;
      my $old_level = $self->{"_current_check_level"};
      $self->{"_current_check_level"} = $level;
      return $old_level;
   } else {
      return $self->{"_current_check_level"};
   }

}

##############################################################################
# Some subroutines to handle record_obj->delete and checking FK references:

# get/set flag to check, if _fk_struct is already created:
sub has_fk_struct {
   $_[0]->{'_has_fk_struct'} = $_[1] if defined $_[1];
   return $_[0]->{'_has_fk_struct'};
}

# create the structure that represents, which table.columns have foreign keys
# that point to them. This is needed for record deleting to allow only
# deletion of leafs in FK-trees.
# Example of the structure:
#   'transfer' => { 'db_animal' => [ [ 'animal',  'db_animal' ],
#                                    [ 'animal',  'db_sire' ],
#                                    [ 'animal',  'db_dam' ],
#                                    [ 'service', 'db_animal' ]
#                                  ]
#   },
sub build_fk_struct {
    my $self = shift;
    return if $self->has_fk_struct;
    for my $table ( $self->tables ) {
        my $table_obj = $self->table($table);

        COLUMN:
        for my $col ( $table_obj->columns ) {
            my $col_obj = $table_obj->column($col);
            my $fk_ref  = $col_obj->foreignkey;
            next COLUMN if !$fk_ref;
            # hash with keys table -> column,
            # value: array of arrays (table, column whose FK points here)
            push @{ $self->{'_fk_struct'}{ $fk_ref->[0] }{ $fk_ref->[1] } },
                [ $table, $col ];
        }
    }
    $self->has_fk_struct(1);
    return;
}

# return, if some columns have a ForeignKey, pointing to the passed
# table.column:
sub has_fk_from {
    my ( $self, $args_ref ) = @_;
    my $table = $args_ref->{table};
    my $column = $args_ref->{column};
    return if !$table;
    return if !$column;
    my $fk_struct = $self->{'_fk_struct'};
    return if !exists $fk_struct->{$table};
    return if !exists $fk_struct->{$table}{$column};
    return $fk_struct->{$table}{$column};
}

##############################################################################
##############################################################################
package Apiis::Model::TableObj;
$Apiis::Model::TableObj::VERSION = '$Revision: 1.41 $';

use Apiis::Init;
@Apiis::Model::TableObj::ISA = qw( Apiis::Init );

=head1 NAME

Apiis::Model::TableObj -- internal package to provide a table object with
methods to access a single table and its columns

=head1 SYNOPSIS

Programming interface:

   $table_obj = Apiis::Model::TableObj->new( $tablename, $struct_ref);

Usage: 

   $table_obj = $apiis->Model->table('animal');

=head1 METHODS

=head2 new (mostly internal)

To create the table object, new() needs as input the table name and a
reference to the datastructure of this table from the model file:

   $table_obj = Apiis::Model::TableObj->new( $tablename, $struct_ref);

The order of the columns in the model file is preserved.

=cut

sub new {
   my ( $class, $tablename, $t_href ) = @_;
   my $self = bless {}, ref($class) || $class;

   $self->{'_db_columns'} = $t_href->{'_column_order'};
   $self->{'_name'}  = $tablename;
   $self->{'_pk'}  = $t_href->{'pk'};
   $self->{'_index'}  = $t_href->{'index'};
   $self->{'_trigger'}  = $t_href->{'trigger'};
   $self->{'_sequence'}  = $t_href->{'sequence'};
   $self->{'_struct_type'}  = $t_href->{'struct_type'};

   foreach my $thiscol ( @{ $self->{'_db_columns'} } ) {
      $self->{'_columns'}->{$thiscol} =
         Apiis::Model::ColumnObj->new( $thiscol, $t_href->{'column'}->{$thiscol} );
   }
   return $self;
}

##############################################################################

=head2 column (public, readonly)

$table_obj->column( $col_name ) returns the column object for this column

=cut

sub column {
   my ( $self, $colname ) = @_;
   return undef unless $_[1];
   return $_[0]->{'_columns'}->{$_[1]}
     if exists $_[0]->{'_columns'}->{$_[1]};
}
##############################################################################

=head2 name (public, readonly)

$table_obj->name returns the name of this table.

=head2 struct_type (public, readonly)

$table_obj->struct_type returns the structural type of this table.
Current values of struct_type can be mandatory, recommended, and optional.

=head2 columns/cols (public, readonly)

$table_obj->cols returns the columns of this table.
$table_obj->columns is just an alias.

=cut

sub cols {
   wantarray && return @{ $_[0]->{'_db_columns'} };
   return $_[0]->{'_db_columns'};
}
*columns = *cols; # alias
sub name { return $_[0]->{'_name'} }
sub struct_type { return $_[0]->{'_struct_type'} }

##############################################################################

=head2 primarykey (public, readonly)

primarykey() needs one argument, which is either 'ref_col', 'view',
'where', or 'concat'.

   $table_obj->primarykey('ref_col')

returns the reference column to which this primary key in the table refers
to.

   $table_obj->primarykey('concat')

returns the external columns, that build the concatenated primary key. The
old syntax of $table_obj->primarykey('ext_cols') is still supported but
deprecated.

   $table_obj->primarykey('view')

returns the viewname of the view, that finally provides the foreignkey
through the where clause:

   $table_obj->primarykey('where')

Often the where clause is 'closing_dt is NULL'. The resulting view then
shows only records, which are not closed.

=cut

sub primarykey {
   my ( $self, $key ) = @_;
   return undef unless exists $self->{'_pk'};
   return $self->{'_pk'}->{'ref_col'} if $key eq 'ref_col';
   return $self->{'_pk'}->{'view'} if $key eq 'view';
   return $self->{'_pk'}->{'where'}  if $key eq 'where';
   # ext_cols for compatibility reasons:
   if ( $key eq 'concat' or $key eq 'ext_cols' ) {
      wantarray && return @{ $self->{'_pk'}->{'concat'} };
      return $self->{'_pk'}->{'concat'};
   }
   $self->status(1);
   $self->errors(
      Apiis::Errors->new(
         type      => 'CODE',
         severity  => 'ERR',
         from      => 'primarykey',
         msg_short => "Wrong key '$key' passed to \$col_obj->primarykey( <key> )",
         backtrace => Carp::longmess('invoked'),
      )
   );
   return undef;
}
##############################################################################

=head2 $table_obj->[sequence | sequences | index | indices | indexes] (public,
readonly)

They return the index and the sequence entries for the table,
either as an array or as an array reference. There are only two
methods, the others act like aliases.

usage:

   my @indices = $table_obj->indices;
   my $sequences_ref = $table_obj->sequences;

=cut

sub sequence {
   my $self = shift;
   return undef unless exists $self->{'_sequence'};
   wantarray && return @{ $self->{'_sequence'} };
   return $self->{'_sequence'};
}
sub index {
   my $self = shift;
   return undef unless exists $self->{'_index'};
   wantarray && return @{ $self->{'_index'} };
   return $self->{'_index'};
}
*sequences = *sequence;
*indices = *index;
*indexes = *index;
##############################################################################

=head2 $table_obj->triggers( $triggertype ) (public, readonly)

The method B<triggers> takes the following triggertypes as argument:

   $table_obj->triggers( 'preinsert' );
   $table_obj->triggers( 'postinsert' );
   $table_obj->triggers( 'preupdate' );
   $table_obj->triggers( 'postupdate' );
   $table_obj->triggers( 'predelete' );
   $table_obj->triggers( 'postdelete' );

and returns the triggers for this type. Depending on the calling context
they will be returned as a list or as an array reference.

=cut

sub triggers {
   my ( $self, $type ) = @_;
   return undef unless exists $self->{'_trigger'};
   my %types = (
      preinsert  => 1,
      postinsert => 1,
      preupdate  => 1,
      postupdate => 1,
      predelete  => 1,
      postdelete => 1,
   );

   if ( exists $types{$type} ) {
      return undef unless exists $self->{'_trigger'}->{ uc $type }; # uppercase
      wantarray && return @{ $self->{'_trigger'}->{ uc $type } };
      return $self->{'_trigger'}->{ uc $type };
   } else {
      $self->status(1);
      $self->errors(
         Apiis::Errors->new(
            type      => 'CODE',
            severity  => 'ERR',
            db_table  => $self->tablename,
            from      => 'triggers',
            msg_short => "Wrong trigger type '$type' passed.",
            backtrace => Carp::longmess('invoked'),
         )
      );

   }
   return undef;
}
##############################################################################

=head2 $table_obj->[datatype | length | default | description | check | modify | foreignkey | label] (public, readonly)

Although these methods are column methods, they are kept here for
compatibility reasons.

The old, still valid (but deprecated) syntax

   my $descr = $table_obj->description( $column_name );

should now be better written as:

   my $descr = $column_obj->description;

or

   my $descr = $table_obj->column( $column_name )->description;

=cut

sub datatype { return $_[0]->column( $_[1] )->datatype }
sub length { return $_[0]->column( $_[1] )->length }
sub default { return $_[0]->column( $_[1] )->default }
sub description { return $_[0]->column( $_[1] )->description }
sub check { return $_[0]->column( $_[1] )->check }
sub modify { return $_[0]->column( $_[1] )->modify }
sub foreignkey {return $_[0]->column( $_[1] )->foreignkey }
sub label { return $_[0]->column( $_[1] )->label }

##############################################################################
##############################################################################
package Apiis::Model::ColumnObj;
$Apiis::Model::ColumnObj::VERSION = '$Revision: 1.41 $';

use Apiis::Init;
@Apiis::Model::ColumnObj::ISA = qw( Apiis::Init );

=head1 NAME

Apiis::Model::ColumnObj -- internal package to provide a column object with
methods to access a single column of a table

=head1 SYNOPSIS

   $col_obj = $table_obj->column( $column_name );

=head1 DESCRIPTION

=head1 METHODS

=head2 $column_obj->[datatype | length | default | description | check | modify | struct_type | label] (public, readonly)

Example:
   my $datatype = $column_obj->datatype;

The according values from the model file are returned. All these
methods are readonly.

check() returns the rules for the current check level. If a check level
for a column is defined/exists, this one is taken.

If there is no CHECKn defined for check level n the default CHECK is taken.
This also applies if e.g. CHECK2 is defined in the model file but no
CHECK1. In this case the default CHECK is taken for CHECK1 as this is
undef.

=cut

sub new {
   my ( $class, $colname, $c_href ) = @_;
   my $self = bless {}, ref($class) || $class;
   $self->{'_name'}        = $colname;                   # eq DB_COLUMN
   foreach my $thiskey ( keys %{$c_href} ){
      $self->{'_' . lc $thiskey } = $c_href->{$thiskey};
   }
   return $self;
}
sub name { return $_[0]->{'_name'} }
sub check {
   # if not defined CHECKn return CHECK, otherwise CHECKn:
   if ( my $cl = $apiis->Model->check_level ) {
      if ( exists $_[0]->{ '_check' . $cl } ) {
         wantarray && return @{ $_[0]->{ '_check' . $cl } };
         return $_[0]->{ '_check' . $cl };
      }
   }
   if ( exists $_[0]->{'_check'} ) {
      wantarray && return @{ $_[0]->{'_check'} };
      return $_[0]->{'_check'};
   }
   return undef;
###    if ( not defined $__wh{$attr}{$key}[ $apiis->Model->check_level ] ) {
###       return if $apiis->Model->check_level == 0;    # undefined CHECK
###            # wantarray && return @{ $__wh{$attr}{$key}[0] };
###       if (wantarray) {
###          if ( ref $__wh{$attr}{$key}[0] eq 'ARRAY' ) {
###             return @{ $__wh{$attr}{$key}[0] };
###          }
###       }
###       return $__wh{$attr}{$key}[0];
###    }
###    wantarray && return @{ $__wh{$attr}{$key}[ $apiis->Model->check_level ] };
###    return $__wh{$attr}{$key}[ $apiis->Model->check_level ];
}
sub modify {
   return undef unless exists $_[0]->{ '_modify' };
   wantarray && return @{ $_[0]->{ '_modify' } };
   return $_[0]->{ '_modify' };
}

sub datatype    { return $_[0]->{'_datatype'} }
sub length      { return $_[0]->{'_length'} }
sub default     { return $_[0]->{'_default'} }
sub description { return $_[0]->{'_description'} }
sub struct_type { return $_[0]->{'_struct_type'} }
sub form_type   { return $_[0]->{'_form_type'} }
sub ar_check    { return $_[0]->{'_ar_check'} }
sub label       { return $_[0]->{'_label'} }
##############################################################################

=head2 foreignkey (public, readonly)

   my ($fk_table, $fk_column) = $column_obj->foreignkey;

foreignkey() returns the defined foreign key table and the foreign key
column for this column, either as an array or as a
reference to an array, depending on the callers context.

It returns undef if no foreign key is defined.

=cut

# get the Foreign Key for a column

sub foreignkey {
   my ( $self ) = @_;
   return undef unless exists $self->{'_check'};
   foreach my $thisrule ( @{ $self->{'_check'} } ) {
      next unless defined $thisrule;
      next if $thisrule !~ /^\s*ForeignKey/;
      require Text::ParseWords;
      # e.g. 'ForeignKey unit db_unit'
      # or 'ForeignKey codes db_code class=SEX'
      my ( $fk, $table, $col, @rest ) = Text::ParseWords::parse_line( '\s+', 0, $thisrule );
      if ( defined $table and defined $col ) {
         wantarray && return ( $table, $col, @rest );
         return [ $table, $col, @rest ];
      }
   }
   return undef;
}
##############################################################################
1;

