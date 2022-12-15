##############################################################################
# $Id: Insert.pm,v 1.28 2014/12/08 08:56:55 heli Exp $
##############################################################################
##############################################################################
package Apiis::DataBase::Record::Insert;
$VERSION = '$Revision: 1.28 $';

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Apiis::Init;
our $apiis;

sub _insert {
    my $self = shift;

    # tell the record object that we are now doing an insert:
    my $oldaction = $self->action('insert');
    my $debug     = 1
        if $apiis->syslog_priority  eq 'debug'
        or $apiis->filelog_priority eq 'debug';

    if ($debug) {
        $apiis->log( 'debug', '_insert: starting insert of record object' );
    }

    EXIT: {
        # Note to the flow of execution:
        # 1. modify_record() to make modifications like UpperCase, which
        #    could be important for encoding. modify_record only takes place
        #    on extdata!
        # 2. encode_record() prepares all extdata and fills intdata,
        #    even the ones, which don't need any encoding. They are
        #    simply copied.
        # 3. PreInsert triggers are fired then.
        # 4. After running the PreInsert triggers, the record gets again encoded
        #    in case of changes made by the triggers.
        # 5. check_record() then checks intdata (not extdata!).
        # 6. auth() makes authentication and authorisation
        # 7. the record will be inserted
        # 8. PostInsert triggers are fired.

        # modify:
        $self->modify_record;
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug', '_insert: record successfully modified' );
        }

        # encode:
        $self->encode_record;
        # last EXIT if $self->status;  # debugg
        if ($debug) {
            $apiis->log( 'debug', '_insert: record successfully encoded' );
        }

        ### Check for PreInsert triggers
        if ($debug) {
            $apiis->log( 'debug',
                '_insert: going to fire preinsert trigger ...' );
        }
        $self->RunTrigger('preinsert');
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug',
                '_insert: PreInsert triggers in record successfully handled' );
        }

        # we need to re-encode the data in case some trigger changed it:
        if ( !$self->encoded ) {
            if ($debug) {
                $apiis->log( 'debug',
                    '_insert: going to re-encode record due to trigger changes'
                );
            }
            $self->encode_record;
            last EXIT if $self->status;
            if ($debug) {
                $apiis->log( 'debug',
                    '_insert: record successfully re-encoded' );
            }
        }

        ### CheckRules with error handling
        $self->check_record;
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug', '_insert: record successfully checked' );
        }

        # authentication:
        $self->auth();
        last EXIT if $self->status;
        if ($debug) {
            $apiis->log( 'debug',
                '_insert: record successfully authenticated' );
        }

        ### create sqltext
        my ( @col_name, @col_val, $found );
        foreach my $thiscolumn ( $self->columns ) {
            my $thisval = $self->column($thiscolumn)->intdata;
            if ( defined $thisval ) {
                $found++;
                push @col_name, $thiscolumn;
                if ( $thisval eq '' ) {
                    push @col_val, 'NULL';
                }
                else {
                    push @col_val, $apiis->DataBase->dbh->quote($thisval);
                }
            }
        }

        my @errors;
        if ($found) {
            ### create and execute sqltext:
            my $sqltext = sprintf "INSERT INTO %s (%s) values (%s)",
                $self->tablename, join( ', ', @col_name ),
                join( ', ', @col_val );
            my $inserted = $apiis->DataBase->sql(
                {   statement => $sqltext,
                    user      => 'system',
                }
            );
            if ( scalar $inserted->errors ) {
                $self->errors( scalar $inserted->errors );
                $self->status(1);
                $apiis->log( 'notice', '_insert: record insert failed' );
                last EXIT;
            }
            $self->rows( $inserted->rows );

            $apiis->log( 'info',
                      $self->rows
                    . " records inserted into table "
                    . $self->tablename );
        }

        ### check for PostInsert triggers
        $self->RunTrigger('postinsert');

        ### error handling PostInsert
    }    # end label EXIT

    # reset the record notification:
    $self->action($oldaction);
    if ($debug) {
        $apiis->log( 'debug',
            sprintf( '_insert: insert of record object finished with status %s',
                $self->status || 0 )
        );
    }
}

##############################################################################
1;

# vim: expandtab:tw=100
