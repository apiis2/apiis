##############################################################################
# $Id: Check.pm,v 1.22 2007/01/09 13:30:26 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check;
$VERSION = '$Revision: 1.22 $';

use strict;
use warnings;

use Apiis::Init;
our $apiis;

sub _check_record {
    my $self  = shift;
    my $debug = $apiis->debug || $self->debug;

    # check if action is update and record is flagged dirty:
    my $skipdirty;
    my $action = lc $self->action;
    if ( $action eq 'update' ) {
        $skipdirty = 1 if $self->column('dirty')->intdata;
    }

    COLUMN:
    foreach my $thiscol ( $self->columns ) {
        # skip unchanged columns if record is flagged 'dirty':
        next COLUMN if $skipdirty and !$self->column($thiscol)->updated;

        # do we have any check rules?:
        my $check_refs = $self->column($thiscol)->check_rules;
        next COLUMN if !$check_refs;

        CHECKRULE:
        foreach my $check_ref (@$check_refs) {
            my ( $thisrule, @check_args ) = @$check_ref;    # LoL

            if ($debug) {
                $apiis->log( 'debug', sprintf "%s running rule %s on %s",
                    'check_record:', $thisrule,
                    $self->tablename . q{.} . $thiscol );
            }

            # not loaded yet?:
            if ( !$self->can($thisrule) ) {
                my $thissub = 'Apiis::DataBase::Record::Check::' . $thisrule;
                eval "require $thissub";
                if ($@) {
                    $self->status(1);
                    my $err_msg  = $@;
                    my %err_args = (
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => 'check_record',
                        db_column => $thiscol,
                        db_table  => $self->tablename,
                        msg_long  => $err_msg,
                        msg_short => __(
                            "Loading checkrule '[_1]' into ISA failed", $thissub
                        ),
                    );
                    my $ef_ref = $self->column($thiscol)->ext_fields;
                    if ($ef_ref) {
                        $err_args{ext_fields} = $ef_ref;
                    }
                    $self->errors( Apiis::Errors->new(%err_args) );
                    next CHECKRULE;
                }

                # add this method to ISA array:
                push @Apiis::DataBase::Record::Check::ISA, $thissub;
                if ($debug) {
                    $apiis->log( 'debug',
                        "check_record: Loaded checkrule '$thisrule' into ISA" );
                }
            }

            # should we skip this checkrule for this action?:
            my $skip_me = 'skip_' . $thisrule;
            if ( $self->can($skip_me) ) {
                my $skip_ref = $self->$skip_me;
                if ( grep {/^$action$/} @$skip_ref ) {
                    if ($debug) {
                        $apiis->log( 'debug', sprintf
                            "check_record: checkrule '%s' skipped during %s",
                            $thisrule, $action
                        );
                    }
                    next CHECKRULE;
                }
            }

            # now execute (encapsulated in eval to catch buggy check routines):
            my $thisrule_status;
            eval {
                $thisrule_status = $self->$thisrule( $thiscol, @check_args );
            };

            if ($@) {
                my $err_msg = $@;
                $self->status(1);
                my %err_args = (
                    type      => 'CODE',
                    severity  => 'ERR',
                    from      => 'check_record->' . $thisrule,
                    db_column => $thiscol,
                    db_table  => $self->tablename,
                    msg_long  => $err_msg,
                    msg_short =>
                        __( "Rule '[_1]' returned fatal error", $thisrule ),
                );
                my $ef_ref = $self->column($thiscol)->ext_fields;
                if ($ef_ref) {
                    $err_args{ext_fields} = $ef_ref;
                }
                $self->errors( Apiis::Errors->new(%err_args) );
                next CHECKRULE;
            }

            $self->status(1) if $thisrule_status;

            if ($debug) {
                $apiis->log( 'debug',
                    sprintf "%s rule '%s' for column '%s' returned status %s",
                    'check_record', $thisrule, $thiscol,
                    ( $thisrule_status || 0 )
                );
            }
        }    # end loop CHECKRULE
    }    # end loop COLUMN
}

##############################################################################
1;


__END__

# ToDo:
# special handling of check_integrity
# checking of correct datatypes, e.g. if a passed date is valid (do we want
# this?)

# deleted:
my ( $package, $filename, $line ) = caller;
croak __(
    "This method [_1] may only be invoked from package [_2].\nYou called it from package [_3]",
    '_check_record', 'Apiis::DataBase::Record::*', $package )
    unless $package =~ /^Apiis::DataBase::Record/;
