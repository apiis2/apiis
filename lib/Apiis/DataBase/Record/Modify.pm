##############################################################################
# $Id: Modify.pm,v 1.14 2014/12/08 08:56:55 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Modify;
$VERSION = '$Revision: 1.14 $';

use strict;
use warnings;
use Data::Dumper;
use Carp qw( longmess );
use Text::ParseWords;

use Apiis::Init;
our $apiis;

sub _modify_record {
    my $self  = shift;
    my $debug = 1 if $apiis->syslog_priority eq 'debug';
    my $tablename = $self->tablename;

    COLUMN:
    foreach my $thiscol ( $self->columns ) {
        # get the column object:
        my $thiscol_obj = $self->column($thiscol);

        # modify rules for this column?:
        my $mod_ref = $thiscol_obj->modify;
        next COLUMN if !$mod_ref;

        foreach my $thismodify (@$mod_ref) {
            # parse the modify rule:
            my ( $thisrule, @modify_args ) =
                parse_line( '\s+', 0, $thismodify );

            # get extdata:
            my $extdata_ref = $self->column($thiscol)->extdata;

            # do we have this rule?:
            my $module = 'Apiis::DataBase::Record::Modify::' . $thisrule;
            my $exec_rule = $module . '::' . $thisrule; # filename eq methodname
            eval "require $module";
            if ( $@ ){
                my $msg = $@;
                $self->status(1);
                my $err_id = $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => 'Apiis::DataBase::Record::Modify::_modify',
                        db_column => $thiscol,
                        db_table  => $tablename,
                        msg_long  => $msg,
                        msg_short => __( "undefined rule '[_1]'", $module ),
                        backtrace => longmess('invoked'),
                    )
                );
                my $extfields_ref = $self->column($thiscol)->ext_fields;
                if ($extfields_ref) {
                    $self->error($err_id)->ext_fields(@$extfields_ref);
                }
                next COLUMN;
            }

            my $olddata = '';
            if ($debug) {
                $olddata = join( ',', @$extdata_ref ) if $extdata_ref;
            }

            # encapsulate in an eval to catch buggy modify routines:
            # eval { $self->$thisrule( $thiscol, @modify_args ) };
            eval { $self->$exec_rule( $thiscol, @modify_args ) };
            if ($@) {
                my $err_msg = $@;
                $self->status(1);
                my $err_id = $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => '_modify->' . $thisrule,
                        db_column => $thiscol,
                        db_table  => $tablename,
                        msg_long  => $err_msg,
                        msg_short =>
                            __( "rule '[_1]' returned fatal error", $thisrule ),
                        )
                );
                my $extfields_ref = $self->column($thiscol)->ext_fields;
                if ($extfields_ref) {
                    $self->error($err_id)->ext_fields(@$extfields_ref);
                }
            }

            if ( !$self->status ) {
                if ($debug) {
                    my $newdata     = '';
                    my $extdata_ref = $self->column($thiscol)->extdata;
                    if ($extdata_ref) {
                        $newdata = join( ',', @$extdata_ref );
                    }
                    $apiis->log( 'debug', sprintf(
                            "_modify: rule '%s' for column '%s': %s=>%s",
                            $thisrule, $thiscol, $olddata, $newdata
                        )
                    );
                }
            }
        }
    }    # end COLUMN loop
    return;
}

##############################################################################
1;

# vim: expandtab:tw=100
