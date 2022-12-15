##############################################################################
# $Id: Delete.pm,v 1.14 2014/12/08 08:56:55 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Delete;
$VERSION = '$Revision: 1.14 $';

use strict;
use warnings;
use Carp qw( croak );
use Data::Dumper;

use Apiis;
our $apiis;

sub _delete {
    my $self = shift;

    my ( $package, $filename, $line ) = caller;
    if ( $package ne 'Apiis::DataBase::Record' ) {
        croak __(
            "Method [_1] may only be invoked from package [_2], not from [_3]",
            'delete', 'Apiis::DataBase::Record', $package
        );
    }
    # tell the record object that we are now doing a delete:
    my $oldaction = $self->action('delete');

    EXIT: {

        # only requirement (besides auth()) is the existance of the rowid:
        my $rowid_name = $apiis->DataBase->rowid;
        my $rowid_value = $self->column( $rowid_name )->intdata;
        if ( !defined $rowid_value ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'CRIT',
                    from      => 'Apiis::DataBase::Record::delete',
                    msg_short => __(
                        "Delete requires a value for column[_1]", $rowid_name
                    ),
                )
            );
            last EXIT;
        }

        # authorization:
        $self->auth;
        last EXIT if $self->status;

        __check_FK_violation($self);
        last EXIT if $self->status;

        ### Check for PreDelete triggers
        $self->RunTrigger('predelete');
        last EXIT if $self->status;

        ### create sqltext
        my $sqltext = sprintf "DELETE FROM %s where %s = %s",
            $self->tablename,
            $apiis->DataBase->rowid,
            $apiis->DataBase->dbh->quote( $rowid_value );

        ### pass sqltext and check returned SQL-object:
        my $deleted = $apiis->DataBase->sql(
            {   statement => $sqltext,
                user      => 'system',
            }
        );
        if ( $deleted->status ) {
            $self->status(1);
            $self->errors( scalar $deleted->errors );
            last EXIT;
        }
        $self->rows( $deleted->rows );

        ### check for PostDelete triggers
        $self->RunTrigger('postdelete');
        last EXIT if $self->status;

        # some logging about the results:
        $apiis->log( 'info', sprintf "delete: %s record deleted from table %s",
            $deleted->rows, $self->tablename );
    } # end label EXIT

    # reset the action type:
    $self->action($oldaction);
    return;
}

##############################################################################
# check if this record is a parent in an ForeignKey-tree:
# (internal subroutine, no public method!)
sub __check_FK_violation {
    my $self = shift;

    # create internal structure for FK-references:
    $apiis->Model->build_fk_struct();

    # get all data for this record; use new record_obj to search only for guid:
    my $rowid_name = $apiis->DataBase->rowid;
    my $f_rec = Apiis::DataBase::Record->new( tablename => $self->tablename );
    $f_rec->column($rowid_name)->intdata( $self->column($rowid_name)->intdata );
    my @q_records = $f_rec->fetch( user => 'system' );
    my $full_rec = shift @q_records;    # only one due to unique guid
    if ( !$full_rec ) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'DATA',
                severity  => 'CRIT',
                db_table  => $self->tablename,
                db_column => $rowid_name,
                from      => 'Apiis::DataBase::Record::delete',
                msg_short => __(
                    "No record found for [_1]: [_2]",
                    $rowid_name, $self->column($rowid_name)->intdata
                ),
            )
        );
        return;
    }

    # now search if FK value is used:
    my %violations;
    FK_COL:
    for my $thiscol ( $full_rec->columns ) {
        my $fk_struct =
            $apiis->Model->has_fk_from(
            { table => $full_rec->tablename, column => $thiscol, } );
        next FK_COL if !$fk_struct;

        my $intdata = $full_rec->column($thiscol)->intdata;
        next FK_COL if !defined $intdata;    # columns with NULL ignored

        # start the expensive process of checking, if this FK-value is used:
        for my $entry (@$fk_struct) {
            my ( $leaf_table, $leaf_col ) = @$entry;
            my $sql = sprintf 'select count(*) from %s where %s = %s',
                $leaf_table, $leaf_col, $apiis->DataBase->dbh->quote($intdata);
            my $sql_ref = $apiis->DataBase->sys_sql($sql);
            $sql_ref->check_status;
            my $sth = $sql_ref->handle;
            my $count;
            while ( my @row = $sth->fetchrow_array ) {
                $count += shift @row;
            }
            if ($count) {
                push @{ $violations{$thiscol} },
                    [ $leaf_table, $leaf_col, $count ];
            }
        }
    }

    if ( keys %violations ) {
        $self->status(1);
        # one Error for each column
        for my $viol_col ( keys %violations ) {
            my $err_id = $self->errors(
                Apiis::Errors->new(
                    type      => 'AUTH',
                    severity  => 'CRIT',
                    db_table  => $self->tablename,
                    db_column => $viol_col,
                    from      => 'Apiis::DataBase::Record::delete',
                    msg_short => __(
                        "You must not delete records with Foreign Key definitions"
                    ),
                )
            );

            # several entries (tables) for one column possible:
            my $long_text = "referenced by\n";
            for my $entry ( @{ $violations{$viol_col} } ) {
                $long_text .= sprintf "%s.%s (%sx)\n",
                    $entry->[0], $entry->[1], $entry->[2];
            }
            $self->error($err_id)->msg_long($long_text);
            my $ext_fields_ref = $self->column($viol_col)->ext_fields;
            $self->error($err_id)->ext_fields($ext_fields_ref)
                if $ext_fields_ref;
        }
    }
    return;
}
##############################################################################
1;
