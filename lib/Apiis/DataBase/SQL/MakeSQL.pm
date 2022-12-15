##############################################################################
# $Id: MakeSQL.pm,v 1.18 2020/11/03 19:01:43 ulf Exp $
##############################################################################

use strict;
use warnings;
use List::Util qw( first );

=head1 NAME

Apiis::DataBase::MakeSQL Module to create SQL-statements from the model file

=head1 DESCRIPTION

B<MakeSQL> as the main method and some auxiliary routines read the Apiis model
file and create a file with SQL data definition commands to create tables,
views, indices, sequences, etc.

The resulting file will either be written to STDOUT or placed in the
var-subdirectory of the given project. Its name is created from the project
name with database driver and .sql extension appended:

   <project>_<db_driver>.sql
   breedprg_Pg.sql

=head1 METHODS

Besides the main method B<MakeSQL> there are the auxiliary methods
B<Cascaded_FK>, B<resolve_concatenations>, and B<HasFKRule>.

Read 'perldoc $APIIS_HOME/bin/mksql' for the most prominent implementation and
for detailed usage information.

=cut

sub MakeSQL {
    my ($args_ref) = @_;
    my $only_table = $args_ref->{'-t'} if defined $args_ref->{'-t'};
    my $do_delete  = $args_ref->{-d}   if defined $args_ref->{-d};
    my $do_views   = 1;
    $do_views = 0 if defined $args_ref->{-n};
    my $write_stdout = $args_ref->{-s}   if defined $args_ref->{-s};

    # use Text::ParseWords;

    use vars qw/ $tab_alias %tab_trans %tmp_hash
        @join_tables_pre @join_alias_pre @join_cols_pre
        @join_tables_post @join_alias_post @join_cols_post
        /;

    # defaults:
    my $comment     = '-- ';
    my $dropcomment = $comment;
    $dropcomment = '' if $do_delete;
    my $with_comments = 1;
    my $csv           = 0;

    if ( $apiis->Model->db_driver eq 'CSV' ) {    # for CSV 'database'
        $csv           = 1;
        $with_comments = 0;
    }
    if ( $apiis->Model->db_driver eq 'InterBase' ) {    # for InterBase
        $with_comments = 0;
    }

    # read table names from the model file:
    my @tables = $apiis->Model->tables;

    # for each table of this model:
    my ( $create, $columns, @sql_arr, $create_view, @pk_views, %pk_index );
    TABLE:
    for my $tab (@tables) {
        next TABLE if defined $only_table and $only_table ne $tab;
        my $table = $apiis->Model->table($tab);

        my ( $create_indices, @sequences, $create_sequences );
        $columns = scalar @{ $table->cols };    # get number of columns

        $create .= "${dropcomment}DROP TABLE $tab;\n"
            if $with_comments
            or $dropcomment eq '';
        $create .= "CREATE TABLE $tab (\n";

        # first get max length of textparts to beautify the output:
        my $max_db_column = 0;
        my $max_datatype  = 0;
        my @table_columns = $table->cols;
        for my $col (@table_columns) {
            my $meta_datatype = $table->datatype($col);
            my $len_md = length( $apiis->DataBase->datatypes($meta_datatype) );
            $max_db_column = length($col) if length($col) > $max_db_column;
            $max_datatype = $len_md if $len_md > $max_datatype;
        }
        $max_db_column += 2;    # add to max length
        $max_datatype  += 2;

        # some view preparations:
        my ( @view_selects, @left_outer_joins );
        $tab_alias = 'a';
        $tab_trans{$tab} = $tab_alias;
        if ($do_views) {
            $create_view .= "${dropcomment}DROP VIEW v_$tab;\n"
                if $with_comments or $dropcomment eq '';
            $create_view .= "CREATE VIEW v_$tab AS\nSELECT ";

            # add view column for oid (  $apiis->DataBase->rowid ) of driving table:
            push @view_selects,
                "$tab_trans{$tab}" . '.'
                . $apiis->DataBase->rowid
                . ' AS v_'
                . $apiis->DataBase->rowid;
        }

        # Getting the information from 'TABLE' key
        # primary key definitions and views:
        if ( $table->primarykey('ref_col') ) {
            # create special FK-view if defined:
            my $thisview = $table->primarykey('view');
            if ( $thisview ) {
                # do we have a table with this name?:
                if ( first { $_ eq $thisview } @tables ) {
                    die sprintf
                        "Can't create view %s! Table with same name defined.\n",
                        $thisview;
                }

                push @pk_views, sprintf '%sDROP VIEW %s;',
                    $dropcomment, $thisview
                    if $with_comments or $dropcomment eq '';
                push @pk_views, sprintf 'CREATE VIEW %s AS', $thisview;

                my @tmp_arr;
                push @tmp_arr, $table->cols;
                my $myrowid = $apiis->DataBase->rowid;
                push @tmp_arr, $myrowid unless ( grep /^$myrowid$/, @tmp_arr );

                my $where_clause = '';
                $where_clause = sprintf "\nWHERE       %s",
                    $table->primarykey('where') if $table->primarykey('where');
                push @pk_views, sprintf "SELECT      %s\nFROM        %s;\n",
                    join( ', ', @tmp_arr ), $tab . $where_clause;
            }

            # create also a unique index for each PK:
            my $index_name = 'uidx_pk_' . $tab;
            if ( exists $pk_index{$index_name} ) {
                warn "Multiple primary keys defined for table $tab!\n";
            }
            else {
                # take a hash %pk_index to prevent duplication of indices:
                push @{ $pk_index{$index_name} },
                    "${dropcomment}DROP INDEX  $index_name;"
                    if $with_comments or $dropcomment eq '';
                my $index_string =
                    sprintf 'CREATE UNIQUE INDEX %s ON %s ( %s )', $index_name,
                    $tab, join( ', ', @{ $table->primarykey('ext_cols') } );

                # conditional index works only for PostgreSQL >= 7.2
                $index_string .= "\nWHERE " . $table->primarykey('where')
                    if $table->primarykey('where');
                $index_string .= ";\n";
                push @{ $pk_index{$index_name} }, $index_string;
            }
        }    # end PRIMARYKEY

        my @indices = $table->indices if $table->indices;
        if ( scalar @indices ) {
            my $i = 1;
            foreach (@indices) {
                my @idx = split;    # split each index into its parts
                my $unique;
                $idx[0] =~ /unique/i
                    ? ( $unique = uc shift @idx )
                    : ( $unique = '' );
                my $idx_name;
                $unique
                    ? ( $idx_name = "uidx_${tab}_$i" )
                    : ( $idx_name = "idx_${tab}_$i" );
                $create_indices .= "${dropcomment}DROP INDEX $idx_name;\n"
                    if $with_comments or $dropcomment eq '';
                $create_indices
                    .= "CREATE $unique INDEX $idx_name ON $tab ( "
                    . join( ', ', @idx ) . " );\n";
                $i++;
            }
        }
        my @tab_sequences = $table->sequences if $table->sequences;
        if ( scalar @tab_sequences ) {
            foreach (@tab_sequences) {
                $create_sequences .= "${dropcomment}DROP SEQUENCE $_;\n"
                    if $with_comments or $dropcomment eq '';
                $create_sequences .= "CREATE SEQUENCE $_;\n";
            }
        }

        foreach my $col (@table_columns) {
            my $db_column = $col;
            $tmp_hash{ ${tab} . ${db_column} }++;

            # change META datatype into db_specific in one step:
            my $datatype =
                $apiis->DataBase->datatypes( lc $table->datatype($col) );

            $create .= "   $db_column"
                . ' ' x ( $max_db_column - length($db_column) );
            $create .= "$datatype";
            $columns > 1 ? ( $create .= "," ) : ( $create .= " " );
            $create .= ' ' x ( $max_datatype - length($datatype) );

            # replacing new line characters in description with spaces
            my $descr = $table->description($col);
            if ($descr) {
                $descr =~ s/\n/ /g;
                $create .= "${comment}" . $descr if $with_comments;
            }
            $create .= "\n";
            $columns--;

            # views:
            push @view_selects, "$tab_trans{$tab}.${db_column}";

            # create additional column in view for FK-external values:
            # get ForeignKey rules:
            my ( $fk_table, $fk_col ) = HasFKRule( $tab, $col );

            # is there a cascaded chain of FK rules?:
            # jetzt hier:
            if ( $fk_table and $fk_col ) {
                ( $fk_table, $fk_col ) = Cascaded_FK( $fk_table, $fk_col );
            }

            if ( $fk_table and $fk_col ) {    # FK exists
                # temp arrays to solve concatenated primary keys
                my ( @fk_tables, @fk_cols, @table_aliases );
                push @fk_tables, $fk_table;
                push @fk_cols,   $fk_col;

                # $DB::single = 1; # set breakpoint for debugger
                $tab_trans{$fk_table} = ++$tab_alias
                    if !exists $tab_trans{$fk_table};

                # (re)initialize:
                @join_tables_pre  = ($tab);
                @join_alias_pre   = ( $tab_trans{$tab} );
                @join_cols_pre    = ($db_column);
                @join_tables_post = ($fk_table);
                @join_alias_post  = ( $tab_trans{$fk_table} );
                @join_cols_post   = ($fk_col);

                my $new_db_col = $db_column;
                $new_db_col =~ s/^db_/ext_/i;
                $new_db_col = 'ext_' . $new_db_col
                    unless ( $new_db_col =~ /^ext_/i );
                push @table_aliases, $tab_trans{$fk_table};

                # pass parameters as array references for allowing to add
                # tables via recursion:
                resolve_concatenations( \@fk_tables, \@fk_cols,
                    \@table_aliases )
                    if !( $fk_table eq $apiis->codes_table );

                # this is an ugly hardcoded hack:
                # the codes_table (usually codes) is known to have no deeper
                # dependencies to other tables. But what happens, if this
                # changes somewhen/somewhere? :^( I use it to prevent a
                # db_sex solving as: SEX >=< 1 The column class from codes is
                # not needed to solve the foreign key.
                my $delimiter = ${ $apiis->reserved_strings }{v_concat};
                for ( my $i = 0; $i <= $#fk_cols; $i++ ) {
                    # if the $fk_col starts with db_ (e.g. db_code) take the
                    # corresponding ext_ column. A bit clumsy as it depends on
                    # naming conventions, but ...
                    
                    #-- mue if there are connections like ForeignKey -> ForeignKey
                    #-- db_ to ext_ is not runing because only in codes and unit are "ext_"-fields
                    #-- that's why replacing only if this to tables in use.
                    
                    if (($fk_tables[$i] eq 'codes') or ($fk_tables[$i] eq 'units') or ($fk_tables[$i] eq 'transfer')) {
                        $fk_cols[$i] =~ s/^db_/ext_/;
                    }
                    
                    $fk_cols[$i] = $table_aliases[$i] . '.' . $fk_cols[$i];
                }
                push @view_selects,
                    join( " || '$delimiter' || ", @fk_cols )
                    . " AS $new_db_col";

                if ($do_views) {
                    for ( my $i = 0; $i <= $#join_tables_pre; $i++ ) {
                        push @left_outer_joins,
                            sprintf 'LEFT OUTER JOIN %s %s ON %s.%s = %s.%s',
                            $join_tables_post[$i],
                            $tab_trans{ $join_tables_post[$i] },
                            $join_alias_pre[$i], $join_cols_pre[$i],
                            $tab_trans{ $join_tables_post[$i] },
                            $join_cols_post[$i];
                    }
                }
            }    # end FK exists
        }    # end each $col of this $tab

        $csv ? ( $create .= ")\n" ) : ( $create .= ");\n" );
        push @sql_arr, $create if $create;
        $create = '';
        foreach ( keys %pk_index ) {
            push @sql_arr, @{ $pk_index{$_} };
            delete $pk_index{$_};
        }
        push @sql_arr, $create_indices if $create_indices and not $csv;

        # create unique index for rowid in each table
        ## for faster update in check_integrity
        unless ($csv) {
            my $create_rowid_indices =
                "${dropcomment}DROP INDEX uidx_${tab}_rowid;\n"
                if $with_comments
                or $dropcomment eq '';
            $create_rowid_indices
                .= "CREATE UNIQUE INDEX uidx_${tab}_rowid ON $tab ( "
                . $apiis->DataBase->rowid . " );\n";
            push @sql_arr, $create_rowid_indices;
        }

        if ($do_views) {
            $create_view .= join( ",\n       ", @view_selects );
            # A self-referencing FK makes $tab_trans{$table} overwrite the
            # alias. We have to hardcode it in the FROM-clause:
            # $create_view .= "\nFROM $tab $tab_trans{$tab}";
            $create_view .= "\nFROM $tab a";
            my $tmp_count  = 0;
            my $thislength = length("FROM $tab x");
            while (@left_outer_joins) {
                if ($tmp_count) {
                    $create_view
                        .= "\n"
                        . ' ' x $thislength . ' '
                        . shift @left_outer_joins;
                }
                else {
                    $create_view .= ' ' . shift @left_outer_joins;
                    $tmp_count++;
                }
            }
            $create_view .= ";\n\n";
        }

        push @sql_arr, $create_sequences if $create_sequences and not $csv;
    };    # end TABLE loop

    # view must wait for creation of all tables:
    push @sql_arr, $create_view if $create_view and not $csv;
    push @sql_arr, @pk_views    if @pk_views    and not $csv;

    if ($write_stdout) {
        print STDOUT join( "\n", @sql_arr ) if scalar @sql_arr;
        print STDOUT "\n";
    }
    else {
        my $extension = '.sql';
        my $filename =
              $apiis->APIIS_LOCAL . "/var/"
            . $apiis->Model->basename . "_"
            . $apiis->Model->db_driver
            . $extension;

        open my $SQL, '>', $filename
            or die __( 'Problems opening file [_1]: [_2]', $filename, $! )
            . "\n";
        print $SQL join( "\n", @sql_arr ) if scalar @sql_arr;
        print $SQL "\n";
        close $SQL;
    }
}

##############################################################################
# Check recursively if the ForeignKey points to a FK by itself.
# input:  1. foreign key table
#         2. foreign key column (i.e. DB_COLUMN)
# output: 1. last element (table) of the foreign key chain
#         2. dito (column)
# uses some global vars. :^(

sub Cascaded_FK {
    my ( $tab, $db_col ) = @_;
    if ($db_col) {
        my ( $fk_table, $fk_col ) = HasFKRule( $tab, $db_col );
        if ( $fk_table and $fk_col ) {
            $tab_trans{$tab} = ++$tab_alias unless exists $tab_trans{$tab};
            $tab_trans{$fk_table} = ++$tab_alias
                unless exists $tab_trans{$fk_table};
            push @join_tables_pre,  $tab;
            push @join_alias_pre,   $tab_trans{$tab};
            push @join_cols_pre,    $db_col;
            push @join_tables_post, $fk_table;
            push @join_alias_post,  $tab_trans{$fk_table};
            push @join_cols_post,   $fk_col;

            # recursion if again an FK rule exists:
            ( $fk_table, $fk_col ) = Cascaded_FK( $fk_table, $fk_col );
            return ( $fk_table, $fk_col );
        }
    }
    return ( $tab, $db_col );
}

##############################################################################
# resolve concatenated primary key.
# input is a list of references to the tables, columns and table-aliases.
# Although this starts with only one entry (a scalar would be enough there) it
# increments during solving the concatenations. Therefore arrays.  no output,
# the references are used in main.
sub resolve_concatenations {
    my ( $tables_ref, $cols_ref, $aliases_ref ) = @_;
    my $has_concat_pk;    # set flag for recursion

    for ( my $i = 0 ; $i <= $#$tables_ref ; $i++ ) {

        # check for foreign keys again in these concatenated cols:
        ( $tables_ref->[$i], $cols_ref->[$i] ) =
          Cascaded_FK( $tables_ref->[$i], $cols_ref->[$i] );
        my $table = $apiis->Model->table( $tables_ref->[$i] );

        if (    $table->primarykey('ref_col')
            and $table->primarykey('ref_col') eq $cols_ref->[$i]
            and scalar @{ $table->primarykey('ext_cols') } )
        {

            $has_concat_pk = 1;    # set global flag for recursion

            # replace the REF_COL with the CONCAT cols in @$cols_ref:
            splice @$cols_ref, $i, 1, @{ $table->primarykey('ext_cols') };
            for ( 1 .. $#{ $table->primarykey('ext_cols') } ) {
                # shoot another entry for each additional col in CONCAT into
                # @$tables_ref and also @$aliases_ref:
                splice @$tables_ref,  $i, 0, $tables_ref->[$i];
                splice @$aliases_ref, $i, 0, 'dummy';
            }
        }
        if ($has_concat_pk) {
            $has_concat_pk = 0;

            # recursion until all concatenated PKs are solved.
            resolve_concatenations( $tables_ref, $cols_ref, $aliases_ref );
        }
        else {
            $tab_trans{ $tables_ref->[$i] } = ++$tab_alias
              unless exists $tab_trans{ $tables_ref->[$i] };
            $aliases_ref->[$i] = $tab_trans{ $tables_ref->[$i] };
        }
    }
}

##############################################################################
# check if column $col in table $tab has a ForeignKey rule
# return a list with the foreign key table $fk_table and the according
# column $fk_col (empty list if no FK rule exists).
# uses some global vars. :^(
sub HasFKRule {
    my ( $tab, $col ) = @_;
    my ( $return_fk_table, $return_fk_col );
    my $table = $apiis->Model->table($tab);
    my ( $fk_table, $fk_col ) = $table->foreignkey($col);
    if ( $fk_table and $fk_col ) {
        my $newtable = $apiis->Model->table($fk_table);
        if ( $newtable->foreignkey($fk_col) ) {
            $return_fk_table      = $fk_table;
            $return_fk_col        = $fk_col;
            $tab_trans{$fk_table} = ++$tab_alias
                if $tmp_hash{ ${fk_table} . ${fk_col} }++;
        }
        else {
            # if there is only a simple primary key in $fk_table on $fk_col
            # without concatenations, we don't need this column in the view:
            if (    $newtable->primarykey('ref_col')
                and $newtable->primarykey('ref_col') eq $fk_col )
            {
                if ( $newtable->primarykey('ext_cols') ) {
                    # increment the table alias for duplicate table.column entries:
                    $tab_trans{$fk_table} = ++$tab_alias
                        if $tmp_hash{ ${fk_table} . ${fk_col} }++;
                    $return_fk_table = $fk_table;
                    $return_fk_col   = $fk_col;
                }
            }
        }
        # increment the table alias for duplicate table.column entries:
        # $tab_trans{$fk_table} = ++$tab_alias if $tmp_hash{ ${fk_table} . ${fk_col} }++;
    }
    return ( $return_fk_table, $return_fk_col );
}

##############################################################################
1; # don't remove the truth!

