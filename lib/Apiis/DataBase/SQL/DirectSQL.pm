##############################################################################
# $Id: DirectSQL.pm,v 1.29 2014/12/08 08:56:55 heli Exp $
# the SQL module for direct access (without any authorization).
# This access should be allowed only from Record.pm and friends. (???)
##############################################################################
package Apiis::DataBase::SQL::DirectSQL;
$VERSION = '$Id ';

=head1 NAME

Apiis::DataBase::SQL::DirectSQL  Direct access to SQL

=head1 SYNOPSIS

   $apiis->DataBase->user_sql( $sql_statement );
   $apiis->DataBase->sys_sql( $sql_statement );

=head1 DESCRIPTION

Both of these methods point to the internal work horse B<_sql> with the
invocation parameters as a hash reference:

   _sql( { statement => $sql_statement, user => 'system' } )

in case of sys_sql or without the 'user' parameter for user_sql.

B<_sql> creates its own statement object, which is returned.

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw( longmess croak );
use Data::Dumper;
use Apiis::Init;
use Encode;

@Apiis::DataBase::SQL::DirectSQL::ISA = qw(
      Apiis::Init
);

=head2 user_sql | sys_sql | _sql

The only input parameter for B<user_sql> and B<sys_sql> is a valid SQL
statement. Returned will be a statement object with the following methods:

Examples:

    my $statement_obj    = $apiis->DataBase->user_sql('select * from codes');
    my $statement_handle = $statement_obj->handle;
    my $processed_rows   = $statement_obj->rows;
    if ( $statement_obj->status ) {
        for my $error ( $statement_obj->errors ) {
            # handle error:
            $error->print;
        }
    }
   
See 'man DBI' for detailed information about the statement handle and rows.

=cut

sub _sql {
    my ( $invocant, $args_ref ) = @_;

    my ( $package, $filename, $line ) = caller;
    if ( $package ne 'Apiis::DataBase::SQL::DirectSQL' ) {
        croak __(
            "This method [_1] may only be invoked from package [_2].\nYou called it from package [_3]",
            '_sql', 'Apiis::DataBase::SQL::DirectSQL', $package
        );
    }

    croak "Missing initialisation in main file (", __PACKAGE__, ")\n"
        unless defined $apiis;

    my $class = ref($invocant) || $invocant;
    my $self  = bless {}, $class;
    my ( $statement, $log_prefix, $sth, $rv );

    EXIT: {
        # get/check the passed arguments:
        my ( $thisuser, $thisdbh );

        # user: default is user_dbh, sys_dbh only when "user => 'system'":
        if ( exists $args_ref->{user} ) {
            $thisuser = $args_ref->{user} || $apiis->User->id;
            # should be:
            # if ( defined $thisuser and lc $thisuser eq $apiis->DataBase->db_user ) {#}
            if ( defined $thisuser and lc $thisuser eq 'system' ) {
                $thisdbh = $apiis->DataBase->sys_dbh;
            }
            else {
                $thisdbh = $apiis->DataBase->user_dbh;
            }
        }
        else {
            $thisuser = $apiis->User->id;
            $thisdbh  = $apiis->DataBase->user_dbh;
        }
        $log_prefix = "sql ($thisuser): ";

        # get a valid SQL statement:
        $statement = $args_ref->{statement};
        if ( !$statement ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'sql',
                    msg_short => "No valid SQL-statement passed",
                    backtrace => longmess('invoked'),
                )
            );
            $self->status(1);
            last EXIT;
        }

        # get the action of this statement:
        $statement =~ s/^\s*//;  # leading blanks make split fail!
        my ($action) = split /\s+/, $statement;

        my $run_execute = 1;
        if ( exists $args_ref->{execute} ) {
            $run_execute = $args_ref->{execute};
        }
        eval {
            local $thisdbh->{RaiseError} = 1 unless $thisdbh->{RaiseError};

            my $encoding = lc $apiis->Model->db_encoding;
            if ( $encoding eq 'unicode' ) {
                if ( !Encode::is_utf8($statement) ) {
                    $statement = Encode::decode_utf8($statement);
                }
            }
            elsif ( $encoding eq 'latin1' ) {
                $statement = Encode::encode( "iso-8859-1", $statement );
            }
            $sth = $thisdbh->prepare($statement);
            # $sth = $thisdbh->prepare_cached( $statement, undef, 3 );
            # $sth = $thisdbh->prepare_cached( $statement, { dbi_dummy => __FILE__ . __LINE__ } );

            # don't run execute if you want to use placeholders/binding:
            if ($run_execute) {
                $rv = $sth->execute;
            }
        };
        if ($@) {
            $self->status(1);
            my $err_text = $@;
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DB',
                    severity  => 'ERR',
                    from      => '_sql',
                    backtrace => longmess('invoked'),
                    msg_long  => __( "SQL Statement: [_1]", $statement ),
                    msg_short => __(
                        "Error in SQL statement ([_1]): [_2]",
                        $thisuser, $err_text ),
                )
            );
            # PostgreSQL does not seem to recover gracefully after an error
            # within a transaction. See at the end of this file for details
            # explanations:
            $thisdbh->rollback;
            last EXIT;
        }
        last EXIT if !$run_execute;    # don't need to check return values

        # check for return values of certain statements:
        my %check_rv_for = (
            insert => 1,
            update => 1,
            delete => 1,
        );

        # treat update/delete/insert of 0 records as a warning, so it's up to
        # the developer to handle this case (SELECT must be excluded as the
        # number of affected rows will not be returned by the database:
        if ( exists $check_rv_for{ lc $action } ) {
            # zero, but true: no records affected
            if ( $rv eq '0E0' ) {
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DB',
                        severity  => 'WARNING',
                        from      => '_sql',
                        backtrace => longmess('invoked'),
                        msg_short => __(
                            "No records affected by [_1] statement",
                            uc $action
                        ),
                        msg_long => __(
                            "SQL Statement([_1]): [_2] \(Return value: [_3]\)",
                            $thisuser, $statement, $rv
                        ),
                    )
                );
                $self->status(1);
                last EXIT;
            }

            # return value unknown:
            if ( $rv == -1 ) {
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DB',
                        severity  => 'WARNING',
                        from      => '_sql',
                        backtrace => longmess('invoked'),
                        msg_short => __(
                            "Unknown number of records affected by [_1] statement",
                            uc $action
                        ),
                        msg_long => __(
                            "SQL Statement([_1]): [_2] \(Return value: [_3]\)",
                            $thisuser, $statement, $rv
                        ),
                    )
                );
                $self->status(1);
                last EXIT;
            }

            # ToDo: better use I18N facilities to handle grammar:
            if ( $rv > 0 ) {
                my $lcaction =
                    lc $action eq 'insert'
                    ? ( lc $action . 'ed' )
                    : ( lc $action . 'd' );
                $apiis->log( 'info', "$log_prefix $rv record $lcaction" );
                last EXIT;
            }

            # this should not happen:
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DB',
                    severity  => 'ERR',
                    from      => '_sql',
                    backtrace => longmess('invoked'),
                    msg_short => __(
                        "Unknown return value from DBI in action [_1] ", $action
                    ),
                    msg_long => __(
                        "SQL Statement([_1]): [_2] \(Return value: [_3]\)",
                        $thisuser, $statement, $rv
                    ),
                )
            );
            $self->status(1);
        }
    }    # end EXIT label
    unless ( $self->status ) {
        $apiis->log( 'sql',   $statement );
        $apiis->log( 'debug', "$log_prefix $statement" );
        $self->{_handle} = $sth;
        $self->{_rows}   = $rv;
    }

    return $self;
}

# public methods:
# to access the keys of the $self-hash (the return values):
*handle = sub { $_[0]->{_handle} };
*rows   = sub { $_[0]->{_rows} };

# maybe later we delete direct access via _sql, but currently I keep
# it to make the code still run:
sub sys_sql { $_[0]->_sql( { statement => $_[1], user => 'system' } ) }
sub user_sql { $_[0]->_sql( { statement => $_[1] } ) }

# sql() gives full freedom for choosing the parameter list (hashref!):
sub sql { shift()->_sql( @_ ); }

##############################################################################
1;


__END__

from: http://mail.pm.org/pipermail/spug-list/2004-December/006143.html:

Umar,
PostgreSQL doesn't currently have a way to recover from an error in a
transaction, so any statement after one that causes an error is rejected and
doesn't do anything if it's in the same transaction.  Usually DBD::Pg will be
set to Autocommit=true, so every time you prepare and execute a statement, DO
a statement, etc. the driver will start a new transaction for your statement,
and this will never come up.

It seems like you're setting autocommit=false, probably in your connect
statement, or you're sending an explicit 'begin' statement, and not
'commit'ing it.  If you don't need explicit transactions, it's better to just
have autocommit turned on.  If you do need to control your own transactions
(because you're doing related inserts/updates/whatever) you need to also keep
track of any failures, 'rollback' the current transaction, fix whatever the
problem was, and start the transaction over.  The finish() won't effect this.
If you're seeing this persist past disconnect()'s, that would be pretty
strange.  If any of this doesn't make any sense, or doesn't fit what you're
seeing, let me know and I can try to help you work out what's going on.

Thanks,
Peter Darley

(Postgresql 7.4.7-6sarge1, 3.2.2006 - heli)
