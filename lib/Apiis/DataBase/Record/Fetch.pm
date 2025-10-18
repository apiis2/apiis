##############################################################################
# $Id: Fetch.pm,v 1.30 2014/12/08 08:56:55 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Fetch;
$VERSION = '$Revision: 1.30 $';
# See POD at end of file.
##############################################################################

use strict;
use warnings;
use Data::Dumper;
use Carp qw(croak);
use Apiis::Init;

sub _fetch {
    my ( $self, %args ) = @_;

    # only allow invocation from Record object:
    my ( $package, $filename, $line ) = caller;
    if ( $package ne 'Apiis::DataBase::Record' ) {
        croak sprintf( "Method fetch may only be invoked from package %s.\n",
            'Apiis::DataBase::Record' )
            . "You called it from $package";
    }

    # tell the record object that we are now doing a fetch:
    my $oldaction = $self->action('fetch');
    my @return_array;

    EXIT: {
        my $sql_user = $args{'user'};
        delete $args{'user'};
        my $order_by_ref = $args{'order_by'};
        delete $args{'order_by'};

        $sql_user='system' if (!$sql_user);

        # check order_by clause:
        if ($order_by_ref) {
            if ( ref $order_by_ref ne 'ARRAY' ) {
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'PARAM',
                        severity  => 'ERR',
                        from      => 'Apiis::DataBase::Record::Fetch::fetch',
                        msg_short => 'Wrong parameter type passed',
                        msg_long  =>
                            'order_by must have an array reference as value',
                    )
                );
                last EXIT;
            }
        }

        # handle remaining args:
        foreach my $thisarg ( keys %args ) {
            if ( ref( $args{$thisarg} ) eq 'ARRAY' ) {
                $self->$thisarg( @{ $args{$thisarg} } );
            }
            else {
                $self->$thisarg( $args{$thisarg} );
            }
        }
        my $expect_rows = $self->expect_rows || 'many'; # default is many

        # prepare record (encode):
        $self->encode_record;
        last EXIT if $self->status;

        ### create sqltext
        # where clause:
        # special conditions NULL/NOT NULL:
        my %sqlstring_for = (
            'not null' => ' is NOT NULL ',
            'null'     => ' is NULL ',
        );
        my ( @where_conditions, $data_found );
        my %has_id_set;
        my @all_columns = $self->columns;
        foreach my $thiscolumn ( @all_columns ) {
            my $intdata = $self->column($thiscolumn)->intdata;
            if ( defined $intdata ) {
                $data_found++;
                if ( my $txt = $sqlstring_for{ lc $intdata } ){
                    push @where_conditions, $thiscolumn . $txt;
                }
                else {
                    # ToDo: other operators than hardcoded '=':
                    push @where_conditions, $thiscolumn . ' = '
                        . $apiis->DataBase->dbh->quote($intdata);
                }
            }
            else {
                my ($extdata) = $self->column($thiscolumn)->extdata;
                if ( defined $extdata ) {
                    if ( my $txt = $sqlstring_for{ lc $extdata } ) {
                        push @where_conditions, $thiscolumn . $txt;
                        $data_found++;
                    }
                }
            }
            if ( $apiis->Compat->get('id_set') ) {
                my $id_set = $self->column($thiscolumn)->id_set;
                $has_id_set{$thiscolumn} = $id_set if $id_set;
            }
        }

        my @errors;
        if ($data_found) {
            ### create and execute sqltext:
            # by default, use the entry_view, if it exists for a table. But there
            # must be a way, to circumvent it (later):
            # my $query_table =
            #     $apiis->entry_views->{$self->tablename} || $self->tablename;
            # Note:
            # default changed: values from inside the database should access the
            # tables, not the entry views. The entry views are only for external
            # data from the outside (insert, update), which should only work on
            # active records ( reference: Eildert, 2006-1-25).
            my $query_table = $self->tablename;

            my @retrieve_cols;
            my @exp_cols = $self->expect_columns;
            if ( @exp_cols ) {
                my %tmp_hash;
                $tmp_hash{$_} = 1 for @exp_cols;
                # add oid by default unless selected in expect_columns:
                push @retrieve_cols, $apiis->DataBase->rowid
                    if not exists $tmp_hash{ $apiis->DataBase->rowid };
                push @retrieve_cols, @exp_cols;
            }
            else {
                my %tmp_hash;
                $tmp_hash{$_} = 1 for @all_columns;
                push @retrieve_cols, $apiis->DataBase->rowid
                    if not exists $tmp_hash{ $apiis->DataBase->rowid };
                push @retrieve_cols, @all_columns;
            }

            my $sqltext = sprintf "SELECT %s FROM %s where %s",
                join( ',', @retrieve_cols ), $query_table,
                join( ' AND ', @where_conditions );

            # order by:
            if ( $order_by_ref ){
                my @order_string;
                for my $o_col (@$order_by_ref) {
                    if ( ref $o_col ne 'HASH' ) {
                        $self->status(1);
                        $self->errors(
                            Apiis::Errors->new(
                                type     => 'PARAM',
                                severity => 'ERR',
                                from => 'Apiis::DataBase::Record::Fetch::fetch',
                                msg_short => 'Wrong parameter type passed',
                                msg_long =>
                                    'the elements of the order_by arrayref must be hashrefs',
                            )
                        );
                        last EXIT;
                    }
                    push @order_string,
                        $o_col->{column} . q{ } . ( $o_col->{order} || 'asc' );
                }

                if (@order_string) {
                    $sqltext .= q{ order by } . join( q{,}, @order_string );
                }
            }

            # now prepare and run the sql statement:
            # Note: not quite clear if fetch should be run by 'system' or
            # $apiis->User->id:
            my %sql_options;
            $sql_options{statement} = $sqltext;
            $sql_options{user} = $sql_user if $sql_user;

            my $fetched = $apiis->DataBase->sql( \%sql_options );
            if ( $fetched->status ) {
                $self->errors( scalar $fetched->errors );
                $self->status(1);
                last EXIT;
            }

            # handle results of successful query:
            my $count = 0;
            while ( my $row_ref = $fetched->handle->fetch ) {
                $count++;
                if ( $count > 1 and $expect_rows eq 'one' ) {
                    $self->status(1);
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DATA',
                            severity  => 'ERR',
                            msg_short =>
                                __('One record expected and many retrieved'),
                            from => 'Apiis::DataBase::Record::Fetch::_fetch',
                            )
                    );
                    last EXIT;
                }

                # fill new record objects with the retrieved data:
                my @fetched_record = @$row_ref;
                my $record = Apiis::DataBase::Record->new(
                    tablename => $self->tablename
                );

                for (@retrieve_cols) {
                    $record->column($_)->intdata( shift @fetched_record );
                }
                push @return_array, $record;
            }
            $self->rows($count);

            # pass over the id_set definitions to the retrieved records:
            if ( my @id_set_cols = keys %has_id_set ) {
                for my $rec (@return_array) {
                    for my $col (@id_set_cols) {
                        $rec->column($col)->id_set( $has_id_set{$col} );
                    }
                }
            }
        }
        $apiis->log( 'debug', sprintf "%d records fetched from table %s",
            ( $self->rows || 0 ), $self->tablename
        );
    }    # end label EXIT
    $self->action($oldaction);
    return @return_array;
}

##############################################################################
1;

__END__

=head1 NAME

Fetch

=head1 SYNOPSIS

    # fill record with query data, then:
    $record_obj->fetch(
        expect_rows    => 'one',                   # ['one'|'many']
        expect_columns => qw/ db_sex db_breed/,    # all columns if absent
        order_by       => [                        # optional sorting
            { column => 'db_sex',   order => 'desc' },
            { column => 'db_breed', order => 'asc' },
        ],
        user => 'system',                          # optional for internal use
    );

Apiis::DataBase::Record::Fetch fetches the specified record(s), creates a
record object for each of them and returns an array of these objects.

=head1 DESCRIPTION

The query is created according to the already filled-in data in this record
object.

All columns of this record object, which contain data, build
'column=value'-pairs. The operator is currently only '=' and all data fields
are ANDed.

Special allowed values are 'null' and 'not null', which are reflected in the
resulting where clause. Both strings are case insensitive.

Example:

    $rec_obj->column('exit_dt')->extdata('not null');

or

    $rec_obj->column('db_breeder')->intdata('null');
    $rec_obj->column('db_breeder')->encoded(1);

The qualifiers I<expect_rows()> and I<expect_colums()> can either be
provided as methods to the record object or as hash parameters to fetch.

I<expect_rows()> can have the values 'one' and 'many'(default).

If I<expect_columns()> is omitted, all columns of the record are retrieved.
Every records also retrieves the rowid/oid.

Example:

    my $rec_obj = Apiis::DataBase::Record->new( tablename => 'codes' );
    $rec_obj->column('class')->extdata('BREED');
    my @query_objects = $rec_obj->fetch(
        expect_rows    => 'many',
        expect_columns => [qw/ db_code ext_code /],
        sort_by        => [ { column => 'ext_code', order => 'asc' } ],
    );

This query returns columns db_code and ext_code of all the records from codes,
where the BREED is coded. They are sorted by ext_code in ascending order.
The resulting rows are packed into separate record objects each and passed
back in an array of record objects.

$rec_obj->expect_rows('many') is default and can be omitted.

Another example:

    my $rec_obj = Apiis::DataBase::Record->new( tablename => 'animal' );

    # if you know the internal code:
    $rec_obj->column('db_animal')->intdata(8608);
    # you must set the encoded(1) flag for internal data:
    $rec_obj->column('db_animal')->encoded(1);

    # or, if you have the external data:
    $rec_obj->column('db_animal')->extdata( 'society|sex', '32|1', '63' );

    # now specify the query:
    $rec_obj->expect_columns(qw/ db_sex db_breed /);
    $rec_obj->expect_rows('one');
    $rec_obj->fetch;

If you provide the external data, it is encoded before the query is created:

   SELECT db_sex,db_breed from animal where db_animal = 8608;

If this results in more than one record (which should not happen), an error is
risen.

Note: If you don't want the record to get encoded (perhaps you provide
internal data anyway) you have to set $record->encoded(1), which will skip
encoding. In case of providing internal data without external one, leaving out
$record->encoded(1) will yield an error. During encoding, the internal
value will simply get deleted.

Ordering the query result can be done with:

    $record_obj->fetch(
        order_by => [
            { column => 'birth_dt', order => 'desc' },
            { column => 'parity',   order => 'asc' },
        ],
    );

B<order_by> expects an array reference of hash references. According to the
SQL standard, this query is sorted by column birth_dt in descending order and,
for equal values in birth_dt, by column parity in ascending order.

This makes mainly sense for columns without encoded values as the sorting
happens on the internal database values.

=cut
