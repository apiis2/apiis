##############################################################################
# $Id: Clear.pm,v 1.17 2006-06-06 13:21:42 heli Exp $
# clears the data references of all fields
##############################################################################
package Apiis::Form::Event::Clear;

use strict;
use warnings;
use base 'Apiis::Init';
use Data::Dumper;

sub _clear_block {
    my ( $self, $args_ref ) = @_;
    my $blockname = $args_ref->{'blockname'};
    my $veryclean = $args_ref->{'veryclean'};
    $veryclean = 1 if !defined $veryclean;

    EXIT: {
        if ( not defined $blockname ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::_query_block',
                    backtrace => Carp::longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'blockname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # reset/delete query records and indices:
        my $fields_ref;
        my $ds_name = $self->GetValue( $blockname, 'DataSource' );
        $self->SetValue( $ds_name, '__rowid', undef );
        if ($veryclean) {
            $self->SetValue( $ds_name, '__curr_index',    0 );
            $self->SetValue( $ds_name, '__max_index',     undef );
            $self->SetValue( $ds_name, '__query_records', undef );
            if ( !$self->GetValue( $blockname, '_is_detailblock' ) ) {
                $self->form_status_msg( &main::__('Cleared') );
            }

            # set all _data_refs in the fields to Default (if any):
            $fields_ref = $self->GetValue( $blockname, '_all_field_list' );
            last EXIT if !$fields_ref;

            FIELD:
            for my $field (@$fields_ref) {
                # don't overwrite the _data_ref pointers of Field, which are
                # connected to others via Connect:
                next FIELD if $self->GetValue( $field, '_connect_list' );

                # get the Default, if any, otherwise undef:
                my $default = $self->GetValue( $field, 'Default' );
                next FIELD if !defined $default;
                my $data_refs = $self->GetValue( $field, '_data_refs' );
                next FIELD if !$data_refs;
                for my $d_r (@$data_refs) {
                    $$d_r = $default;
                }
            }
        }

        # ... then restore the _list_ref of somehow related fields:
        LIST_REF:
        for my $field (@$fields_ref) {
            my $event_ref = $self->GetValue( $field, '_event_list' );
            next LIST_REF if !$event_ref;
            EVENT:
            for my $event (@$event_ref) {
                my $action = $self->GetValue( $event, 'Action' );
                next EVENT if $action ne 'get_choices';

                # get fieldname from Parameter, restore choices for this field:
                my $ev_args_ref =
                    $self->get_event_par_ref( { eventname => $event } );

                # execute:
                for my $targetfield ( @{ $ev_args_ref->{'fieldname'} } ) {
                    $self->get_field_list_ref($targetfield);
                }
            }
        }
    }    # end label EXIT
    return;
}
##############################################################################

1;

__END__

=head2 _clear_block

B<_clear_block> loops with default 'veryclean => 1' through all fields of the
passed block and clears all elements of @_data_refs (undef), the indices
__curr_index (0) and __max_index (undef), and all record objects from former
queries.

Additionally it restores the original scrolling lists of connected fields,
which might be shortened by Events.

B<_clear_block> has two input parameters:

    1. 'blockname => $blockname' (required)
    2. 'veryclean => 1|0'        (optional)

The option 'veryclean => 0' doesn't delete __query_records and the indices.

Usage:

    $self->_clear_block( blockname => $thisblock );
    $self->_clear_block(
        blockname => $thisblock,
        veryclean => 0
    );

=cut

