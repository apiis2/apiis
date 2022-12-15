##############################################################################
# $Id: Decode.pm,v 1.22 2014/12/08 08:56:55 heli Exp $
# decode columns
##############################################################################
package Apiis::DataBase::Record::Decode;
$VERSION = '$Revision: 1.22 $';
##############################################################################

=head1 NAME

Decode.pm

=head1 SYNOPSIS

    $record_obj->decode_column($column);

    $record_obj->decode_column(
        {
            column => $column,
            cache_tried => 1,
        }
    );

=head1 DESCRIPTION

Apiis::DataBase::Record::Decode contains the internal routine B<_decode_column>
for decoding on column level. It does the work of the public method:

   $record_obj->decode_column( $column );

Usually, even this public method is not invoked directly but via

   $record_obj->decode_record;

This builds a loop around all columns and runs the column-level method.

B<decode_column> is a record (not column) methods as encoding (at least
partially) is based on information available only on record level (i.e.
primary key definitions).

The recommended inferface to B<decode_column> is the passing of the arguments
as a hash reference. The internal parameter 'cache_tried' is for coordination
between B<decode_record> and B<decode_column>. Usually B<decode_record> tries
to use the memcached (if it exists) and skips execution of B<decode_column>
for found values. If B<decode_column> is called directly, we also want to use
the cache but in the other cases, we don't want to repeat the cache search
from B<decode_record>.

Columns with id_set definitions are treated separately, as the
memcached-hashkey needs the decoded id_set as additional parameter. So we have
different decodings for one internal db_animal:

   * Herdbooknr. for db_animal 6765:
     decode::ovicap_st::animal::db_animal::6765::HB
        ->'20-herdbuchnummer,2-st05006,12195'
   * Lifetimenr. for db_animal 6765:
     decode::ovicap_st::animal::db_animal::6765::LBN
        ->'10-lebensnummer,st,8233'

=cut

use strict;
use warnings;
use List::Util qw( first );
use Scalar::Util qw( weaken );
use Carp qw( longmess );
use Data::Dumper;

use Apiis::Init;
our $apiis;

my %datatype_of = (
    time      => sub { return scalar $_[0]->iso2exttime( $_[1] ); },
    date      => sub { return scalar $_[0]->iso2extdate( $_[1] ); },
    timestamp => sub { return scalar $_[0]->iso2extdate( $_[1] ); },
);

=head2 decode_column() (internal)

B<decode_column> decodes the internal database code to the external
values. If nothing is to decode, it just copies the internal data to extdata.

B<decode_column> resolves the dependencies of an encoded value in accordance
to the model file. This is based on the model file entries of

   CHECK => 'ForeignKey ...'

on column level and the PRIMARYKEY definitions on record level.  This is done
recursively. Decoding is based on the definitions in the model file.  For
details please read the B<encode_column>-part of the documentation.

Input parameters:

Short form (deprecated):

    $record_obj->decode_column( $thiscol );

Long form (recommended):

    $record_obj->decode_column(
        column           => $col,     # name of the column to encode (required):
        where_conditions => \@w_c,    # additional entries of the ForeignKey
                                      #   rule like 'class=SEX' (optional):
        recursion_level  => $r_l + 1, # the recursion level can be passed
                                      # for nice indented logs (optional):
        cache_tried      => 1,        # for internal coordination
    );

Output parameters:
   
   None. The decoded values are directly written into

      $record_obj->column( $thiscol )->extdata

   Errors are stored in

      $record_obj->errors

   and the $record_obj->status flag is set in case of errors.

=cut

sub _decode_column {
    my ( $self, $args_ref ) = @_;

    # arguments:
    my ( $thiscol, $where_cond_ref, $datatype );
    my ( $cache_tried, $cache_found, $found_best_id_set );
    my $recursion_level = 0;
    if ( ref $args_ref eq 'HASH' ) {
        $thiscol          = $args_ref->{'column'};
        $where_cond_ref   = $args_ref->{'where_conditions'};
        $recursion_level  = $args_ref->{'recursion_level'} || 0;
        $cache_tried      = $args_ref->{'cache_tried'}     || 0;
        # $args_ref->{mode} = 'scalar' unless $args_ref->{mode};
        # It should be default with primary keys to return only one value.
        # Anyway, APIIS has special setup e.g. with several open
        # datachannels for one animal. No real primary key.
        # If you need all db_animals use mode=>'list'.
        # (Not yet used by anybody, not implemented.)
    }
    else {
        $thiscol = $args_ref;    # simple scalar passed
    }

    my $log_prefix;
    my $thistable = $self->tablename;

    my $debug = $apiis->debug;

    my ( $intdata, $col_obj );
    my ( $has_cache, $db_name, $mem_cache, $mem_key );
    my ( $has_id_set, $id_set_ref );
    DECODE: {
        if ( !defined $thiscol ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    db_table  => $thistable,
                    backtrace => longmess,
                    from      => 'decode_column',
                    msg_short => __( "Parameter missing: [_1]", 'column name' ),
                )
            );
            $self->status(1);
            last DECODE;
        }

        $log_prefix = sprintf "decode_column:%s",
            q{ } x ( $recursion_level * 3 );

        # get column data via object:
        $col_obj = $self->column($thiscol);
        weaken($col_obj);

        # get datatype early. It's used later even if we leave DECODE now:
        $datatype = $col_obj->datatype;

        # don't do work twice.
        last DECODE if $col_obj->decoded;

        $intdata = $col_obj->intdata;
        # overwrite extdata if e.g. old values from before update exist:
        if ( !defined $intdata or $intdata eq q{} ) {
            $col_obj->extdata(undef);
            last DECODE;
        }

        last DECODE if lc $datatype eq 'blob'; # don't decode blobs!

        # do we have to hande ID sets generally?:
        $has_id_set = 1 if $apiis->Compat->get('id_set');
        # ... and especially for this column:
        $id_set_ref = scalar $col_obj->id_set if $has_id_set;

        # is this intdata already cached?:
        CACHE: {
            $has_cache = 1 if $apiis->Cache->hasMemcached();
            last CACHE if !$has_cache;

            # collect memcached config data, also for storing at the end:
            $mem_cache = $apiis->Cache->memcache();
            $db_name   = $apiis->Model->db_name;

            # Try to get value from cache unless already tried in decode_record:
            last CACHE if $cache_tried;

            my $data_key = $intdata;
            $data_key =~ tr/ /_/;    # change blank to underscore
            my @memkeys   =
                ( 'decode', $db_name, $thistable, $thiscol, $data_key );

            # handle columns with id_set definition separately:
            if ($id_set_ref) {
                # We only look for the first id_set, because when it's
                # missing, we don't know if it wasn't cached before or there
                # really is no value for it. So we better try to decode it.
                my $id_set = $id_set_ref->[0];
                push @memkeys, $id_set;
            }

            # special handling DATE/TIME datatype:
            if ( exists $datatype_of{ lc $datatype } ) {
                my $dateorder = $apiis->date_order;
                my $timeorder = $apiis->time_order;
                push @memkeys, $dateorder . '_' . $timeorder;
            }

            # now retrieve the value(s) for this key:
            $mem_key = join( '::', @memkeys );
            my $extdata_ref = $mem_cache->get($mem_key);
            if ($extdata_ref) {
                $cache_found = 1;
                $self->column($thiscol)->extdata($extdata_ref);
                $self->column($thiscol)->decoded(1);
                if ($debug) {
                    $apiis->log( 'debug',
                        sprintf "%s %s.%s retrieved from cache( %s->'%s')",
                        $log_prefix, $thistable, $thiscol,
                        $mem_key, join( q{,}, @$extdata_ref )
                    );
                }
                last DECODE;
            }
            if ($debug) {
                $apiis->log( 'debug', sprintf "%s key %s not found in cache",
                    $log_prefix, $mem_key );
            }
        }

        if ($debug) {
            $apiis->log( 'debug',
                sprintf "%s --> starting column %s.%s, intdata: %s",
                $log_prefix, $thistable, $thiscol, $intdata
            );
        }

        # has this column a foreign key:
        my $fk_ref = $col_obj->foreignkey;
        if ( $fk_ref ) {
            # a foreign key is defined
            if ($debug) {
                $apiis->log( 'debug', sprintf
                    "%s found foreign key definition for '%s.%s'",
                    $log_prefix, $thistable, $thiscol
                );
            }

            my ( $fk_table, $fk_db_col, @fk_where ) = @$fk_ref;

            # create a new Record from the foreign key table and decode_column:
            my $fk_record =
                Apiis::DataBase::Record->new( tablename => $fk_table, );
            $fk_record->column($fk_db_col)->intdata($intdata);
            # pass id_set over to record:
            $fk_record->column($fk_db_col)->id_set($id_set_ref)
                if $id_set_ref;
            my %decode_args = (
                column           => $fk_db_col,
                recursion_level  => $recursion_level + 1,
            );
            $decode_args{where_conditions} = \@fk_where if @fk_where;
            $fk_record->decode_column( \%decode_args );

            # propagate errors down the stack:
            if ( $fk_record->status ) {
                $self->errors( scalar $fk_record->errors );
                $self->status(1);
                last DECODE;
            }
            # propagate the decoded value downwards:
            my $fk_extdata_ref = $fk_record->column($fk_db_col)->extdata;
            $col_obj->extdata($fk_extdata_ref);
            # which of id_set() was chosen?:
            $found_best_id_set = $fk_record->column($fk_db_col)->best_id_set;
            if ($debug and $found_best_id_set) {
                $apiis->log( 'debug', sprintf
                    "%s FK-Record %s.%s returned with best_id_set '%s'",
                    $log_prefix, $thistable, $thiscol, $found_best_id_set );
            }
            last DECODE;
        }

        # no foreign key defined, but do we have a primary key definition?:
        my $model_table_obj = $apiis->Model->table($thistable);
        weaken($model_table_obj);
        my $pk_ref_col = $model_table_obj->primarykey('ref_col');

        # does the PK refer to the currently handled column?:
        if ( defined $pk_ref_col and $pk_ref_col eq $thiscol ) {
            if ($debug) {
                $apiis->log( 'debug', sprintf
                    "%s found primary key definition for '%s.%s'.",
                    $log_prefix, $thistable, $thiscol );
            }

            # is it a concatenated primary key?:
            my (%pk_concat_cols_data, %pk_ccol_datatype);
            my @pk_concat_cols = $model_table_obj->primarykey('ext_cols');
            if (@pk_concat_cols) {
                if ($debug) {
                    $apiis->log( 'debug',
                        "$log_prefix ... even a concatenated one :^)" );
                }
                # first see if we already have the internal data for the
                # @pk_concat_cols:
                my $has_intd = 0;
                for my $pk_ccol (@pk_concat_cols) {
                    my $intd = $self->column($pk_ccol)->intdata;
                    $has_intd = 1 if defined $intd and $intd ne '';
                    # could it happen that only one pk_concat_col has intdata???
                }
                if ($has_intd) {
                    if ($debug) {
                        $apiis->log( 'debug', sprintf
                            '%s intdata for pk_concat_cols %s already here',
                            $log_prefix, join( ',', @pk_concat_cols )
                        );
                    }
                    # now get the external ones:
                    my @out_arr;
                    for my $pk_ccol (@pk_concat_cols) {
                        if ($debug) {
                            $apiis->log( 'debug', sprintf
                                '%s Now handling (decoding) pk_concat_col: %s',
                                $log_prefix, $pk_ccol );
                        }
                        my %pk_args = (
                            column          => $pk_ccol,
                            recursion_level => $recursion_level + 1,
                        );
                        $self->decode_column( \%pk_args );
                        push @out_arr, $self->column($pk_ccol)->extdata;
                    }
                    if ($debug) {
                        $apiis->log( 'debug', sprintf
                            '%s Got results for pk_concat_cols: %s',
                            $log_prefix, Dumper( \@out_arr )
                        );
                    }
                    $col_obj->extdata( \@out_arr );
                    last DECODE;
                }

                # no intdata available, so fetch it:
                if ($debug) {
                    $apiis->log( 'debug',
                        sprintf "%s going to fetch data from table %s",
                        $log_prefix, $thistable );
                }

                # Would it have side effects, if we use $self to fetch the
                # pk_concat_cols-data?  Maybe the record is filled with
                # other (unchecked) data that lead to different returned
                # records??? Anyway, it's save to create a new record for
                # fetching.
                # A new record object should be taken in any case. If the
                # original record is mirrored, everything is out of order!
                # (22.5.06 - heli)

                my $fetch_record =
                    Apiis::DataBase::Record->new( tablename => $thistable );
                $fetch_record->column($thiscol)->intdata($intdata);
                $fetch_record->encoded(1);    # no encoding needed.
                if ($id_set_ref) {
                    $apiis->log( 'debug', sprintf
                        "%s setting id_set for %s.%s to %s",
                        $log_prefix, $thistable, $thiscol,
                        join( ',', @$id_set_ref )
                    ) if $debug;
                    $fetch_record->column($thiscol)->id_set($id_set_ref);
                }

                # usually we want to fetch columns @pk_concat_cols, but if
                # the ForeignKey has where-definitions (like 'ForeignKey
                # codes db_code class=SEX'), we don't need to fetch column
                # 'class':
                my @fetch_columns;
                if ($where_cond_ref) {
                    my %where_cols;
                    foreach (@$where_cond_ref) {
                        /([^\s]+)=([^\s]+)/;
                        $where_cols{$1} = 1 if defined $1;
                    }
                    foreach (@pk_concat_cols) {
                        # add to @fetch_columns if they are not part of the
                        # where condition:
                        push @fetch_columns, $_
                            if !exists $where_cols{$_};
                    }
                }
                else {
                    # We only get $where_cond_ref, if we decode codes.db_code
                    # as e.g. animal.db_sex. Only in animal we have a
                    # class=SEX condition in the model file. If we get db_code
                    # directly from codes, we don't have it. We have to catch
                    # this special case here:
                    if ( $thistable eq $apiis->codes_table
                        and scalar @pk_concat_cols > 1 ) {
                        @fetch_columns = $pk_concat_cols[1]; # only ext_code
                    }
                    else {
                        @fetch_columns = @pk_concat_cols;
                        if ($has_id_set) {
                            push @fetch_columns, 'id_set'
                                if $thistable eq 'transfer';
                        }
                    }
                }

                # there *could* be more than one expected rows as there
                # are several open datachannels for one primary key
                # possible (e.g. animal data gets filled from two stations
                # or for with sow/earnotch- and herdbook-number:
                my @fetched_records = $fetch_record->fetch(
                    expect_rows    => 'many',
                    expect_columns => \@fetch_columns,
                );
                if ( $fetch_record->status ){
                    $self->status(1);
                    $self->errors( scalar $fetch_record->errors );
                    last DECODE;
                }

                if ($debug) {
                    $apiis->log( 'debug',
                        sprintf "%s pk_concat_cols (%s) fetched successfully",
                        $log_prefix, join( q{, }, @pk_concat_cols ) );
                }

                my @result_records;
                if ( @fetched_records > 1 ) {
                    my $do_search = 0;
                    if ($id_set_ref) {
                        # transfer hardcoded!:
                        $do_search = 1 if $thistable eq 'transfer';
                    }

                    # can we track down, which record to use?:
                    my ( %id_set_of, $best_rec );
                    if ($do_search) {
                        F_REC:
                        for my $fr (@fetched_records) {
                            $fr->decode_column( { column => 'id_set' } );
                            my ($id_set_val) = $fr->column('id_set')->extdata;
                            next F_REC
                                if !defined $id_set_val and $id_set_val ne '';
                            $id_set_of{$id_set_val} = $fr;
                        }
                        $best_rec =
                            first { exists $id_set_of{$_} } @$id_set_ref;
                    }

                    if ($best_rec) {
                        # the one and only record:
                        $id_set_of{$best_rec}->column($thiscol)->best_id_set($best_rec);
                        $col_obj->best_id_set($best_rec);
                        push @result_records, $id_set_of{$best_rec};
                        $found_best_id_set = $best_rec; # for later caching
                        $apiis->log( 'debug', sprintf
                            "%s found record with best id_set: %s.%s -> %s",
                            $log_prefix, $thistable, $thiscol, $best_rec
                        ) if $debug;
                    }
                    else {
                        $apiis->log( 'warning', sprintf
                            "%s several records fetched for primary key: %s.%s",
                            $log_prefix, $thistable, $thiscol
                        );
                        $apiis->log( 'warning', sprintf '%s taking the first, '
                            . 'not neccessarily the desired one!',
                            $log_prefix
                        );
                        @result_records = @fetched_records;
                    }
                }
                else {
                    @result_records = @fetched_records;
                }

                # store data of @fetch_columns in %pk_concat_cols_data (but
                # take care: id_set is not in pk_concat_cols):
                RECORD:
                for my $thisrecord (@result_records) {
                    foreach my $this_pcc (@fetch_columns) {
                        $pk_concat_cols_data{$this_pcc} =
                            $thisrecord->column($this_pcc)->intdata;
                        $pk_ccol_datatype{$this_pcc} =
                            $thisrecord->column($this_pcc)->datatype;
                    }
                    last RECORD;
                    # Note: we take the first record (if there are still
                    # several) as last fallback if we cannot find the 'best'
                    # one. This gives a valid decoding anyway, not
                    # neccessarily the desired one.
                }
                if ($debug) {
                    $apiis->log( 'debug', sprintf
                        "%s pk_concat_cols stored in pk_concat_cols_data: %s",
                        $log_prefix, Dumper(\%pk_concat_cols_data) );
                }

                COLUMN:
                foreach my $this_ccol (@fetch_columns) {
                    next COLUMN if !first { $_ eq $this_ccol } @pk_concat_cols;
                    if ($debug) {
                        $apiis->log( 'debug',
                            sprintf "%s handling pk_concat_col %s.%s",
                            $log_prefix, $thistable, $this_ccol );
                    }

                    # has this column also a foreign key relation?:
                    my $fk_ref = $model_table_obj->foreignkey($this_ccol);
                    if ( $fk_ref ) {
                        my ( $fk_table, $fk_db_col, @fk_where ) = @$fk_ref;

                        if ($debug) {
                            my $tmp_text = ' with ' . join( ',', @fk_where )
                                if @fk_where;
                            $apiis->log( 'debug', sprintf
                                "%s this PK has a foreign key to %s.%s %s",
                                $log_prefix, $fk_table, $fk_db_col,
                                ( $tmp_text || '' )
                            );
                        }

                        # resolve the FK:
                        my @thisdata;
                        my $fk2_record = Apiis::DataBase::Record->new(
                            tablename => $fk_table );
                        $fk2_record->column($fk_db_col)->intdata(
                            $pk_concat_cols_data{$this_ccol} );

                        my %fk_args = (
                            column          => $fk_db_col,
                            recursion_level => $recursion_level + 1,
                        );
                        if (@fk_where) {
                            $fk_args{where_conditions} = \@fk_where;
                        }
                        $fk2_record->decode_column( \%fk_args );

                        if ( $fk2_record->status ) {
                            $self->errors( scalar $fk2_record->errors );
                            $self->status(1);
                            last DECODE;
                        }

                        # propagate the decoded value downwards,
                        # but don't simply replace extdata:
                        my $extdata_ref = $col_obj->extdata;
                        if ( $extdata_ref ) {
                            $col_obj->extdata( @$extdata_ref,
                                $fk2_record->column($fk_db_col)->extdata
                            );
                        }
                        else {
                            $col_obj->extdata(
                                $fk2_record->column($fk_db_col)->extdata );
                        }
                        next COLUMN;
                    }

                    # no FK, so copy data into record:
                    my $extdata_ref = $col_obj->extdata;
                    if ($extdata_ref) {
                        my $ccol_data = $pk_concat_cols_data{$this_ccol};
                        my $ccol_datatype = $pk_ccol_datatype{$this_ccol};
                        my @old_extdata = @$extdata_ref;

                        # date/time conversion if needed:
                        if ( exists $datatype_of{ lc $ccol_datatype } ) {
                            my $ccol_tmp;
                            my $code_ref = $datatype_of{ lc $ccol_datatype };
                            $ccol_tmp = $self->$code_ref($ccol_data);
                            # $ccol_tmp = $code_ref->( ref $self, $ccol_data);

                            if ($debug) {
                                $apiis->log( 'debug', sprintf
                                    "%s Date/Time converted for %s.%s (%s=>%s)",
                                    $log_prefix, $thistable, $this_ccol,
                                    $ccol_data, $ccol_tmp
                                );
                            }
                            $ccol_data = $ccol_tmp;
                        }

                        $col_obj->extdata( @old_extdata, $ccol_data );

                        if ($debug) {
                            $apiis->log( 'debug', sprintf
                                "%s copy non-FK-data (%s) into %s.%s (%s)",
                                $log_prefix, join( q{,}, $col_obj->extdata ),
                                $thistable, $col_obj->name,
                                "$ccol_data appended",
                            );
                        }
                    }
                    else {
                        # no date/time conversion needed here.
                        $col_obj->extdata(
                            $pk_concat_cols_data{$this_ccol} );

                        if ($debug) {
                            $apiis->log( 'debug',
                                sprintf "%s copy non-FK-data (%s) into %s.%s",
                                $log_prefix, join( q{,}, $col_obj->extdata ),
                                $thistable, $col_obj->name
                            );
                        }
                    }
                }
                last DECODE;
            }

            # this column is the pk_ref_col, but there are no pk_concat_cols,
            # so this column contains the encoded data. We simply copy the
            # internal data to the external.
            $col_obj->extdata($intdata);
            if ($debug) {
                $apiis->log( 'debug',
                    "$log_prefix decoding/copying a non-concatenated PK column"
                );
            }
            last DECODE;
        }

        # no FK, no PK. We just copy the internal data to external:
        $col_obj->extdata($intdata);

        if ($debug) {
            $apiis->log( 'debug',
                "$log_prefix decoding/copying non-PK/non-FK column" );
        }
    }    # end label DECODE

    # postprocessing:
    POST: {
        last POST if !defined $thiscol;

        if ( lc $datatype eq 'blob' ) {
            if ($debug) {
                $apiis->log( 'debug',
                    sprintf "%s %s.%s: skipped decoding of datatype 'blob'",
                    $log_prefix, $thistable, $thiscol );
            }
            last POST;
        }

        if ( !$self->status ) {
            my $extdata_ref = $col_obj->extdata;
            my @old_extdata;
            if ($extdata_ref) {
                # store old values for debugging:
                @old_extdata = @$extdata_ref if $debug;

                # convert every column to external date/time:
                if ( exists $datatype_of{ lc $datatype } ) {
                    # change the dates *inline* for every part of array extdata:
                    # ok, should/could be only one anyway, or?:
                    for my $idx ( 0 .. ( scalar @$extdata_ref - 1 ) ) {
                        my $code_ref = $datatype_of{ lc $datatype };
                        my $val      = $extdata_ref->[$idx];
                        $extdata_ref->[$idx] = $self->$code_ref($val);
                        # $extdata_ref->[$idx] = $code_ref->( ref $self, $val );
                    }
                    if ($debug) {

                        #-- undef -> ''
                        map { if (!defined $_) {$_=''} } @$extdata_ref;

                        $apiis->log( 'debug', sprintf
                            "%s Date/Time converted for %s.%s (%s => %s)",
                            $log_prefix, $thistable, $thiscol,
                            join( q{,}, @old_extdata ),
                            join( q{,}, @$extdata_ref ),
                        );
                    }
                }
                $col_obj->decoded(1);
                $col_obj->encoded(1);

                if ($debug) {
                       
                    #-- undef -> ''
                    map { if (!defined $_) {$_=''} } @$extdata_ref;

                    $apiis->log( 'debug',
                        sprintf "%s extdata for '%s.%s' found: %s",
                        $log_prefix, $thistable, $thiscol,
                        join( q{,}, @$extdata_ref )
                    );
                }

                # write them into the cache for later use:
                if ( $has_cache and !$cache_found ) {
                    my ( @memkeys, $mem_key );
                    $intdata =~ tr/ /_/;    # change blank to underscore
                    @memkeys =
                        ( 'decode', $db_name, $thistable, $thiscol, $intdata );

                    SPECIAL: {
                        # special handling for db_animal/id_set:
                        if ($id_set_ref) {
                            # add the ID set to the key
                            $found_best_id_set = $col_obj->best_id_set
                                if !$found_best_id_set;
                            if ($found_best_id_set) {
                                push @memkeys, $found_best_id_set;
                            }
                            last SPECIAL;
                        }

                        # special handling DATE/TIME datatype:
                        if ( exists $datatype_of{ lc $datatype } ) {
                            my $dateorder = $apiis->date_order;
                            my $timeorder = $apiis->time_order;
                            push @memkeys, $dateorder . '_' . $timeorder;
                        }
                        last SPECIAL;
                    }

                    $mem_key = join( '::', @memkeys );
                    # timeout in seconds:
                    $mem_cache->set( $mem_key, $extdata_ref, 36000 );
                    if ($debug) {
                        $apiis->log( 'debug',
                            sprintf "%s %s.%s stored in cache( %s->'%s')",
                            $log_prefix, $thistable, $thiscol,
                            $mem_key, join( q{,}, @$extdata_ref )
                        );
                    }
                }
            }
        }

        if ($debug) {
            $apiis->log( 'debug', sprintf "%s --> finished decoding column %s.%s",
                $log_prefix, $thistable, $thiscol );
        }
    } # end label POST
}

=head1 BUGS

Lots!

If you set 

   $apiis->debug(1);

you will get a nice output of what these methods are doing.

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

##############################################################################
1;

