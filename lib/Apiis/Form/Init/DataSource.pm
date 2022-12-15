##############################################################################
# $Id: DataSource.pm,v 1.28 2022/02/25 22:10:15 ulf Exp $
# Provides data structures to access data according to the defined
# DataSources in the xml config files.
##############################################################################
package Apiis::Form::Init::DataSource;

use strict;
use warnings;
our $VERSION = '$Revision: 1.28 $';

use Apiis;
use base 'Apiis::Init';
use Data::Dumper;
use Carp qw( longmess );
use List::MoreUtils qw( uniq each_array );
use List::Util qw( first );
use Scalar::Util qw( weaken );

##############################################################################

=head1 NAME

Apiis::Form::Init::DataSource -- auxiliary package to retrieve datasources

=head1 SYNOPSIS

This auxiliary package provides internal methods for Apiis::Form::Init.pm
concerning datasources. These methods are generic for all widget sets.

=head1 METHODS

=cut

##############################################################################

=head2 _get_datasources (internal)

After parsing and reordering of the xml configuration is done, the connection to
the datasources is done by B<_get_datasources>. For scalar fields it creates
references to (undef) variables, for listfields additionally references to
arrays that contain the data to be listed.

=cut

sub _get_datasources {
    my ( $self, %args ) = @_;
    foreach my $blockname ( $self->blocknames ) {
        # only one datasource possible:
        my $ds_name =
            ${ $self->GetValue( $blockname, '_datasource_list' ) }[0];
        $self->{'_flat'}{$ds_name}{'__rowid'} = undef;    # ToDo: indizieren

        # are the fields of scalar or list type?:
        my %_is_a_list_column;
        my $field_list_ref = $self->GetValue( $blockname, '_all_field_list' );
        if ($field_list_ref) {
            foreach my $fieldname (@$field_list_ref) {
                my $type = lc $self->GetValue( $fieldname, 'Type' );
                
                #-- if a listfield or a textfield with a datasource to 
                #-- get a default value
                if (  $self->is_a_listfield($type) or
                    (($type eq 'textfield') and $self->GetValue( $fieldname, '_my_field_datasource' )) ) {

                    my $ds_name = $self->GetValue( $fieldname, '_my_field_datasource' );

                    if ($ds_name) {
                        # Field has own DataSource to provide the list values:
                        $self->{'_flat'}{$fieldname}{'_list_ref'} =
                            $self->get_field_list_ref($fieldname);

                        #-- muelf fill _data_ref with first list_ref  for default
                        $self->{'_flat'}{$fieldname}{'_data_ref'}=
                            \$self->{'_flat'}{$fieldname}{'_list_ref'}->[0];
                    }
                    else {
                        my $col = $self->GetValue( $fieldname, 'DSColumn' );
                        $_is_a_list_column{$col} = 1;
                    }
                }
            }
        }

        # create the list datastructure for the columns/fields and also the
        # reverse list for every Column, which other Columns are related to:
        my $columns_ref = $self->GetValue( $ds_name, '_column_list' );
        for my $thiscol (@$columns_ref) {
            # list datastructes:
            if ( exists $_is_a_list_column{$thiscol} ) {
                my $fieldname = $self->GetValue( $thiscol, '_field' );
                $self->{'_flat'}{$fieldname}{'_list_ref'} =
                    $self->Apiis::Form::Init::DataSource::_get_list_ref(
                        $thiscol);
            }
            # related columns:
            my $coltype = $self->GetValue( $thiscol, 'Type' );
            if ( $coltype eq 'Related' ) {
                my $rel_col = $self->GetValue( $thiscol, 'RelatedColumn' );
                my $order   = $self->GetValue( $thiscol, 'RelatedOrder' );

                # Store the Column names, which point to this Column in an
                # arrayref in the order, defined in the xml-file:
                ${ $self->{'_flat'}{$rel_col}{'_related_from'} }[$order] =
                    $thiscol;
            }
        }
    }
}
##############################################################################

=head2 _get_block_ds (internal)

B<_get_block_ds> runs the defined DataSource on Block level, typically a
DataSource of type Sql or Function, and fills the Fields of this block with
data.

Currently only for DataSource type Function implemented.

=cut

sub _get_block_ds {
    my ( $self, $args_ref ) = @_;
    my $block = $args_ref->{blockname};
    EXIT: {
        last EXIT if !$block;
        my $ds   = $self->GetValue( $block, 'DataSource' );
        my $type = $self->GetValue( $ds,    'Type' );

        # Function:
        if ( lc $type eq 'function' ) {
            my $mod  = $self->GetValue( $ds, 'Module' );
            my $func = $self->GetValue( $ds, 'FunctionName' );
            my $full_mod = 'Apiis::Form::Event::' . $mod;
            eval "require $full_mod"; ## no critic
            if ( $@ ){
                my $msg = $@;
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => '_get_block_ds',
                        backtrace => longmess('invoked'),
                        msg_long  => $msg,
                        msg_short => sprintf 'Error in loading Function: %s',
                                     $full_mod,
                    ),
                );
                last EXIT;
            }
            my $command = $full_mod . '::' . $func;
            $self->$command( $args_ref );
        }
    } # end label EXIT
}

##############################################################################

=head2 _get_list_ref (internal)

B<_get_list_ref> returns a list of values for list fields, which expect this
list (like ScrollingList, etc.).

Currently supported DataSource types are Sql and Record.

=cut

sub _get_list_ref {
    my ( $self, $columnname ) = @_;
    my $ds_name = $self->GetValue( $columnname, '_parent' );
    my $ds_type = lc $self->GetValue( $ds_name, 'Type' );
    my $return_val;

    EXIT: {
        if ( $ds_type eq 'sql' ) {
            # Sql:
            my $statement = $self->GetValue( $ds_name, 'Statement' );
            my $sql_obj = $apiis->DataBase->sys_sql($statement);
            if ( $sql_obj->status ){
                $self->status(1);
                $self->errors( $sql_obj->errors );
                last EXIT;
            }
            my $data_ref = $sql_obj->handle->fetchall_arrayref;
            my $order_index = $self->GetValue( $columnname, 'Order' );
            my @thislist;
            # push @thislist, $_->[$order_index] for @$data_ref;
            for my $line_ref (@$data_ref) {
                my $col = $line_ref->[$order_index];
                push @thislist, ( defined $col ? $col : 'NULL' );
            }

            if (@thislist) {
                $return_val = \@thislist;
                last EXIT;
            }
            last EXIT;
        }


        if ( $ds_type eq 'record' ) {
            # Record:
            my $tablename = $self->GetValue( $ds_name, 'TableName' );
            my $record_obj =
                Apiis::DataBase::Record->new( tablename => $tablename );
            my $col_dataname = $self->GetValue( $columnname, 'DBName' );
            my $thiscol_obj  = $record_obj->column($col_dataname);
            weaken($thiscol_obj);
            if ( $record_obj->status ) {
                # could not get column object, e.g. for a related column
                # listfield without Field-specific DataSource:
                my $fieldname = $self->GetValue( $columnname, '_field' );
                my $type = lc $self->GetValue( $fieldname, 'Type' );
                my $msg = sprintf "Could not create Field of type %s", $type;
                $msg .= sprintf " for %s (%s)", $columnname, $col_dataname;
                for my $err ( $record_obj->errors ) {
                    my $msg_long = $err->msg_long || '';
                    $err->msg_long( $msg_long . $msg );
                }
                $self->status(1);
                $self->errors( scalar $record_obj->errors );
            }
            last EXIT if !$thiscol_obj;

            if ( $thiscol_obj->check ) {
                foreach my $thischeck ( $thiscol_obj->check ) {
                    require Text::ParseWords;
                    my ( $thisrule, @check_args ) =
                        Text::ParseWords::parse_line( '\s+', 0, $thischeck );

                    # List:
                    if ( $thisrule eq 'List' ) {
                        $return_val = \@check_args;
                        last EXIT;
                    }

                    # ForeignKey:
                    if ( $thisrule eq 'ForeignKey' ) {
                        # e.g. 'ForeignKey codes db_code class=ENTRY_ACTION'
                        my ($fk_table, $fk_column, $fk_where) = @check_args;
                        my @return_list;
                        my @q_records;
                        my $fk_record_obj =
                            Apiis::DataBase::Record->new(
                            tablename => $fk_table );
                        if ( $fk_where ) {
                            $fk_where =~ /(.*)=(.*)/;
                            $fk_record_obj->column($1)->extdata($2);
                        }
                        else {
                            # workaround for missing where clause:
                            $fk_record_obj->column($fk_column)->extdata(
                                'not null');
                        }
                        @q_records =
                            $fk_record_obj->fetch(
                            expect_columns => $fk_column );

                        for my $this_rec_obj (@q_records) {
                            $this_rec_obj->decode_record;
                            my @ext_data =
                                $this_rec_obj->column( $fk_column )->extdata;

                            # workaround for table codes: the PrimaryKey is
                            # concatenated from class and ext_code, so the
                            # decoded extdata for db_code is e.g. 'SEX', 'm'.
                            # For ListFields etc. we only want the ext_code,
                            # so we have to skip the first one:
                            if ( $fk_table eq $apiis->codes_table
                                and scalar @ext_data > 1 )
                            {
                                push @return_list, $ext_data[1];
                            }
                            else {
                                push @return_list, $ext_data[0];
                            }
                        }
                        if (@return_list) {
                            my @sorted = sort @return_list;
                            $return_val = \@sorted;
                            last EXIT;
                        }
                    }
                }
            }
            # no CHECK rules or no List/FK CHECK rules:
            $record_obj->column($col_dataname)->extdata('not null');
            my @q_records =
                $record_obj->fetch( expect_columns => $col_dataname );
            my %return_list;
            for my $this_rec_obj (@q_records) {
                $this_rec_obj->decode_record;
                my @ext_data = $this_rec_obj->column($col_dataname)->extdata;
                if ( $tablename eq $apiis->codes_table
                    and scalar @ext_data > 1 )
                {
                    $return_list{ $ext_data[1] } = undef;
                }
                else {
                    $return_list{ $ext_data[0] } = undef;
                }
            }
            if ( keys %return_list ) {
                my @sorted = sort keys %return_list;
                $return_val = \@sorted;
                last EXIT;
            }
            last EXIT;
        }
    }
    my @uniq_list = uniq @$return_val;
    return \@uniq_list;
}
##############################################################################

sub _get_field_data_ref {
    my ( $self, $fieldname ) = @_;

    EXIT: {
        my $ds_name = $self->GetValue( $fieldname, '_my_field_datasource' );
        last EXIT if !defined $ds_name;

        my $ds_type = lc $self->GetValue( $ds_name, 'Type' );
        if ( $ds_type eq 'sql' ) {
            my $statement = $self->GetValue( $ds_name, 'Statement' );
            $statement =~ tr/ //s;  # remove duplicate blanks

            # check for placeholders:
            my $bind_ref = $self->get_bind_params( { datasource => $ds_name } );

            # run and check the SQL statement:
            my %sql_args = (
                statement => $statement,
                user      => 'application',
                # user      => 'system',
            );
            $sql_args{execute} = 0 if $bind_ref;

            my ( $sql_obj, $data_ref, @bind_values );
            eval {
                # at least prepare the query:
                $sql_obj = $apiis->DataBase->sql( \%sql_args );

                # run execute separately if we work with placeholders:
                if ($bind_ref) {
                    my $idx = 0;
                    for my $param ( @{$bind_ref} ) {
                        $idx++;
                        # set bindtypes for the placeholders:
                        my $bindtype = $param->{bindtype};
                        if ($bindtype) {
                            my $h_ref = eval "{ $bindtype }"; ## no critic
                            $sql_obj->handle->bind_param( $idx, undef, $h_ref );
                        }

                        # get the data for this Field as bind value:
                        my $f_data_ref =
                            $self->GetValue( $param->{fieldname}, '_data_ref' );
                        push @bind_values, $$f_data_ref;
                    }
                    # execute:
                    $sql_obj->handle->execute(@bind_values);
                }

                # finally fetch the data:
                $data_ref = $sql_obj->handle->fetchall_arrayref;
            };

            # check for errors:
            if ($@) {
                my $err_msg = $@;
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DB',
                        severity  => 'ERR',
                        from      => '_get_field_data_ref',
                        backtrace => longmess('invoked'),
                        msg_short => $err_msg,
                        msg_long  => sprintf
                            'Error in SQL statement: %s Bind values: %s',
                            Dumper( \%sql_args ), join( q{,}, @bind_values ),
                    ),
                );
                last EXIT;
            }
            if ( $sql_obj->status ) {
                $self->status(1);
                $self->errors( scalar $sql_obj->errors );
                last EXIT;
            }

            my $field_data_ref = $self->GetValue( $fieldname, '_data_ref' );
            RECORD:
            for my $line_ref (@$data_ref) {
                $$field_data_ref = $line_ref->[0];
                # we expect only one scalar value, so skip the rest:
                last RECORD;
            }
        }
    } # end label EXIT
    return;
}
##############################################################################

=head2 _get_field_list_ref (internal)

B<_get_field_list_ref> works like B<_get_list_ref> but on Field level. If you
want to provide a field-specific, non-standard list of allowed values, you can
define an own DataSource for this field. The currently supported DataSource
type is only Sql.

B<_get_field_list_ref> is based on some hardcoded assumptions:

=over 2

=item *
if the defined DataSource returns only one column, no translation take place.
This could be used to produce lists depending on the values of other fields.

=item *
if the defined DataSource returns two columns, they must accord to the
following rules:

=item *
the first one is the external representation of the primary/foreign key column
and builds the key of %translate_hash.

=item *
the second one is arbitrary and provides the shown values for the list field.
It builds the value of %translate_hash.

=back

Example: You want to get codes.long_name instead of codes.ext_code as
the list of allowed values. The SQL text then must look like this:

   SELECT ext_code, long_name FROM codes WHERE class='SEX'

Important is the order of ext_code (first) and long_name (second). These two
value pairs build up a tranlation hash which is used whenever values come or
go from/to the database.

It's also possible, to have several values for one key.

If there are keys with missing values, these missing values are replaced by
'NULL_<index>'. The index is incremented if there are several missing vals.

There is an adjustable threshold for lists, that are too big to make any
sense. If this happens, an error message is displayed as list. The threshold
is currently set to 10.000 list entries.

=cut

sub _get_field_list_ref {
    my ( $self, $fieldname ) = @_;
    my $too_big = 10_000; # threshold for max size of return list
    my ( @return_list, @uniq_list );
    EXIT: {
        my $ds_name = $self->GetValue( $fieldname, '_my_field_datasource' );
        last EXIT if !defined $ds_name;

        my $ds_type = lc $self->GetValue( $ds_name, 'Type' );

        my $data_ref;

        if ( ($ds_type eq 'sql' ) or ($ds_type eq 'function') or ($ds_type eq 'sqlfunction')) {

            if ( $ds_type eq 'sqlfunction' ) {

                my $statement = "select * from ".$self->GetValue( $ds_name, 'View' );
                
                my ( $sql_obj, @bind_values );

                # run and check the SQL statement:
                my %sql_args = (
                    statement => $statement,
                    user      => 'system',
                );

                eval {
                    # at least prepare the query:
                    $sql_obj = $apiis->DataBase->sql( \%sql_args );

                    # finally fetch the data:
                    $data_ref = $sql_obj->handle->fetchall_arrayref;
                };

                # check for errors:
                if ($@) {
                    my $err_msg = $@;
                    $self->status(1);
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DB',
                            severity  => 'ERR',
                            from      => '_get_field_list_ref',
                            line      => __LINE__,
                            backtrace => longmess('invoked'),
                            msg_short => $err_msg,
                            msg_long  => sprintf
                                'Error in SQL statement: %s Bind values: %s',
                            Dumper( \%sql_args ), join( q{,}, @bind_values ),
                        ),
                    );
                    last EXIT;
                }
                if ( $sql_obj->status ) {
                    $self->status(1);
                    $self->errors( scalar $sql_obj->errors );
                    last EXIT;
                }

            } elsif ( $ds_type eq 'sql' ) {
                my $statement = $self->GetValue( $ds_name, 'Statement' );
                $statement =~ tr/ //s;  # remove duplicate blanks

                # check for placeholders:
                my $bind_ref = $self->get_bind_params( { datasource => $ds_name } );

                # run and check the SQL statement:
                my %sql_args = (
                    statement => $statement,
                    user      => 'system',
                );
                $sql_args{execute} = 0 if $bind_ref;

                my ( $sql_obj, @bind_values );
                eval {
                    # at least prepare the query:
                    $sql_obj = $apiis->DataBase->sql( \%sql_args );

                    # run execute separately if we work with placeholders:
                    if ($bind_ref) {
                        my $idx = 0;
                        for my $param ( @{$bind_ref} ) {
                            $idx++;
                            # set bindtypes for the placeholders:
                            my $bindtype = $param->{bindtype};
                            if ($bindtype) {
                                my $h_ref = eval "{ $bindtype }";    ## no critic
                                $sql_obj->handle->bind_param( $idx, undef, $h_ref );
                            }

                            # get the data for this Field as bind value:
                            my $f_data_ref =
                                $self->GetValue( $param->{fieldname}, '_data_ref' );
                            # set empty string to undef/NULL:
                            if ( defined $$f_data_ref ) {
                                $$f_data_ref = undef if $$f_data_ref eq '';
                            }
                            push @bind_values, $$f_data_ref;
                        }
                        # execute:
                        $sql_obj->handle->execute(@bind_values);
                    }
                    # finally fetch the data:
                    $data_ref = $sql_obj->handle->fetchall_arrayref;
                };

                # check for errors:
                if ($@) {
                    my $err_msg = $@;
                    $self->status(1);
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DB',
                            severity  => 'ERR',
                            from      => '_get_field_list_ref',
                            line      => __LINE__,
                            backtrace => longmess('invoked'),
                            msg_short => $err_msg,
                            msg_long  => sprintf
                                'Error in SQL statement: %s Bind values: %s',
                            Dumper( \%sql_args ), join( q{,}, @bind_values ),
                        ),
                    );
                    last EXIT;
                }
                if ( $sql_obj->status ) {
                    $self->status(1);
                    $self->errors( scalar $sql_obj->errors );
                    last EXIT;
                }

            }
            else {
                no strict "refs";

                my $fun=$self->GetValue( $ds_name, 'FunctionName' );
                my $LO=$self->GetValue( $ds_name, 'Module' );

                require $LO.".pm";
                my $mod=$LO.'::'.$fun;

                $data_ref=&$mod($apiis);

                if ( $@ ){
                    my $msg = $@;
                    $self->status(1);
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'CODE',
                            severity  => 'ERR',
                            from      => '_get_list_ref',
                            backtrace => longmess('invoked'),
                            msg_long  => $msg,
                            msg_short => sprintf 'Error in loading Function: %s',
                                        $fun,

                        ),
                    );
                }
            }

            # retrieve the data:
            my $i        = 0;
            my $has_any_value = 0;
            my ( @keys, @values );
            for my $line_ref (@$data_ref) {
                push @keys, $line_ref->[0];    # database key (ext)
                my $val = $line_ref->[1];      # display value
                if ( !defined $val ) {
                    $val = qq{NULL_$i};    # for multiple undef values add index
                    $i++;
                }
                else {
                    $has_any_value++;
                }
                push @values, $val;
            }

            if ($has_any_value) {
                # ok, we have a translation with two columns:
                # %translate_hash = pairwise { ( $a => $b ) } @keys, @values;
                my %translate_hash;
                my $ea = each_array( @keys, @values );
                while ( my ( $k, $v ) = $ea->() ) {
                    if ($k) {
                        push @{ $translate_hash{$k} }, $v;
                    }
                }

                $self->SetValue( $fieldname, '_datasource_translate',
                    \%translate_hash );
                @uniq_list = uniq @values;
            }
            else {
                # no translation, take only keys:
                @uniq_list = uniq @keys;
            }
        }
    } # end label EXIT

    my $count = scalar @uniq_list;
    if ( $count > $too_big ) {
        @uniq_list = (
            __('** Too big! **'),
            __('This list is too big!'),
            __("Found [_1] elements", $count),
            __("Threshold is [_1]", $too_big),
        );
    }
    $self->{'_flat'}{$fieldname}{'_list_ref'} = \@uniq_list;
    my $dref = $self->{'_flat'}{$fieldname}{'_data_ref'};
    if ( defined $$dref ){
        # delete old entry if it's not in the restored list:
        $$dref = undef if !first { $_ eq $$dref } @uniq_list;
    }
    return \@uniq_list;
}
##############################################################################

=head2 _list_ref_coding (internal)

B<_list_ref_coding> does the encoding/decoding for the non-standard values in
a listfield, provided by a field-specific DataSource.

The public interfaces for these tasks are B<encode_list_ref> and
B<decode_list_ref>, which are located in Apiis::Form::Init.pm.

=cut

sub _list_ref_coding {
    my ( $self, $fieldname, $value, $code ) = @_;
    my $return_val;

    EXIT: {
        last EXIT if not defined $fieldname;
        last EXIT if not defined $value;
        last EXIT if not defined $code;
        
        if ( $value eq q{} ){
            $return_val = q{};
            last EXIT;
        }

        my $ds_name = $self->GetValue( $fieldname, '_my_field_datasource' );
        last EXIT if not defined $ds_name;

        my $translate_hash_ref =
            $self->GetValue( $fieldname, '_datasource_translate' );

        # if we don't have any translation, only a SQL-datasource:
        if ( !$translate_hash_ref ){
            $return_val = $value;
            last EXIT;
        }

        if ( $code eq 'encode' ) {
            # $value means 'key' in this case:
            if ( exists $translate_hash_ref->{$value} ) {
                # return the first element of the stored array:
                $return_val = $translate_hash_ref->{$value}[0];
                last EXIT;
            }
        }
        if ( $code eq 'decode' ) {
            for my $k ( keys %$translate_hash_ref ) {
                # take this key if one entry matches:
                $return_val = $k
                    if first { $_ eq $value } @{ $translate_hash_ref->{$k} };
                last EXIT if defined $return_val;
            }
            
            # if OnlyListEntries="no", new values, which are not in list are possible
            if ( $self->GetValue( $fieldname, 'OnlyListEntries') eq "no" ) {
                $return_val=$value;
                last EXIT;
            }
        }

        my $db_column = $self->GetValue( $fieldname, 'DBName' );
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type       => 'DATA',
                severity   => 'ERR',
                from       => '_list_ref_coding',
                ext_fields => [$fieldname],
                db_column  => $db_column,
                data       => $value,
                msg_short  => __('Value violated the provided list'),
                msg_long   => __(
                    "Allowed values: [_1]",
                    join( ',', keys %$translate_hash_ref )
                ),
            )
        );
    }
    return $return_val;
}
##############################################################################

=head2 get_bind_params (internal)

B<get_bind_params> collects the important parameters of a SQL datasource with
bind parameters.

As input parameter it expects a hash reference with the key 'datasource' and
the name of this datasource as value.

B<get_bind_params> returns an arrayref of hash references, where each hash
provides these keys/values:

   name      => <Name of this parameter (XML)>
   fieldname => <Fieldname (XML), to which this bind parameter points>
   bindtype  => <database specific bind type of this DB column>

B<get_bind_params> is defined in Apiis::Form::Init.pm as a wrapper, while the
real code resides in Apiis::Form::Init::DataSource.pm as B<_get_bind_params>.

=cut

sub _get_bind_params {
    my ( $self, $args_ref ) = @_;

    my @params;
    EXIT: {
        my $datasource = $args_ref->{datasource};
        if ( not defined $datasource ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'get_bind_params',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'datasource', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # get parameters for this datasource:
        my $parameter_ref = $self->GetValue( $datasource, '_parameter_list' );
        last EXIT if !$parameter_ref;

        # process parameters now:
        PARAM:
        for my $parameter (@$parameter_ref) {
            my %thispar;
            my $key = $self->GetValue( $parameter, 'Key' );
            next PARAM if $key ne 'placeholder';
            my $val = $self->GetValue( $parameter, 'Value' );
            $thispar{name}      = $parameter;
            $thispar{fieldname} = $val;

            # define the datatypes of the placeholders:
            # (TableName is optional for Column. We only need it here to get
            # the bindtype. Without bindtype we have to rely on the DBI
            # defaults.)
            my $ds_col = $self->GetValue( $val,    'DSColumn' );

            my ($db_col,$table);

            #-- only if ds_col exists 
            if ($ds_col) {

                $db_col = $self->GetValue( $ds_col, 'DBName' );
                # could be defined at Column level:
                $table  = $self->GetValue( $ds_col, 'TableName' );
            }

            if ( $table) {
                # first try to retrieve from Cache:
                my $namespace = 'bindtype';
                my $c_key     = "${table}.${db_col}";
                my $bindtype  = $apiis->Cache->GetCache( $namespace, $c_key );

                # No cache? Consult Modelfile and database config:
                if ( !$bindtype ) {
                    my $metatype =
                        $apiis->Model->table($table)->column($db_col)->datatype;
                    $bindtype = $apiis->DataBase->bindtypes($metatype);
                    # store in Cache:
                    $apiis->Cache->SetCache( $namespace, $c_key, $bindtype );
                }

                # store the bindtype for this parameter:
                if ($bindtype) {
                    $thispar{bindtype} = $bindtype;
                }
            }
            else {
                $apiis->log( 'warning', sprintf
                    'Add attribute TableName to Column %s in XML file %s',
                    $ds_col, $self->xmlfile);
            }
            push @params, \%thispar;
        }
    }    # end label EXIT
    return \@params;
}
##############################################################################

=head2 _ro2fields (internal)

B<_ro2fields> is an internal method to store the extdata values of a Record
Object into the form's fields.

input: hashref with keys 'datasource', 'record_obj', and 'row_index'

    $self->_ro2fields(
        {   datasource => 'name of DataSource',
            record_obj => $rec_obj,
            row_index  => 0,
        }
    );

    The row_index points to the index in the _data_refs array (mainly for
    tabulars). Default for row_index is 0.

output: none, values of the record object get stored in _data_ref of the
fields.

=cut

sub _ro2fields {
    my ( $self, $args_ref ) = @_;

    EXIT: {
        my $ds_name = $args_ref->{datasource};
        last EXIT if !defined $ds_name;
        my $record  = $args_ref->{record_obj};
        last EXIT if !$record;

        weaken( $record );
        $record->decoded(0);
        $record->mirror_intdata;
        $record->decode_record;
        $record->mirror_extdata;

        my $row_idx = $args_ref->{row_index} || 0;
        my @columns = @{ $self->GetValue( $ds_name, '_column_list' ) };

        COL1:
        foreach my $thiscol (@columns) {
            next COL1 if $self->GetValue( $thiscol, 'Type' ) ne 'DB';
            my $db_col    = $self->GetValue( $thiscol, 'DBName' );
            my $fieldname = $self->GetValue( $thiscol, '_field' );
            next COL1 if !defined $fieldname;

            my @extdata = $record->column($db_col)->extdata;
            my $data_refs = $self->GetValue( $fieldname, '_data_refs' );
            if ( scalar @extdata > 1 ) {
                # here we handle related columns:
                my @related_from;
                @related_from =
                    @{ $self->GetValue( $thiscol, '_related_from' ) }
                    if $self->GetValue( $thiscol, '_related_from' );

                # also display intdata, mainly for debugging:
                my $int_data_ref = $data_refs->[$row_idx];
                $$int_data_ref = undef;
                $$int_data_ref = $record->column($db_col)->intdata;
                $self->SetValue( $fieldname, '_displays_intdata', 1 );

                # now extdata:
                EXTDATA:
                for ( my $i = 0; $i <= $#related_from; $i++ ) {
                    my $rel_field =
                        $self->GetValue( $related_from[$i], '_field' );
                    next EXTDATA if !defined $rel_field;
                    my $rel_data_refs =
                        $self->GetValue( $rel_field, '_data_refs' );
                    my $rel_data_ref = $rel_data_refs->[$row_idx];
                    $$rel_data_ref = $extdata[$i];
                    # read variable once to make tie happy:
                    my $_tmp = $$rel_data_ref;
                }
            }
            else {
                my $data_ref = $data_refs->[$row_idx];
                if ( $self->GetValue( $fieldname, '_my_field_datasource' ) ) {
                    # field has its own datasource for _list_ref:
                    my $val;
                    # do we handle intdata?:
                    if ( $self->GetValue( $fieldname, '_displays_intdata' ) ) {
                        my $intdata = $record->column($db_col)->intdata;
                        $val = $self->encode_list_ref( $fieldname, $intdata );
                    }
                    else {
                        $val =
                            $self->encode_list_ref( $fieldname, $extdata[0] );
                    }
                    last EXIT if $self->status;    # encode did not succeed
                    $extdata[0] = $val;
                }
                $$data_ref = $extdata[0];
                # read variable once to make tie's fetch method happy:
                my $_tmp = $$data_ref;
            }

            # copy first element of _data_refs to _data_ref;
            my $data_ref_0 = $data_refs->[0];
            # next COL1 if !defined $data_ref_0;
            my $df = $self->GetValue( $fieldname, '_data_ref' );
            $$df = $$data_ref_0;
        }
    }    # end label EXIT
}
##############################################################################

1;
