##############################################################################
# $Id: NotNull.pm,v 1.10 2006/11/20 14:33:45 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::NotNull;
$VERSION = '$Revision: 1.10 $';
##############################################################################

=head1 NAME

NotNull

=head1 SYNOPSIS

B<NotNull()> checks, if the data has a defined value

=head1 DESCRIPTION

The passed value $data is not allowed to be undefined or empty. It may have
the numeric value 0.

B<NotNull()> is usually used as a CHECK-rule in the model file.

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub NotNull {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;
    EXIT: {
        my $data = $self->column($col_name)->intdata;

        my $empty;
        if ( !defined $data ) {
            $empty = __('undefined');
        }
        elsif ( $data eq q{} ) {
            $empty = __('empty');
        }

        if ($empty) {
            $local_status = 1;
            my $err_id = $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'NotNull',
                    action    => $self->action || 'unknown',
                    db_column => $col_name,
                    db_table  => $self->tablename,
                    msg_short => __('Value must not be NULL'),
                    msg_long  => __( 'The passed value was: [_1]', $empty ),
                )
            );
            my $ef_ref = $self->column($col_name)->ext_fields;
            if ($ef_ref) {
                $self->error($err_id)->ext_fields($ef_ref);
            }
        }
    }
    return $local_status || 0;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>
