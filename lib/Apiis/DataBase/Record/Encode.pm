##############################################################################
# $Id: Encode.pm,v 1.24 2014/12/13 17:56:51 ulm Exp $
# encode columns
##############################################################################
package Apiis::DataBase::Record::Encode;
$VERSION = '$Revision: 1.24 $';
##############################################################################

=head1 NAME

Encode.pm

=head1 SYNOPSIS

   $record_obj->encode_column( $column );

=head1 DESCRIPTION

Apiis::DataBase::Record::Encode contains the internal routine B<_encode_column>
for encoding on column level. It does the work of the public method:

   $record_obj->encode_column( $column );

Usually, even this public method is not invoked directly but via

   $record_obj->encode_record;

These builds a loop around all columns and runs the column-level method.

B<encode_column> is a record (not column) methods as encoding (at least
partially) is based on information available only on record level (i.e.
primary key definitions).

=cut

use strict;
use warnings;
use Carp qw( longmess );
use Data::Dumper;
use Scalar::Util qw( weaken );
use List::Util qw(first);

use Apiis::Init;
our $apiis;   # doesn't this sound familiar? Our dear $apiis! :^)
our $debug;

my %datatype_of = (
    time      => sub { return scalar $_[0]->exttime2iso( $_[1] ); },
    date      => sub { return scalar $_[0]->extdate2iso( $_[1] ); },
    timestamp => sub { return scalar $_[0]->extdate2iso( $_[1] ); },
);

=head2 _encode_column() (internal)

B<_encode_column> encodes the external value(s) to the internal database
code, if any. Otherwise it just copies the external data to intdata.

B<_encode_column> resolves the dependencies of an encoded value in accordance
to the model file. This is based on the model file entries of

   CHECK => 'ForeignKey ...'

on column level and the PRIMARYKEY definitions on record level.
This is done recursively.

First the ForeignKey (FK) on column level is checked. This points to another
table.column which is also checked against defined ForeignKeys. At the end
of this FK-chain it is checked, if this column is the reference column
(pk_ref_col) of a PRIMARYKEY (PK).

If there is a PK and this PK is a concatenated one, the concatenation
columns (pk_concat_cols) are again checked for FK constraints and resolved.

At the end of the chain, the resulting leaf columns are filled with the
external data and a query retrieves the desired database code.

The order of the columns is determined by the order, in which they appear
in the recursion tree and by the order of the pk_concat_cols. The external
data has to keep this order!

The where condition of the primary key (where closing_dt is null) is
solved by accessing the views entry_transfer/entry_unit.

Input parameters:

   $record_obj->_encode_column(
      # name of the column to encode (required):
      column           => $this_column,
      # additional entries of the ForeignKey rule like 'class=SEX' (optional):
      where_conditions => \@this_fk_where,
      # the recursion level can be passed for writing nice indented logs (optional):
      recursion_level  => $recursion_level + 1,

   );

Output parameters:
   
   None. The encoded value is directly written into

      $record_obj->column( $thiscolumn )->intdata

   Errors are stored in

      $record_obj->errors

   and the $record_obj->status flag is set in case of errors.

=cut

sub _encode_column {
    my ( $self, $args_ref ) = @_;

    $debug = 1
        if $apiis->syslog_priority  eq 'debug'
        or $apiis->filelog_priority eq 'debug';

    # arguments:
    my ( $thiscolumn, $where_cond_ref, @where_conditions );
    my $recursion_level = 0;
    if ( ref $args_ref eq 'HASH' ) {
        $thiscolumn       = $args_ref->{'column'};
        $where_cond_ref   = $args_ref->{'where_conditions'};
        @where_conditions = @{$where_cond_ref} if $where_cond_ref;
        $recursion_level  = $args_ref->{'recursion_level'} || 0;
    }
    else {
        $thiscolumn      = $args_ref;    # simple scalar passed
    }

    my $thistable        = $self->tablename;
    my ( $thisdatatype, $col_obj );

    # make nice logs
    # my $log_prefix = 'encode_column:' . ' ' x ( $recursion_level * 3 );
    my $log_prefix = '> ' x ( $recursion_level ) . 'encode_column: ';

    if ($debug) {
        $apiis->log( 'debug',
            "$log_prefix starting for column '$thistable.$thiscolumn'." );
    }

    ENCODE: {
        if ( !defined $thiscolumn ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    backtrace => longmess(),
                    from      => '_encode_column',
                    msg_short => __( "Parameter missing: [_1]", 'column name' ),
                )
            );
            $self->status(1);
            last ENCODE;
        }
        $col_obj = $self->column($thiscolumn);
        weaken($col_obj);

        # Note: encode_column could be called directly (e.g. from ForeignKey.pm)
        if ( $col_obj->encoded ) {
            if ($debug) {
                $apiis->log( 'debug', sprintf '%s column %s already encoded',
                    $log_prefix, $thiscolumn );
            }
            last ENCODE;
        }

        # We must check, if extdata is defined. Even if it is undefined it
        # will create an (undef) element in @ext_data otherwise.
        my $extdata_ref = $col_obj->extdata;
        my @ext_data = @$extdata_ref if $extdata_ref;

        # Treat rowid/guid separately. Extdata could be empty but intdata
        # contains the guid from a query:
        my $rowid_name = $apiis->DataBase->rowid;
        if ( $thiscolumn eq $rowid_name ) {
            my $int     = $col_obj->intdata;
            my $ext     = $extdata_ref->[0] if $extdata_ref;
            if ( defined $int ) {
                $col_obj->extdata($int);
                $col_obj->encoded(1);
                $col_obj->decoded(1);
            }
            else {
                $col_obj->intdata($ext);
                $col_obj->encoded(1);
                $col_obj->decoded(1);
            }
            last ENCODE;
        }

        if ( not scalar @ext_data ) {
            $col_obj->intdata(undef);
            $col_obj->encoded(1);
            $col_obj->decoded(1); # decoded() is reset to 0 by assigning intdata
            if ($debug) {
                $apiis->log( 'debug', sprintf
                    '%s no extdata in column %s, setting intdata to undef',
                    $log_prefix, $thiscolumn );
            }
            last ENCODE;
        }

        # If we only have one entry in @ext_data and this entry is undef we
        # set intdata explicitely to undef, which will result in NULL when
        # building the query in an update operation:
        if ( scalar @ext_data == 1 ) {
            if ( defined $ext_data[0] and $ext_data[0] eq '' ) {
                $ext_data[0] = undef;
            }

            if ( !defined $ext_data[0] ) {
                $col_obj->intdata(undef);
                $col_obj->encoded(1);
                $col_obj->decoded(1);
                if ($debug) {
                    $apiis->log( 'debug', sprintf
                        "%s extdata has one undef element, resetting %s.%s to NULL",
                        $log_prefix, $thistable, $thiscolumn
                    );
                }
                last ENCODE;
            }
        }

        # retrieve for later use:
        $thisdatatype = $col_obj->datatype;

        # handling Foreign Key:
        if ( $col_obj->foreignkey ) {
            if ($debug) {
                my $txt = sprintf "%s found foreign key definition for '%s.%s'",
                    $log_prefix, $thistable, $thiscolumn;
                $apiis->log( 'debug', $txt );
            }

            my %resolve_args = ( column => $thiscolumn );
            $self->resolve_fk( \%resolve_args );
            last ENCODE;
        }    # end foreign key

        # as we use the model table definition several times:
        my $model_table_obj = $apiis->Model->table($thistable);
        weaken( $model_table_obj ); # don't increment reference counts

        # no foreign key defined, but do we have a primary key definition?:
        my $pk_ref_col = $model_table_obj->primarykey('ref_col');
        if ($pk_ref_col) {
            if ($debug) {
                my $txt = sprintf "%s found primary key definition for '%s.%s'",
                    $log_prefix, $thistable, $pk_ref_col;
                $apiis->log( 'debug', $txt );
            }
            my %resolve_args = ( column => $thiscolumn );
            $resolve_args{'where_conditions'} = $where_cond_ref;
            $resolve_args{'recursion_level'} = $recursion_level + 1;
            if ($debug) {
                my $txt = sprintf "%s starting resolve_pk (%s)",
                    $log_prefix, Dumper(\%resolve_args);
                $apiis->log( 'debug', $txt );
            }
            $self->resolve_pk( \%resolve_args );
            if ($debug) {
                my $txt = sprintf "%s returned from resolve_pk (%s.%s)",
                    $log_prefix, $thistable, $pk_ref_col;
                $apiis->log( 'debug', $txt );
            }
        }
        else {
            # No FK, no PK. Just copy the external data to internal:
            $col_obj->intdata( $ext_data[0] );
            $col_obj->encoded(1);
            $col_obj->decoded(1);
            if ($debug) {
                $apiis->log( 'debug',
                    "$log_prefix Encoding/copying from a non-PK/non-FK column"
                );
            }
        }

        if ($debug) {
            my @e_data = $col_obj->extdata;
            @e_data = map { defined $_ ? $_ : 'undef' } @e_data;
            $apiis->log(
                'debug',
                sprintf "%s encoding done for column '%s.%s' [%s '=>' %s]",
                $log_prefix, $thistable, $thiscolumn,
                join( ',', @e_data ), ( $col_obj->intdata || 'NULL' )
            );
        }
    }   # end label ENCODE

    # convert to internal date:
    if ( $thisdatatype and ( exists $datatype_of{ lc $thisdatatype } )) {
        my $intdata  = $col_obj->intdata;
        if ($intdata) {
            my $code_ref = $datatype_of{ lc $thisdatatype };
            $col_obj->intdata( $self->$code_ref( $intdata ) );
            # $col_obj->intdata( $code_ref->( ref $self, $intdata ) );
            if ( $self->status ) {
                # qualify errors more detailed if from date/time routines:
                # (Error objects could also come from earlier errors.)
                my $is_from = {
                    extdate2iso => 1,
                    exttime2iso => 1,
                };
                ERR:
                for my $err ( $self->errors ) {
                    my $from = $err->from();
                    next ERR if !exists $is_from->{$from};
                    $err->db_table($thistable) if !$err->db_table();
                    $err->db_column($thiscolumn) if !$err->db_column();
                    my $ef_ref;
                    if ( $ef_ref = $self->column($thiscolumn)->ext_fields ) {
                        $err->ext_fields($ef_ref) if !$err->ext_fields();
                    }
                }
            }
            else {
                $col_obj->decoded(1);
                if ($debug) {
                    $apiis->log( 'debug',
                        sprintf "%s Date/Time converted for %s.%s (%s=>%s)",
                        $log_prefix, $thistable, $thiscolumn, $intdata,
                        $col_obj->intdata
                    );
                }
            }
        }
    }

    # Handle errors differently for queries:
    # This is a workaround to allow queries, where the extdata-array is
    # filled only partially. Currently this could not be encoded. To make such
    # queries work, the errors and the complete extdata-array are deleted and
    # the $self->status is reset to 0. This could result in a larger set of
    # returned records as expected. Final solution would be to honour the
    # partial values, which is not quite easy to implement.
    # Another problem: former errors (and status) are also deleted.
    # (15.5.2006 - heli):
    # Removed this feature as it prevents to stop execution in case of errors
    # (Fetching an item that does not exist, based on wrong partial input,
    # e.g. fetching a db_animal with wrong db_unit).
    # (22.10.2008 - heli):
    # if ( lc $self->action eq 'fetch' ) {
    #     if ( $self->status ) {
    #         $self->status(0);
    #         $self->del_errors;
    #         $self->column($thiscolumn)->extdata(undef);
    #         $apiis->log( 'warning', sprintf
    #             "%s Erased non-encodable extdata-array for column %s in fetch-workaround",
    #             $log_prefix, $thiscolumn
    #         );
    #     }
    # }

    if ($debug) {
        $apiis->log( 'debug',
            "$log_prefix finished for column '$thistable.$thiscolumn'." );
    }
    return;
}

=head2 _no_of_extdata_entries() (internal)

This internal subroutine counts the number of elements of the
extdata-array, that will build the intdata entry for one column.
This is not necessarily 1, as the encoding can include some concatenated
primary keys. 

Input:

   hash reference with keys 'table' and 'column', for which I want to have the
   number of extdata entries

Output:

   number of extdata entries
   missing: error handling, so write clean code! ;^)

Note:

   call this subroutine directly, not as an object method!

=cut

sub _no_of_extdata_entries {
    my $args_ref = shift;
    my $table  = $args_ref->{'table'};
    my $column = $args_ref->{'column'};

    die "Pfui! Programming error!!!\n" if !defined $table or !defined $column;

    my $no_of_data_entries = 0;
    LOOP: {
        # Ugly hardcoded special treatment for table codes. Column class is
        # handled by the where clause, build from the model file:
        last LOOP if $table eq $apiis->codes_table and $column eq 'class';

        # we have a foreign key:
        my ( $fk_table, $fk_column ) =
            $apiis->Model->table($table)->foreignkey($column);
        if ( $fk_table and $fk_column ) {
            # recursion:
            $no_of_data_entries += _no_of_extdata_entries(
                {   table  => $fk_table,
                    column => $fk_column
                }
            );
            last LOOP;
        }

        # no foreign key, but a primary key
        my $pk_ref_col = $apiis->Model->table($table)->primarykey('ref_col');
        if ($pk_ref_col) {
            if ( defined $pk_ref_col and $pk_ref_col eq $column ) {
                # is it a concatenated primary key?:
                my @pk_concat_cols =
                    $apiis->Model->table($table)->primarykey('ext_cols');
                if (@pk_concat_cols) {
                    for my $this_pk_concat_col (@pk_concat_cols) {
                        # recursion:
                        $no_of_data_entries += _no_of_extdata_entries(
                            {   table  => $table,
                                column => $this_pk_concat_col,
                            }
                        );
                    }
                }
                else {
                    $no_of_data_entries = 1;
                }
            }
            else {
                $no_of_data_entries = 1;
            }
            last LOOP;
        }
        # no FK, no PK, just one entry:
        $no_of_data_entries = 1;
    }
    return $no_of_data_entries;
}
##############################################################################
# resolve_fk
sub _resolve_fk {
    my ( $self, $args_ref ) = @_;
    # print Dumper($args_ref);

    EXIT: {
        # first some parameter checking:
        my $thiscol = $args_ref->{column};
        if ( !$thiscol ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'resolve_fk',
                    db_table  => $self->tablename,
                    db_column => $thiscol,
                    action    => $self->action || 'unknown',
                    msg_short => __( "Parameter missing: [_1]", 'column name' ),
                )
            );
            last EXIT;
        }
        my $col_obj    = $self->column($thiscol);
        if ( !$col_obj ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'resolve_fk',
                    db_table  => $self->tablename,
                    db_column => $thiscol,
                    action    => $self->action || 'unknown',
                    msg_short =>
                        __( "Cannot get Column object: [_1]", 'column name' ),
                )
            );
            last EXIT;
        }
        weaken($col_obj);

        my ( $where_cond_ref, @where_conditions, $recursion_level );
        if ($args_ref) {
            $where_cond_ref   = $args_ref->{'where_conditions'};
            @where_conditions = @{$where_cond_ref} if $where_cond_ref;
            $recursion_level  = $args_ref->{'recursion_level'} || 0;
        }

        # a foreign key is defined
        my ( $fk_table, $fk_db_col, @fk_where ) = $col_obj->foreignkey;
        last EXIT if !$fk_table;
        last EXIT if !$fk_db_col;

        my $extdata_ref = $col_obj->extdata;
        last EXIT if !$extdata_ref;    # nothing to resolve if no data

        # new record object for the foreign key table and pass the extdata:
        my $fk_record = Apiis::DataBase::Record->new( tablename => $fk_table, );
        $fk_record->column($fk_db_col)->extdata($extdata_ref);
        # propagate flag use_entry_view:
        $fk_record->column($fk_db_col)->use_entry_view(1)
            if $col_obj->use_entry_view;

        # also pass intdata, may help later to encode (in _resolve_pk), when
        # extdata leads to several encodings:
        my $intdata = $col_obj->intdata;
        if ( defined $intdata ) {
            $fk_record->column($fk_db_col)->intdata($intdata);
        }

        # encode the column on the fk-table:
        my %fk_args = (
            column          => $fk_db_col,
            recursion_level => $recursion_level + 1,
        );
        if (@fk_where) {
            $fk_args{'where_conditions'} = \@fk_where;
        }
        $fk_record->encode_column( \%fk_args );   # recursively!

        # propagate errors down the stack:
        if ( $fk_record->status ) {
            $self->status(1);
            $self->errors( scalar $fk_record->errors );
            $fk_record->del_errors;
            $fk_record->status(0);
            last EXIT;
        }

        # propagate the encoded value downwards:
        my $fk_intdata = $fk_record->column($fk_db_col)->intdata;
        if ( defined $fk_intdata ) {
            $col_obj->intdata($fk_intdata);
            $col_obj->encoded(1);
            $col_obj->decoded(1);
            last EXIT;
        }

        # FK-definition could not be resolved (violation of rule). Instead
        # of only dropping a warning (like before) we now raise an error.
        # Without correct coding, the record handling in forms does not
        # work properly.
        $self->status(1);
        $col_obj->intdata(undef);
        my @print_arr = @$extdata_ref;
        @print_arr = map { defined $_ ? $_ : 'undef' } @print_arr;
        my $err_id = $self->errors(
            Apiis::Errors->new(
                type      => 'DATA',
                severity  => 'ERR',
                from      => '_encode_column',
                db_table  => $self->tablename,
                db_column => $col_obj->name,
                action    => $self->action || 'unknown',
                data      => join( ',', @print_arr ),
                msg_short => __("Found Foreign Key violation"),
            )
        );
        # add some error fields which might not exist:
        if ( my $e_fields_ref = $col_obj->ext_fields ) {
            $self->error($err_id)->ext_fields($e_fields_ref);
        }
        if ( my $rid = $self->column( $apiis->DataBase->rowid )->intdata ) {
            $self->error($err_id)->record_id($rid);
        }
    }    # end label EXIT
    return;
}
##############################################################################
# resolve_pk
sub _resolve_pk {
    my ( $self, $args_ref ) = @_;
    # die Dumper($args_ref);

    my ( $intdata, $col_obj );
    EXIT: {
        # first some parameter checking:
        my $thiscol = $args_ref->{column};
        if ( !$thiscol ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'resolve_pk',
                    db_table  => $self->tablename,
                    db_column => $thiscol,
                    action    => $self->action || 'unknown',
                    msg_short => __( "Parameter missing: [_1]", 'column name' ),
                )
            );
            last EXIT;
        }
        $col_obj = $self->column($thiscol);
        if ( !$col_obj ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'resolve_pk',
                    db_table  => $self->tablename,
                    db_column => $thiscol,
                    action    => $self->action || 'unknown',
                    msg_short =>
                        __( "Cannot get Column object: [_1]", 'column name' ),
                )
            );
            last EXIT;
        }
        weaken($col_obj);

        # passed parameters via $args_ref:
        my $recursion_level = $args_ref->{'recursion_level'} || 0;
        # my $log_prefix = 'resolve_pk:' . ' ' x ( $recursion_level * 3 );
        my $log_prefix = '> ' x ( $recursion_level ) . 'resolve_pk: ';
        my $where_cond_ref   = $args_ref->{'where_conditions'};
        my @where_conditions = @{$where_cond_ref} if $where_cond_ref;

        # get the table object of the Model:
        my $thistable = $self->tablename;
        my $model_table_obj = $apiis->Model->table($thistable);
        weaken($model_table_obj);    # don't increment reference counts
        my $pk_ref_col = $model_table_obj->primarykey('ref_col');
        last EXIT if !$pk_ref_col;

        # does the PK refer to the currently handled column?:
        my $extdata_ref = $col_obj->extdata;
        if ( $pk_ref_col ne $thiscol ) {
            # PK does not touch this column, so accept data:
            $intdata = $extdata_ref->[0];
            if ($debug) {
                $apiis->log( 'debug',
                    "$log_prefix Encoding/Copying from a non-PrimaryKey column"
                );
            }
            last EXIT;
        }

        if ($debug) {
            my $txt =
                sprintf "%s found primary key definition for column '%s.%s'.",
                $log_prefix, $thistable, $thiscol;
            $apiis->log( 'debug', $txt );
        }

        # is it a concatenated primary key?:
        my @pk_concat_cols = $model_table_obj->primarykey('ext_cols');
        if (@pk_concat_cols) {
            if ($debug) {
                $apiis->log( 'debug',
                    "$log_prefix ... even a concatenated one ;^)" );
            }

            my %this_ext_col_data;
            my @extdata = @$extdata_ref; # make a copy to allow shift later!
            foreach my $ext_col (@pk_concat_cols) {
                # has this column also a foreign key relation?:
                my $fk_ref = $model_table_obj->foreignkey($ext_col);
                if ($fk_ref) {
                    my ( $fk_table, $fk_db_col, @fk_where ) = @$fk_ref;
                    if ($debug) {
                        my $txt = sprintf
                            "%s primary key has a foreign key to %s.%s",
                            $log_prefix, $fk_table, $fk_db_col;
                        if (@fk_where) {
                            $txt .= ' with ' . join( q{,}, @fk_where );
                        }
                        $apiis->log( 'debug', $txt );
                    }

                    # First we have to count, how many elements of the
                    # extdata-array belong to this ext_col. This could
                    # only be more than one if this ext_col has a
                    # foreign key relation to another concatenated
                    # primary key.
                    # First consult the cache:
                    my $namespace = 'encode_no_of_entries';
                    my $c_key              = "${thistable}.${ext_col}";
                    my $no_of_data_entries =
                        $apiis->Cache->GetCache( $namespace, $c_key );
                    
                    if ( !defined $no_of_data_entries ) {
                        # do it the hard way ...
                        $no_of_data_entries = _no_of_extdata_entries(
                            {   table  => $thistable,
                                column => $ext_col,
                            }
                        );
                        # ... but store it in cache for later use:
                        $apiis->Cache->SetCache( $namespace, $c_key,
                            $no_of_data_entries );
                    }

                    # now handle this extdata-part(s):
                    my @thisdata;
                    for ( my $i = 0; $i < $no_of_data_entries; $i++ ) {
                        push @thisdata, shift @extdata;
                    }

                    my $pk_record =
                        Apiis::DataBase::Record->new(
                        tablename => $fk_table );

                    $pk_record->column($fk_db_col)->extdata(@thisdata);
                    # propagate flag use_entry_view:
                    $pk_record->column($fk_db_col)->use_entry_view(1)
                        if $col_obj->use_entry_view;

                    # encode the column on the pk-table:
                    my %pk_args = (
                        column          => $fk_db_col,
                    );
                    if (@fk_where) {
                        $pk_args{'where_conditions'} = \@fk_where;
                        $pk_args{'recursion_level'} = $recursion_level + 1;
                    }

                    if ($debug) {
                        my $txt = sprintf
                            "%s recursion into encode_column with args %s",
                            $log_prefix, Dumper( \%pk_args );
                        $apiis->log( 'debug', $txt );
                    }

                    $pk_record->encode_column( \%pk_args );
                    if ( $pk_record->status ) {
                        $self->errors( scalar $pk_record->errors );
                        $self->status(1);
                        $pk_record->del_errors;
                        $pk_record->status(0);
                        last ENCODE;
                    }

                    # propagate the encoded value downwards:
                    $this_ext_col_data{$ext_col} =
                        $pk_record->column($fk_db_col)->intdata;
                }
                else {
                    # no foreign key:

                    # kein FK, keine where clause, oder???  falsch: hier geht
                    # es um eine where clause für den PK!  Aber brauchen wir
                    # das hier???

                    if ($where_cond_ref) {
                        foreach (@where_conditions) {
                            /([^\s]+)=([^\s]+)/;
                            if ( defined $1 and $ext_col eq $1 ) {
                                $this_ext_col_data{$ext_col} = $2;
                                if ($debug) {
                                    $apiis->log( 'debug',
                                        sprintf "%s FK where clause: %s = %s",
                                        $log_prefix, $1, $2 );
                                }
                            }
                            else {
                                $this_ext_col_data{$ext_col} =
                                    shift @extdata;
                            }
                        }
                    }
                    else {
                        # here we need separate Date/Time conversion:
                        my $datatype =
                            $model_table_obj->column($ext_col)->datatype;
                        my $value = shift @extdata;
                        if ( $value and exists $datatype_of{ lc $datatype } ) {
                            my $val_tmp;
                            my $code_ref = $datatype_of{ lc $datatype };
                            $val_tmp = $self->$code_ref($value);
                            # $val_tmp = $code_ref->(ref $self, $value);
                            if ( $self->status ) {
                                for my $err ( $self->errors ) {
                                    $err->db_table($thistable);
                                    $err->db_column($ext_col);
                                    my $ef_ref =
                                        $self->column($ext_col)->ext_fields;
                                    $err->ext_fields($ef_ref) if $ef_ref;
                                    last EXIT;
                                }
                            }

                            if ($debug) {
                                $apiis->log( 'debug', sprintf
                                    "%s Date/Time converted for %s.%s (%s=>%s)",
                                    $log_prefix, $thistable, $ext_col,
                                    $value, $val_tmp
                                );
                            }
                            $value = $val_tmp;
                        }
                        $this_ext_col_data{$ext_col} = $value;
                    }
                    if ($debug) {
                        $apiis->log( 'debug', sprintf
                            '%s Value shifted for non FK column %s.%s',
                            $log_prefix, $thistable, $ext_col
                        );
                    }
                }
            }

            # now get the data and create a SQL statement:
            my @where_clause;
            for my $thiskey ( keys %this_ext_col_data ) {
                my $value = $this_ext_col_data{$thiskey};
                # PK should not have ext_cols with NULL, but Ulf demands
                # this for historic data:
                if ( !defined $value or ( $value eq '' ) ) {
                    push @where_clause, ( $thiskey . ' is NULL' );
                }
                else {
                    push @where_clause,
                        $thiskey . '=' . $apiis->DataBase->dbh->quote($value);
                }
            }

            # check for flag 'use_entry_view':
            my $querytable = $thistable;
            if ( $col_obj->use_entry_view ) {
                if ( my $view = $apiis->entry_views->{$thistable} ) {
                    $querytable = $view;
                    if ($debug) {
                        $apiis->log( 'debug',
                            sprintf "%s Using view '%s' instead of table '%s'",
                            $log_prefix, $view, $thistable );
                    }
                }
            }
            
            my $sqltext = sprintf "SELECT %s FROM %s WHERE %s", $pk_ref_col,
                $querytable, join( ' AND ', @where_clause );

            my $_sql_ref = $apiis->DataBase->sys_sql($sqltext);
            if ( $_sql_ref->status ) {
                $self->status(1);
                $self->errors( scalar $_sql_ref->errors );
            }
            else {
                my @enc_values;
                while ( my $arr_ref = $_sql_ref->handle->fetch ) {
                    push @enc_values, $arr_ref->[0];
                }
                if ( scalar @enc_values ) {
                    # do we have more than one possible encode-values?:
                    if ( scalar @enc_values > 1 ) {
                        # does old intdata exist?
                        my $tmp_intdata = $col_obj->intdata;
                        if ( defined $tmp_intdata ) {
                            # compare it:
                            if ( first { $_ eq $tmp_intdata } @enc_values ) {
                                $intdata = $tmp_intdata;
                            }
                        }
                        else {
                            # let's hope, the first is the right one:
                            $intdata = shift @enc_values;
                        }
                    }
                    else {
                        $intdata = shift @enc_values;    # take the first value
                    }
                }
            }
        }
        else {
            # no concatenated primary key, so this column contains the
            # encoded data. We simply copy the external data to the
            # internal (without checking; this is done by CHECK). As
            # there is no concatenated PK, @ext_data could only
            # contain one entry.
            $intdata = $extdata_ref->[0];
            if ($debug) {
                $apiis->log( 'debug',
                    sprintf "%s Encoded a non-concatenated PK column",
                    $log_prefix );
            }
        }
    }    # end label EXIT
    if ( !$self->status ){
        $col_obj->intdata( $intdata );
        $col_obj->encoded(1);
        $col_obj->decoded(1);
    }
}
##############################################################################

=head1 BUGS

Lots!

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

##############################################################################
1;

