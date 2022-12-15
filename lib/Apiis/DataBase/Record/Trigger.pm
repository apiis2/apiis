##############################################################################
# $Id: Trigger.pm,v 1.12 2014/12/08 08:56:55 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger;

use strict;
use warnings;
our $VERSION = '$Revision: 1.12 $';

use Carp qw/ longmess /;
use Text::ParseWords;

use Apiis;

sub _run_trigger {
    my ( $self, $type ) = @_;

    my %types = (
        preinsert  => 1,
        postinsert => 1,
        preupdate  => 1,
        postupdate => 1,
        predelete  => 1,
        postdelete => 1,
    );

    # check for correct type:
    if ( !exists $types{$type} ) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'CODE',
                severity  => 'ERR',
                from      => '_run_trigger',
                msg_short => "Non-existing trigger type '$type' passed.",
                db_table  => $self->tablename,
            )
        );
        return;
    }

    # notify Record object:
    $self->triggeraction($type);

    my $debug = 1
        if $apiis->syslog_priority  eq 'debug'
        or $apiis->filelog_priority eq 'debug';

    # get trigger definitions from record:
    my $thistype     = $type . '_triggers';
    my $triggers_ref = $self->$thistype;
    return if !$triggers_ref;

    # loop through every trigger entry:
    TRIGGER:
    foreach my $entry (@$triggers_ref) {
        my ( $trigger, @t_args ) = parse_line( '\s+', 0, $entry );
        if ($debug) {
            $apiis->log( 'debug', sprintf
                "%s: Starting to run the %s trigger %s with args '%s'",
                '_run_trigger', $type, $trigger, join( ',', @t_args )
            );
        }

        # load triggers dynamically:
        my $module = 'Apiis::DataBase::Record::Trigger::' . $trigger;
        my $exec_rule = $module . '::' . $trigger;    # filename eq methodname
        eval "require $module";                       ## no critic
        if ($@) {
            my $msg = $@;
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type     => 'CODE',
                    severity => 'ERR',
                    from => 'Apiis::DataBase::Record::Trigger::_run_trigger',
                    db_table  => $self->tablename,
                    msg_long  => $msg,
                    msg_short => __( "undefined module '[_1]'", $module ),
                    backtrace => longmess('invoked'),
                )
            );
            next TRIGGER;
        }

        # encapsulate in an eval to catch buggy Trigger routines:
        eval { $self->$exec_rule(@t_args) };
        if ($@) {
            my $err_msg = $@;
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type     => 'CODE',
                    severity => 'ERR',
                    from     => '_run_trigger->' . $trigger,
                    db_table => $self->tablename,
                    msg_long => $err_msg,
                    msg_short =>
                        __( "trigger '[_1]' returned fatal error", $trigger ),
                )
            );
            next TRIGGER;
        }
    }
    return;
}

##############################################################################
1;

# vim: expandtab:tw=100
