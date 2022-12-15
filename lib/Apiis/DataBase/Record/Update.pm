##############################################################################
# $Id: Update.pm,v 1.30 2006/12/01 08:48:52 heli Exp $
##############################################################################
##############################################################################
package Apiis::DataBase::Record::Update;
$VERSION = '$Revision: 1.30 $';

use strict;
use warnings;
use Apiis::Init;
our $apiis;

sub _update {
    my $self = shift;

    my $oldaction = $self->action('update');    # we are now doing an update:
    my %changed_data;
    my $debug = 1
        if $apiis->syslog_priority  eq 'debug'
        or $apiis->filelog_priority eq 'debug';

    EXIT: {
        if ($debug) {
            $apiis->log( 'debug', '_update: starting Record object update.' );
        }

        # is Record mirrored and has it changed?:
        if ( $self->mirrored and !$self->mirror_differs ) {
            if ($debug) {
                $apiis->log( 'debug',
                    '_update: skipped as Record mirrored and not modified' );
            }
            last EXIT;    # nothing to update
        }
        
        # modify:
        $self->modify_record;
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug', '_update: record successfully modified' );
        }

        # encode changes:
        $self->encode_record;
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug', '_update: record successfully encoded' );
        }

        # check, if rowid/guid is set:
        my $rowid_name  = $apiis->DataBase->rowid;
        my $rowid_value = $self->column($rowid_name)->intdata;
        if ( not $rowid_value ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::DataBase::Record::Update::_update',
                    action    => $self->action,
                    db_table  => $self->tablename,
                    msg_short => __('Programming error'),
                    msg_long  => __(
                        "Cannot update record without column '[_1]'",
                        $apiis->DataBase->rowid
                    ),
                )
            );
            last EXIT;
        }

        # fetch complete record by rowid for check() and updated()-flags:
        my $tablename   = $self->tablename;
        my $query_rec =
            Apiis::DataBase::Record->new( tablename => $tablename );

        # put rowid also into extdata, or encode_record will set
        # intdata to undef:
        $query_rec->column($rowid_name)->intdata($rowid_value);
        $query_rec->column($rowid_name)->extdata($rowid_value);
        $query_rec->column($rowid_name)->encoded(1);

        # fetch record as user system to get complete record even if
        # user schema provides only limited set.
        my ($complete_rec) = $query_rec->fetch(
            expect_rows => 'one',
            user        => 'system',
        );
        if ( $query_rec->status ) {
            $self->errors( scalar $query_rec->errors );
            $self->status(1);
            last EXIT;
        }
        # no record returned (is this an error? According to Ulf - yes):
        if ( !$complete_rec ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type     => 'DATA',
                    severity => 'ERR',
                    from     => 'Apiis::DataBase::Record::Update::_update',
                    action   => $self->action,
                    db_table => $self->tablename,
                    data     => $rowid_value,
                    msg_long => __(
                        'Cannot retrieve a record with the provided [_1]',
                        $apiis->DataBase->rowid),
                )
            );
            last EXIT;
        }

        my $do_update = 0;
        for my $thiscol ( $complete_rec->columns ) {
            # compare old and new data and set updated() flag:
            my $olddata = $complete_rec->column($thiscol)->intdata;
            my $newdata = $self->column($thiscol)->intdata;
            if ( defined $newdata ) {
                if ( defined $olddata ) {
                    if ( $newdata eq $olddata ) {
                        $self->column($thiscol)->updated(0);
                    }
                    else {
                        $self->column($thiscol)->updated(1);
                        $do_update++;
                        $changed_data{$thiscol} = $olddata;
                    }
                }
                else {
                    if ( $newdata eq q{} ) {
                        # empty strings is handled as NULL:
                        $self->column($thiscol)->updated(0);
                    }
                    else {
                        $self->column($thiscol)->updated(1);
                        $do_update++;
                        $changed_data{$thiscol} = $olddata;
                    }
                }
            }
            else {
                # after successful encoding, intdata should have a value:
                my $extdata_ref = $self->column($thiscol)->extdata;
                if ($extdata_ref) {
                    # if we have only one element, and this is undef:
                    if (scalar @$extdata_ref == 1
                        and ( !defined $extdata_ref->[0]
                            or $extdata_ref->[0] eq q{} )
                        )
                    {
                        if ( defined $olddata ) {
                            $self->column($thiscol)->updated(1);
                            $do_update++;
                            $changed_data{$thiscol} = $olddata;
                        }
                        else {
                            $self->column($thiscol)->updated(0);
                        }
                    }
                }
                else {
                    # Note: we have to copy $olddata into the record object for
                    # those fields, which are not touched by update but are
                    # needed for check():
                    $self->column($thiscol)->intdata($olddata);
                    $self->column($thiscol)->updated(0);
                    $self->column($thiscol)->encoded(1);
                }
            }
        }

        if ( !$do_update ) {
            $apiis->log( 'info',
                sprintf "_update: nothing to update in table '%s', %s %d",
                $tablename, $rowid_name, $rowid_value );
            $self->rows(0);
            last EXIT;
        }

        ### PreUpdate triggers
        $self->RunTrigger('preupdate');
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug',
                '_update: PreUpdate triggers in record successfully handled' );
        }

        # we need to re-encode the data in case some trigger changed it:
        if ( !$self->encoded ) {
            if ($debug) {
                $apiis->log( 'debug',
                    '_update: going to re-encode record due to trigger changes'
                );
            }
            $self->encode_record;
            last EXIT if $self->status;
            if ($debug) {
                $apiis->log( 'debug',
                    '_update: record successfully re-encoded' );
            }
        }

        $self->check_record;
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug', '_update: record successfully checked' );
        }

        # authorization:
        $self->auth();
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug',
                '_update: record successfully authenticated' );
        }

        ### create sqltext
        my ( @col_name, @col_val );
        my @set_lines;
        foreach my $thiscolumn ( $self->columns ) {
            my $intdata = $self->column($thiscolumn)->intdata;
            if ( $self->column($thiscolumn)->updated ) {
                if ( defined $intdata and $intdata ne q{} ) {
                    push @set_lines, $thiscolumn . ' = '
                        . $apiis->DataBase->dbh->quote($intdata);
                }
                else {
                    # undef and empty string q{} are converted to NULL:
                    push @set_lines, $thiscolumn . ' = NULL';
                }
            }
        }

        my $sqltext = sprintf "UPDATE %s SET %s WHERE %s = %s", $tablename,
            join( ', ', @set_lines ), $rowid_name,
            $apiis->DataBase->dbh->quote( $self->column($rowid_name)->intdata );

        ### execute sql:
        my $updated = $apiis->DataBase->sql(
            {   statement => $sqltext,
                user      => 'system',
            }
        );
        if ( $updated->status ) {
            $self->status(1);
            $self->errors( scalar $updated->errors );
        }
        else {
            $self->rows( $updated->rows );

            # re-mirror data if column was mirrored:
            $self->mirror_record if $self->mirrored;

            # do we have memcached running?:
            my ( $memcache, $db_name );
            if ( $apiis->Cache->hasMemcached() ) {
                $db_name = $apiis->Model->db_name;
                $memcache = $apiis->Cache->memcache();
            }

            CLEANUP:
            for my $thiscolumn ( $self->columns ) {
                if ( $self->column($thiscolumn)->updated() ) {
                    # reset the updated flag if record object stays in use:
                    $self->column($thiscolumn)->updated(0);

                    next CLEANUP if !$memcache;
                    next CLEANUP if !exists $changed_data{$thiscolumn};

                    # delete changed entry from cache (decode):
                    my $old_int_data = $changed_data{$thiscolumn};
                    my $new_int_data = $self->column($thiscolumn)->intdata;

                    DEL_CACHE:
                    for my $data ( $old_int_data, $new_int_data ) {
                        next DEL_CACHE if !defined $data;
                        next DEL_CACHE if $data eq '';
                        $data =~ tr/ /_/;    # change blank to underscore
                        my @memkeys = (
                            'decode', $db_name, $tablename, $thiscolumn, $data
                        );
                        my $mem_key = join( '::', @memkeys );
                        $memcache->delete($mem_key);
                        # $apiis->log( 'info',
                        #     sprintf "%s Deleted key %s from memcached",
                        #     'Update', $mem_key, );
                    }
                }
            }
        }

        ### PostUpdate triggers
        $self->RunTrigger('postupdate');
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug',
                '_update: PostUpdate triggers successfully handled' );
        }

        # reset the record action type:
        $self->action($oldaction);

        if ($debug) {
            $apiis->log( 'debug', '_update: update on Record finished.' );
        }
    }
    return $self;
}


##############################################################################
1;

