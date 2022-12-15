##############################################################################
# $Id: Record.pm,v 1.60 2014/12/08 08:56:55 heli Exp $
##############################################################################
package Apiis::DataBase::Record;
$VERSION = '$Revision: 1.60 $';
##############################################################################
# Database specific package for creating records of type database.
# It creates a record for tables of the model file and provides this table with
# the necessary table methods
#   tablename       - returns the table name for this record (like name)
#   type            - type database
#   methods         - publicly available methods
#   pk_ext_cols     - reflects the entry of the model file
#   pk_ref_col      - reflects the entry of the model file
#   sequences       - reflects the entry of the model file
#   indexes         - reflects the entry of the model file
#   check_level     - current check level
#   max_check_level - max defined check level in model file
#   encode_record   - encode the external data of all columns in this
#                     record into internal, according to the model file
#   decode_record   - vice versa
##############################################################################

=head1 NAME

Apiis::DataBase::Record -- package for DataBase Record objects

=head1 SYNOPSIS

This base package provides the functionality and methods needed for
database record object types.

=head1 DESCRIPTION

The public and internal methods of this base class are described below.

=head1 METHODS

=cut

##############################################################################

use strict;
use warnings;
use Carp qw(croak);
use List::Util qw( first );
use Scalar::Util qw( weaken );

use Apiis;
use base qw(
    Apiis::Init
    Apiis::DataBase::Record::Check
    Apiis::DataBase::Record::Modify
    Apiis::DataBase::Record::Trigger
);

use Apiis::DataBase::Record::Column;
use Apiis::DataBase::Record::Insert;
use Apiis::DataBase::Record::Update;
use Apiis::DataBase::Record::Delete;
use Apiis::DataBase::Record::Fetch;
use Apiis::DataBase::Record::Encode;
use Apiis::DataBase::Record::Decode;

# for debugging:
# use Class::ISA;
# print "Apiis::DataBase::Record path is:\n ",
# join ( ", ", Class::ISA::super_path('Apiis::DataBase::Record') ), "\n";

our $apiis;
##############################################################################

=head2 new (public)

B<new()> returns an object reference for a new record object.

=cut

sub new {
    my ( $invocant, %args ) = @_;
    if ( !defined $apiis ) {
        croak sprintf "Missing initialisation in main file (%s)\n", __PACKAGE__;
    }
    my $class = ref($invocant) || $invocant;
    my $self = bless {}, $class;
    if ( exists $args{hashref} ) {
        # args passed as hashref, e.g. from Column obj:
        $self->_init( $args{hashref} );
    }
    else {
        # normal, public interface as hash:
        $self->_init( \%args );
    }

    # leave early if errors in _init occurred:
    return $self if $self->status;

    # checking parameters, name required:
    if ( not exists $self->{'_name'} ) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'CRIT',
                from      => 'Apiis::DataBase::Record::new',
                msg_short =>
                    __("No key 'name' passed to Apiis::DataBase::Record"),
            )
        );
    }
    return $self;
}
##############################################################################

# initialisation:
sub _init {
    my ( $self, $args_ref ) = @_;
    my $pack = __PACKAGE__;

    EXIT: {
        last EXIT if $self->{"_init"}{$pack}++;    # Conway p. 243
        if ( !$apiis->exists_model ) {
            croak 'No model file joined to global $apiis';
        }

        # shortcut to save $apiis->log invocations:
        my $debug = $apiis->debug;

        # checking parameters, tablename required:
        if ( not exists $args_ref->{tablename} ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'CRIT',
                    from      => 'Apiis::DataBase::Record',
                    msg_short =>
                        "No key 'tablename' passed to Apiis::DataBase::Record",
                )
            );
            last EXIT;
        }
        my $tablename = $args_ref->{tablename};

        # does table exist in model:
        if ( !first { $_ eq $tablename } $apiis->Model->tables ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'CRIT',
                    from      => 'Apiis::DataBase::Record::_init',
                    msg_short => __(
                        "Non existing tablename '[_1]' passed", $tablename ),
                    )
            );
            last EXIT;
        }

        $self->{'_tablename'} = $tablename;
        $self->{'_name'}      = $tablename;
        $self->{'_type'}      = 'database';
        my $table_obj = $apiis->Model->table($tablename);
        weaken($table_obj);

        # get other table definitions:
        $self->{'_struct_type'}         = $table_obj->struct_type;
        $self->{'_pk_ref_col'}          = $table_obj->primarykey('ref_col');
        $self->{'_pk_ext_cols'}         = $table_obj->primarykey('ext_cols');
        $self->{'_indexes'}             = $table_obj->index;
        $self->{'_sequences'}           = $table_obj->sequence;
        $self->{'_check_level'}         = \&{ $apiis->Model->check_level };
        $self->{'_max_check_level'}     = $apiis->Model->max_check_level;
        $self->{'_preinsert_triggers'}  = $table_obj->triggers('preinsert');
        $self->{'_postinsert_triggers'} = $table_obj->triggers('postinsert');
        $self->{'_preupdate_triggers'}  = $table_obj->triggers('preupdate');
        $self->{'_postupdate_triggers'} = $table_obj->triggers('postupdate');
        $self->{'_predelete_triggers'}  = $table_obj->triggers('predelete');
        $self->{'_postdelete_triggers'} = $table_obj->triggers('postdelete');

        # predefine _encoded and _decoded:
        $self->{'_encoded'} = 1;
        $self->{'_decoded'} = 1;

        # get all database columns for this table object:
        my $rowid_done = 0;
        my $rowid_name = $apiis->DataBase->rowid;
        foreach my $thiscol ( $table_obj->cols ) {
            $rowid_done = 1 if $thiscol eq $rowid_name;
            my $model_col_obj = $table_obj->column($thiscol);
            weaken($model_col_obj);
            # create a new column object for each column of the model file
            # and add the definitions of the model file:
            my %col_args = (
                _name        => $thiscol,
                _tablename   => $tablename,
                _tableobj    => $self,
                _db_column   => $thiscol,
                _struct_type => $model_col_obj->struct_type,
                _form_type   => $model_col_obj->form_type,
                _ar_check    => $model_col_obj->ar_check,
                _datatype    => $model_col_obj->datatype,
                _length      => $model_col_obj->length,
                _description => $model_col_obj->description,
                _default     => $model_col_obj->default,
                _check       => scalar $model_col_obj->check,        # arrayref
                _modify      => scalar $model_col_obj->modify,
                _foreignkey  => scalar $model_col_obj->foreignkey,
            );
            my $col_obj =
                Apiis::DataBase::Record::Column->new( hashref => \%col_args );
            $self->addcolumn($col_obj);
        }

        # add the oid column to this record (if it is not done yet):
        #  could this happen???
        if ( not $rowid_done ) {
            my $datatype = 'unknown';
            $datatype = 'oid'
                if $rowid_name               eq 'oid'
                and $apiis->Model->db_driver eq 'Pg';    # bad hack :^(

            my %col_args = (
                _name        => $rowid_name,
                _tablename   => $tablename,
                _tableobj    => $self,
                _db_column   => $rowid_name,
                _datatype    => $datatype,
                _description => 'Rowid/OID of this record',
            );
            my $col_obj =
                Apiis::DataBase::Record::Column->new( hashref => \%col_args );
            $self->addcolumn($col_obj);
        }
    } # end label EXIT
    return;
}
##############################################################################
# create standard methods for these module attributes:

=head2 name (public, readonly)

Returns the name of this record (usually identical with the tablename of
the database record):

=cut

sub name { return $_[0]->{'_name'} }
##############################################################################

=head2 columns (public, readonly)

Returns an array of all column names of this record in the order of the
model file structure.

=cut

sub columns {
    my $self = shift;
    # Problem: an array makes deleting of one entry difficult,
    # a hash does not preserve the order.
    # Solution: take the order from an array and check the existence via
    # the hash keys:
    my @result;
    foreach ( @{ $self->{'_column_names_order'} } ) {
        push @result, $_ if exists $self->{'_column_names'}{$_};
    }
    wantarray && return @result;
    return \@result;
}
##############################################################################

=head2 column (public, readonly)

Returns a column object by column name. Example:

   my $col_obj = $record_obj->column($thiscolumn);

=cut

sub column {
    my ( $self, $col ) = @_;
    return unless defined $col;
    return $self->{_column_objects}{$col}
        if exists $self->{_column_objects}{$col};

    # Note:
    # Error handling, if a column is provided that does not exist in the
    # table.  If you invoke the form:
    #    $record_obj->column('does_not_exist')->extdata('some data');
    # you get the error message: Can't call method "extdata" on unblessed
    # reference ...  This is difficult to catch as there is no status checking
    # possible between the invocation of column() and extdata(). I raise an
    # error nevertheless to get the entry in the log files.

    $self->errors(
        Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'Apiis::DataBase::Record::column',
            msg_short => __(
                "Column '[_1]' does not exist in table '[_2]'", $col,
                $self->name
            ),
        )
    );
    $self->status(1);
    return;
}
##############################################################################

=head2 addcolumn (public)

Adds a column object to the record. Maybe only for internal use.

=cut

sub addcolumn {
    my ( $self, $col_obj ) = @_;
    if ( not defined $col_obj or not defined $col_obj->name ) {
        $self->status(1);
        my $text = __('column name');
        $text = __('column object') if !defined $col_obj;
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'CRIT',
                from      => 'Apiis::DataBase::Record::addcolumn',
                msg_short =>
                    __( 'Undefined [_1] in method [_2]', $text, 'addcolumn' ),
            )
        );
    }
    else {
        $self->{'_column_objects'}{ $col_obj->name } = $col_obj;
        $self->{'_column_names'}{ $col_obj->name }   = 1;
        push @{ $self->{'_column_names_order'} }, $col_obj->name;
    }
}
##############################################################################

=head2 delcolumn (public)

Deletes a column object from the record. Maybe only for internal use.

=cut

sub delcolumn {
    my ( $self, $name ) = @_;
    if ( !defined $name ) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'CRIT',
                from      => 'Apiis::DataBase::Record::delcolumn',
                msg_short =>
                    __( 'Undefined [_1] in method [_2]', 'name', 'delcolumn' ),
            )
        );
        return;
    }
    delete $self->{'_column_objects'}{$name};
    delete $self->{'_column_names'}{$name};
    return;
}
##############################################################################

=head2 rows | value | fk_table | values (public, read/write)

Methods for return status parameters, e.g. for SQL query results.

=cut

sub rows { $_[0]->{'_rows'} = $_[1] if defined $_[1]; return $_[0]->{'_rows'} }

sub value {
    $_[0]->{'_value'} = $_[1] if defined $_[1];
    return $_[0]->{'_value'};
}

sub fk_table {
    $_[0]->{'_fk_table'} = $_[1] if defined $_[1];
    return $_[0]->{'_fk_table'};
}

sub values {
    wantarray && return @{ $_[0]->{_values} };
    return $_[0]->{_values};
}
##############################################################################

# read/write:
sub encoded {
    $_[0]->{'_encoded'} = $_[1] if defined $_[1];
    return $_[0]->{'_encoded'};
}

sub decoded {
    $_[0]->{'_decoded'} = $_[1] if defined $_[1];
    return $_[0]->{'_decoded'};
}

# sub check_level {
#     $_[0]->{'_check_level'} = $_[1] if $_[1];
#     return $_[0]->{'_check_level'};
# }

sub action { $_[0]->{'_action'} = $_[1] if $_[1]; return $_[0]->{'_action'}; }

sub triggeraction {
    $_[0]->{'_triggeraction'} = $_[1] if $_[1];
    return $_[0]->{'_triggeraction'};
}

sub expect_rows {
    $_[0]->{'_expect_rows'} = $_[1] if $_[1];
    return $_[0]->{'_expect_rows'};
}

# array:
sub expect_columns {
    my ( $self, @values ) = @_;
    if (@values) {
        if ( ref( $values[0] eq 'ARRAY' ) ) {
            $self->{'_expect_columns'} = $values[0];
        }
        else {
            $self->{'_expect_columns'} = \@values;
        }
    }

    return
        if !defined $self->{'_expect_columns'}
        or $self->{'_expect_columns'} eq '';

    wantarray && return @{ $self->{'_expect_columns'} };
    return $self->{'_expect_columns'};
}

# read only:
sub tablename       { return $_[0]->{'_tablename'} }
sub type            { return $_[0]->{'_type'} }
sub struct_type     { return $_[0]->{'_struct_type'} }
sub pk_ref_col      { return $_[0]->{'_pk_ref_col'} }
sub max_check_level { return $_[0]->{'_max_check_level'} }

# arrays:
sub sequences {
    if ( ref( $_[0]->{'_sequences'} ) eq 'ARRAY' ) {
        wantarray && return @{ $_[0]->{'_sequences'} };
    }
    return $_[0]->{'_sequences'};
}

sub indexes {
    if ( ref( $_[0]->{'_indexes'})  eq 'ARRAY' ) {
        wantarray && return @{ $_[0]->{'_indexes'} };
    }
    return $_[0]->{'indexes'};
}

sub pk_ext_cols {
    if ( ref( $_[0]->{'_pk_ext_cols'} ) eq 'ARRAY' ) {
        wantarray && return @{ $_[0]->{'_pk_ext_cols'} };
    }
    return $_[0]->{'pk_ext_cols'};
}

sub preinsert_triggers {
    if (    ref( $_[0]->{'_preinsert_triggers'} )
        and ref( $_[0]->{'_preinsert_triggers'} ) eq 'ARRAY' )
    {
        wantarray && return @{ $_[0]->{'_preinsert_triggers'} };
    }
    return $_[0]->{'_preinsert_triggers'};
}

sub postinsert_triggers {
    if (    ref( $_[0]->{'_postinsert_triggers'} )
        and ref( $_[0]->{'_postinsert_triggers'} ) eq 'ARRAY' )
    {
        wantarray && return @{ $_[0]->{'_postinsert_triggers'} };
    }
    return $_[0]->{'_postinsert_triggers'};
}

sub preupdate_triggers {
    if (    ref( $_[0]->{'_preupdate_triggers'} )
        and ref( $_[0]->{'_preupdate_triggers'} ) eq 'ARRAY' )
    {
        wantarray && return @{ $_[0]->{'_preupdate_triggers'} };
    }
    return $_[0]->{'_preupdate_triggers'};
}

sub postupdate_triggers {
    if (    ref( $_[0]->{'_postupdate_triggers'} )
        and ref( $_[0]->{'_postupdate_triggers'} ) eq 'ARRAY' )
    {
        wantarray && return @{ $_[0]->{'_postupdate_triggers'} };
    }
    return $_[0]->{'_postupdate_triggers'};
}

sub predelete_triggers {
    if (    ref( $_[0]->{'_predelete_triggers'} )
        and ref( $_[0]->{'_predelete_triggers'} ) eq 'ARRAY' )
    {
        wantarray && return @{ $_[0]->{'_predelete_triggers'} };
    }
    return $_[0]->{'_predelete_triggers'};
}

sub postdelete_triggers {
    if (    ref( $_[0]->{'_postdelete_triggers'} )
        and ref( $_[0]->{'_postdelete_triggers'} ) eq 'ARRAY' )
    {
        wantarray && return @{ $_[0]->{'_postdelete_triggers'} };
    }
    return $_[0]->{'_postdelete_triggers'};
}
##############################################################################

# encode all _extdata in this record to _intdata:
sub encode_record {
    my $self = shift;
    my $debug = $apiis->debug;
    if ( $self->encoded ) {
        if ($debug) {
            $apiis->log( 'debug',
                '==> encode_record: record already encoded.' );
        }
    }
    else {
        for my $thiscol ( $self->columns ) {
            # we better check for encoded-status on column level as this
            # usually is cheaper than accesses to the database for encoding:
            if ( $self->column($thiscol)->encoded ) {
                if ($debug) {
                    $apiis->log( 'debug', sprintf
                        'encode_record: --> column %s already encoded.',
                        $thiscol
                    );
                }
            }
            else {
                $self->encode_column($thiscol);
            }
        }
        if ( !$self->status ) {
            $self->encoded(1);
            $self->decoded(1);  # implied
            if ($debug) {
                $apiis->log( 'debug',
                    'encode_record: ==> record successfully encoded.' );
            }
        }
    }
}
##############################################################################

# decode all _intdata in this record to _extdata:
sub decode_record {
    my $self = shift;
    my $debug = $apiis->debug;
    if ( $self->decoded ) {
        $apiis->log( 'debug', 'decode_record: ==> record already decoded.' )
            if $debug;
        return;
    }
    if ($debug) {
        $apiis->log( 'debug', sprintf "decode_record: ==> starting record:\n%s",
            join( "\n", @{ $self->print( { all => 1, sprintf => 1 } ) } )
        );
    }

    my $has_id_set = 1 if $apiis->Compat->get('id_set');

    # is this intdata already cached?:
    my $has_cache = 1 if $apiis->Cache->hasMemcached();
    my ( $mem_cache, $db_name, $thistable );
    CACHE: {
        last CACHE if !$has_cache;
        $mem_cache = $apiis->Cache->memcache();
        $db_name   = $apiis->Model->db_name;
        $thistable = $self->tablename;
    }

    # special handling of some datatypes:
    my %datatype_of = (
        time      => 1,
        date      => 1,
        timestamp => 1,
    );

    # loop thru the columns:
    DECODE_COL:
    for my $thiscolumn ( $self->columns ) {
        my $col_obj = $self->column($thiscolumn);
        weaken($col_obj);
        next DECODE_COL if $col_obj->decoded;
        my $intdata = $col_obj->intdata;
        if ( !defined $intdata or $intdata eq '' ) {
            $col_obj->extdata(undef);
            $col_obj->decoded(1);
            next DECODE_COL;
        }
        my $datatype = $col_obj->datatype;

        # don't decode blobs!
        if ( lc $datatype eq 'blob' ) {
            if ($debug) {
                $apiis->log( 'debug', sprintf
                    "decode_record: %s.%s: skipped decoding of datatype 'blob'",
                    $thistable, $thiscolumn
                );
            }
            next DECODE_COL;
        }

        if ($has_cache) {
            $intdata =~ tr/ /_/;    # change blank to underscore
            my @memkeys =
                ( 'decode', $db_name, $thistable, $thiscolumn, $intdata );

            # id_set:
            if ($has_id_set) {
                # add the first id_set definition to the $mem_key:
                my $id_set_ref = scalar $col_obj->id_set if $has_id_set;
                push @memkeys, $id_set_ref->[0] if $id_set_ref;
            }

            # date/time:
            if ( exists $datatype_of{ lc $datatype } ) {
                my $dateorder = $apiis->date_order;
                my $timeorder = $apiis->time_order;
                push @memkeys, $dateorder . '_' . $timeorder;
            }

            my $mem_key = join( '::', @memkeys );
            my $extdata_ref = $mem_cache->get($mem_key);
            if ($extdata_ref) {
                $col_obj->extdata($extdata_ref);
                $col_obj->decoded(1);
                if ($debug) {
                    $apiis->log( 'debug', sprintf
                        "decode_record: %s.%s ==> found '%s -> %s' in cache",
                        $thistable, $thiscolumn,
                        $mem_key, join( q{,}, @$extdata_ref )
                    );
                }
                next DECODE_COL;
            }
        }
        # try it the hard way:
        $self->decode_column( { column => $thiscolumn, cache_tried => 1, } );
    }
    if ( !$self->status ) {
        $self->decoded(1);
        $self->encoded(1); # implied
        if ($debug) {
            $apiis->log( 'debug',
                'decode_record: ==> record successfully decoded.' );
        }
    }
}
##############################################################################
# mirroring data within the record:

sub mirror_differs {
    my $a;
    for ( $_[0]->columns ){
        return 1 if $_[0]->column($_)->m_diff;
    }
    return;
}

# mirror complete record:
sub mirror_record {
    $_[0]->mirror_intdata;
    $_[0]->mirror_extdata;
    $_[0]->mirrored(1);
}

# flag if record is mirrored:
sub mirrored {
    $_[0]->{_mirrored} = $_[1] if defined $_[1];
    return $_[0]->{_mirrored};
}

# mirror intdata:
sub mirror_intdata {
    my $self = shift;
    $self->column($_)->mirror_intdata for $self->columns;
}

# mirror extdata:
sub mirror_extdata {
    my $self = shift;
    $self->column($_)->mirror_extdata for $self->columns;
}
##############################################################################

sub auth {
    my $self = shift;

    # old auth scheme for compatibility (removed later):
    if ( lc $apiis->access_rights eq 'auth' ) {
        $self->Apiis::Auth::Auth::_auth(@_);
    }

    # new access rights setup:
    if ( lc $apiis->access_rights eq 'ar' ) {
        my $ar_obj = $apiis->Auth;
        # misnamed, has nothing to do with sql:
        $ar_obj->check_sql_statement($self);
        if ( $ar_obj->status ) {
            $self->status(1);
            $self->errors( scalar $ar_obj->errors );
            $ar_obj->del_errors;
            $ar_obj->status(0);
        }
    }
    return;
}
##############################################################################

=head2 print

B<print> prints out the defined column values of the Record object, both
internal and external values and the associated ext_fields.

Example:

   $record_obj->print;

There are some switches to control the behaviour of B<print>:

   quiet => 1         # if set to 1, informational output is reduced
   columns => \@cols  # prints out only the defined columns
   m_int   => 1       # displays also mirrored internal data
   m_ext   => 1       # displays also mirrored external data
   id_set  => 1       # displays also the id_set definition of the column
   all     => 1       # includes m_int, m_ext, id_set
   sprintf => 1       # doesn't print to STDOUT but returns an arrayref to the
                      output lines

Example:

   $record_obj->print(
       {   quiet   => 1,
           columns => [qw/ db_animal guid /],
           m_int   => 1,
           id_set  => 1,
       }
   );

   $record_obj->print(
       {   quiet   => 1,
           columns => [qw/ db_animal guid /],
           all     => 1,
       }
   );

   my $output_ref = $record_obj->print( { sprintf => 1 } );
   print join("\n", @$output_ref);

The parameters have to be passed as a hash reference, the columns as an array
reference.

=cut

sub print {
    my ( $self, $args_ref ) = @_;
    my $add_m_int      = 1 if $args_ref->{m_int};
    my $add_m_ext      = 1 if $args_ref->{m_ext};
    my $id_set         = 1 if $args_ref->{id_set};
    my $quiet          = 1 if $args_ref->{quiet};
    my $sprintf        = 1 if $args_ref->{sprintf};
    my $use_entry_view = 1 if $args_ref->{use_entry_view};
    my @output;

    if ( $args_ref->{all} ) {
        $add_m_int      = 1;
        $add_m_ext      = 1;
        $id_set         = 1;
        $use_entry_view = 1;
    }

    # what columns to display:
    my @columns;
    my @all_columns = $self->columns;
    if ( $args_ref->{columns} ) {
        COL:
        for my $col ( @{ $args_ref->{columns} } ) {
            if ( !first { $_ eq $col } @all_columns ) {
                push @output,
                    sprintf "Column %s doesn't exist in table %s. Skipped",
                    $col, $self->tablename;
                next COL;
            }
            push @columns, $col;
        }
    }
    else {
        @columns = @all_columns;
    }

    push @output, sprintf "##### Table: %s", $self->tablename if !$quiet;
    foreach my $thiscolumn ( @columns ) {
        my ( @lines, @additions );
        push @additions, 'updated' if $self->column($thiscolumn)->updated;

        # extdata:
        my $extdata_ref = $self->column($thiscolumn)->extdata;
        if ($extdata_ref) {
            # the array @{$self->column($thiscolumn)->extdata} can have an
            # element with the undef value (to update a database column to
            # NULL), so switch warnings about undefined values off:
            no warnings;
            push @additions, 'decoded' if $self->column($thiscolumn)->decoded;
            my $extdata = q{['} . join( q{','}, @$extdata_ref ) . q{']};
            my $adds = '';
            if (@additions) {
                $adds = q{ (} . join( q{,}, @additions ) . q{)};
            }
            push @lines, "\t(ext): $extdata\t$adds";
        }

        # mirrored ext_data:
        if ($add_m_ext) {
            my $m_extdata_ref = $self->column($thiscolumn)->m_extdata;
            if ($m_extdata_ref) {
                no warnings;
                my $m_extdata = q{['} . join( q{','}, @$m_extdata_ref ) . q{']};
                push @lines, "\t(m_ext): " . $m_extdata;
            }
        }

        # intdata:
        if ( defined $self->column($thiscolumn)->intdata ) {
            my @i_additions;
            push @i_additions, 'encoded' if $self->column($thiscolumn)->encoded;
            my $adds = '';
            if (@i_additions) {
                $adds = q{ (} . join( q{,}, @i_additions ) . q{)};
            }
            push @lines, sprintf "\t(int): %s\t%s",
                $self->column($thiscolumn)->intdata, $adds;
        }

        # mirrored int_data:
        if ($add_m_int){
            if ( defined $self->column($thiscolumn)->m_intdata ) {
                push @lines, sprintf "\t(m_int): %s",
                    $self->column($thiscolumn)->m_intdata;
            }
        }

        # ext_fields:
        if ( defined $self->column($thiscolumn)->ext_fields ) {
            push @lines, "\t(ext_fields): "
                . join( ', ', $self->column($thiscolumn)->ext_fields );
        }

        # id_set:
        if ( $id_set ){
            my $id_set_ref = $self->column($thiscolumn)->id_set;
            if ( $id_set_ref and scalar @$id_set_ref) {
                no warnings;
                my $id_set_data = q{['} . join( q{','}, @$id_set_ref ) . q{']};
                my $line = "\t(IdSet): " . $id_set_data;
                my $best = $self->column($thiscolumn)->best_id_set;
                $line .= " (best: $best)" if $best;
                push @lines, $line;
            }
        }

        # do we have output anyway?:
        if (@lines) {
            my $add;

            # use_entry_view:
            my $use_entry_view = $self->column($thiscolumn)->use_entry_view;
            if ( $use_entry_view ) {
                $add = "\t(use_entry_view = $use_entry_view): ";
            }
            else {
                $add = ':';
            }
            push @output, $thiscolumn . $add;
            push @output, @lines;
        }
    }
    push @output, sprintf "%s\n", '#' x 50 if !$quiet;
    $sprintf ? ( return \@output ) : ( print STDOUT join( "\n", @output ) );
}
##############################################################################

# This is a testversion of print for l10n:
sub print_loc {
    my $self = shift;
    print "##### Table: ", $self->tablename, "\n";
    foreach my $thiscolumn ( $self->columns ) {
        my @lines;
        if ( defined $self->column($thiscolumn)->extdata ) {
            # the array @{$self->column($thiscolumn)->extdata} can have an
            # element with the undef value (to update a database column to
            # NULL), so switch warnings about undefined values off:
            no warnings;
            if ( $self->column($thiscolumn)->datatype eq 'CHAR' ) {
                push @lines, "\t(ext): "
                    . join( ' ', __( $self->column($thiscolumn)->extdata ) );
            }
            else {
                push @lines, "\t(ext): "
                    . join( ' ', $self->column($thiscolumn)->extdata );
            }
        }
        if ( defined $self->column($thiscolumn)->intdata ) {
            push @lines, "\t(int): " . $self->column($thiscolumn)->intdata;
        }
        print "$thiscolumn:\n", join( "\n", @lines ), "\n" if @lines;
    }
    print '#' x 50, "\n";
}
##############################################################################
# only passing over to internal subs:
sub insert        { &Apiis::DataBase::Record::Insert::_insert; }
sub update        { &Apiis::DataBase::Record::Update::_update; }
sub delete        { &Apiis::DataBase::Record::Delete::_delete; }
sub fetch         { &Apiis::DataBase::Record::Fetch::_fetch; }
sub modify_record { &Apiis::DataBase::Record::Modify::_modify_record; }
sub check_record  { &Apiis::DataBase::Record::Check::_check_record; }
sub encode_column { &Apiis::DataBase::Record::Encode::_encode_column; }
sub resolve_fk    { &Apiis::DataBase::Record::Encode::_resolve_fk; }
sub resolve_pk    { &Apiis::DataBase::Record::Encode::_resolve_pk; }
sub decode_column { &Apiis::DataBase::Record::Decode::_decode_column; }
# sub decode_column { $_[0]->_decode_column( column => $_[1] ); }
sub RunTrigger    { &Apiis::DataBase::Record::Trigger::_run_trigger; }
# pass get/set queries to check_level to the Model method:
sub check_level { $apiis->Model->check_level( $_[1] ); }
##############################################################################

1;
