##############################################################################
# $Id: HandleDS.pm,v 1.5 2014/12/08 08:56:55 heli Exp $
# Handle events concerning DataSources.
# See POD at the end of the file.
##############################################################################
package Apiis::Form::Event::HandleDS;

use strict;
use warnings;
use Carp qw( longmess );

##############################################################################

=head2 get_field_data

input: eventname as hash reference:

   { eventname => 'ThisEvent' }

output: none

Event parameters are defined in the XML file:

   Key   => fieldname            (required)
   Value => <Name_of_this_Field> (required)

Example from the XML file:

    <Event Name="Notify_F443"
        Type="OnSelect" Module="HandleDS" Action="get_field_data">
        <Parameter
            Name="Parameter_F449_1"
            Key="fieldname" Value="F443"
        />
    </Event>

B<get_field_data> runs the defined DataSource, usually a SQL statement, to
query the data for this field. This can be triggered by selecting a value in
another Field.

=cut

sub get_field_data {
    my ( $self, $args_ref ) = @_;

    EXIT: {
        my $event = $args_ref->{eventname};
        if ( not defined $event ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::_callform',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'eventname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # get parameters of this event:
        my $event_args_ref =
            $self->get_event_par_ref( { eventname => $event } );

        # get the field data:
        for my $field ( @{ $event_args_ref->{'fieldname'} } ) {
            $self->get_field_data_ref($field);
        }
    }    # end label EXIT
    return;
}

##############################################################################

=head2 get_block_ds

input: eventname as hash reference:

   { eventname => 'ThisEvent' }

output: none

Event parameters are defined in the XML file:

   Key   => blockname            (required)
   Value => <Name_of_this_Block> (required)

Example from the XML file:

    <Event Name="Notify_Block_3"
        Type="OnSelect" Module="HandleDS" Action="get_block_ds">
        <Parameter
            Name="Parameter_4711"
            Key="blockname"
            Value="Block_3"
        />
    </Event>

B<get_block_ds> runs the defined DataSource, usually a SQL statement or a
Function, to query the data for this block. This can be triggered by an event
somewhere else.

=cut

sub get_block_ds {
    my ( $self, $args_ref ) = @_;

    EXIT: {
        my $event = $args_ref->{eventname};
        if ( not defined $event ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::HandleDS::get_block_ds',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'eventname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # get parameters of this event:
        my $event_args_ref =
            $self->get_event_par_ref( { eventname => $event } );

        # get the field data:
        for my $block ( @{ $event_args_ref->{'blockname'} } ) {
            $self->get_block_ds( { blockname => $block } );
        }
    }    # end label EXIT
    return;
}
##############################################################################

=head2 get_choices

input: eventname as hash reference:

   { eventname => 'ThisEvent' }

output: none

Event parameters are defined in the XML file:

   Key   => fieldname            (required)
   Value => <Name_of_this_Field> (required)

Example from the XML file:

    <Event Name="Restore_choices_F443"
           Type="OnSelect"
           Module="HandleDS"
           Action="get_choices">
        <Parameter
            Name="Parameter_F449_1"
            Key="fieldname"
            Value="F443"
        />
    </Event>

B<get_choices> rebuilds the choices list of the defined fieldnames (here
F443).

=cut

sub get_choices {
    my ( $self, $args_ref ) = @_;

    EXIT: {
        my $event = $args_ref->{eventname};
        if ( not defined $event ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::_callform',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'eventname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # get parameters of this event:
        my $event_args_ref =
            $self->get_event_par_ref( { eventname => $event } );

        # execute:
        for my $field ( @{ $event_args_ref->{'fieldname'} } ) {
            $self->get_field_list_ref($field);
        }
    }    # end label EXIT
    return;
}

sub query_block {
    my ( $self, $args_ref ) = @_;

    EXIT: {
        my $event = $args_ref->{eventname};
        if ( not defined $event ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::_callform',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'eventname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # get parameters of this event:
        my $event_args_ref =
            $self->get_event_par_ref( { eventname => $event } );

        # execute:
        for my $block ( @{ $event_args_ref->{'blockname'} } ) {
            $self->clear_block( { blockname => $block } );
            $self->query_block( { blockname => $block } );
        }
    }    # end label EXIT
    return;
}
##############################################################################

=head2 reload_block_data

B<reload_block_data> is a PostInsert-Event on block level. It loads
back the extdata-values of the record object into the _data_ref of the fields.
This is mainly usefull if a database sequence is created during the insert
process which exists in the record object but not in the form's field.

input:

   a hash reference with the keys 'eventname' and 'enventargs':

   {   eventname => 'name_of_this_event',
       eventargs => {
           record_obj => $record,
           blockname  => $block
       },
   }



output:

   none.

B<reload_block_data> needs no additional Event parameters.

Example from the XML file:

   <Event Name="E_sample1"
      Type="PostInsert" Module="HandleDS" Action="reload_block_data" >
   </Event>

=cut

sub reload_block_data {
    my ( $self, $args_ref ) = @_;

    my $event         = $args_ref->{eventname};
    my $eventargs_ref = $args_ref->{eventargs};
    EXIT: {
        if ( not defined $event ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::reload_block_data',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf( "No key '%s' passed", 'eventname' ),
                )
            );
            last EXIT;
        }
        last EXIT if !$eventargs_ref;
        my $block = $eventargs_ref->{blockname};
        last EXIT if !defined $block;
        last EXIT if !$eventargs_ref->{record_obj};
        my $ds_name = $self->GetValue( $block, 'DataSource' );
        last EXIT if lc $self->GetValue( $ds_name, 'Type' ) ne 'record';

        # delegate the work:
        $self->_ro2fields(
            {   datasource => $ds_name,
                record_obj => $eventargs_ref->{record_obj},
                row_index  => 0,
            }
        );
    } # end label EXIT
}

##############################################################################

1;

__END__
