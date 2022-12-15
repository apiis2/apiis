##############################################################################
# $Id: Insert.pm,v 1.24 2009-08-27 13:04:20 duchev Exp $
# Provides methods to handle events in a form.
##############################################################################
package Apiis::Form::Event::Insert;

use strict;
use warnings;
use Apiis;
use base 'Apiis::Init';
use Data::Dumper;

##############################################################################
# insert all input data via the different DataSources into the database:
sub _insert_block {
    my ( $self, $args_ref ) = @_;
    my $blockname = $args_ref->{'blockname'};
    my $status_msg;
    my $do_insert = 0;
    my $ds_name;

    EXIT: {
        if ( !defined $blockname ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::_insert_block',
                    backtrace => Carp::longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'blockname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }
        $ds_name = $self->GetValue( $blockname, 'DataSource' );
        last EXIT if !defined $ds_name;

        # insert only via Record object:
        last EXIT if not lc $self->GetValue( $ds_name, 'Type' ) eq 'record';

        # collect data and leave early if none exists:
        my $all_fields = $self->GetValue( $blockname, '_all_field_list' );
        my %field_data;
        my $has_no_data = 1;

        for my $field (@$all_fields) {
            my $data = ${ $self->GetValue( $field, '_data_ref' ) };
            if ( defined $data and $data ne '' ) {
                $has_no_data = 0;

                # catch multiselection, where $data is an array reference:
                if ( ref $data eq 'ARRAY' ) {
                    # only one element?:
                    if ( scalar @$data == 1 ) {
                        $data = $data->[0];
                    }
                    else {
                        $self->status(1);
                        my $err_short = __(
                            q{Cannot insert multiple values in Field '[_1]'},
                            $field
                        );
                        my $values = q{['} . join( q{','}, @$data ) . q{']};
                        my $err_long = __( "Values: [_1]", $values );

                        $self->errors(
                            Apiis::Errors->new(
                                type       => 'DATA',
                                severity   => 'ERR',
                                from       => '_insert_block',
                                ext_fields => [$field],
                                msg_long   => $err_long,
                                msg_short  => $err_short,
                                )
                        );
                        last EXIT;
                    }
                }
            }
            $field_data{$field} = $data;
        }
        last EXIT if $has_no_data;

        # create new record object for insert:
        my $record_obj = Apiis::DataBase::Record->new(
            tablename => $self->GetValue( $ds_name, 'TableName' )
        );
        if ( $record_obj->status ) {
            $self->status(1);
            $self->errors( scalar $record_obj->errors );
            $record_obj->del_errors;
            last EXIT;
        }

        # loop through all columns of DataSource and fill Record object:
        my ( %related_columns, %related_fields );
        my $thiscol_ref = $self->GetValue( $ds_name, '_column_list' );
        last EXIT if !$thiscol_ref;
        COLUMN:
        foreach my $thiscol ( @$thiscol_ref ) {
            my $db_col = $self->GetValue( $thiscol, 'DBName' );
            my $field  = $self->GetValue( $thiscol, '_field' );
            next COLUMN if !defined $field;
            my $data   = $field_data{$field};

            # if field has its own datasource for _list_ref:
            if ( $self->GetValue( $field, '_my_field_datasource' ) ) {
                $data = $self->decode_list_ref( $field, $data );
            }

            # Related Columns must be treated specially:
            my $coltype = $self->GetValue( $thiscol, 'Type' );
            if ( $coltype eq 'Related' ) {
                # store, even if data is empty (maybe only one element
                # of the array is empty):
                my $rel_col = $self->GetValue( $thiscol, 'RelatedColumn' );
                my $db_col  = $self->GetValue( $rel_col, 'DBName' );
                my $order   = $self->GetValue( $thiscol, 'RelatedOrder' );

               # just define 'is_not_empty' as it does not exist the first time:
               $related_columns{$db_col}{'is_not_empty'} = -1 if (not exists $related_columns{$db_col}{'is_not_empty'});
	       $related_columns{$db_col}{'is_not_empty'} = 0 if (not defined  $data or $data eq '');
	       # if 'is_not_empty' is 0 then at least one related column was undefined, skip the others:
	       next COLUMN unless ($related_columns{$db_col}{'is_not_empty'});
               $related_columns{$db_col}{'order'}[$order] = $data;
	       $related_fields{$db_col}{'order'}[$order]  = $field;
               $related_columns{$db_col}{'is_not_empty'} = 1 
                 if defined $data
                 and $data ne '';

                # unresolved/ToDo: if the related column points into
                # another datasource/table. Not quite easy :^(
            }
            else {
                if ( $self->GetValue( $field, '_displays_intdata' ) ) {
                    # Field contains internal data and needs no encoding:
                    $record_obj->column($db_col)->intdata($data);
                    $record_obj->column($db_col)->encoded(1);
                }
                else {
                    $record_obj->column($db_col)->extdata($data);
                }
                $record_obj->column($db_col)->ext_fields($field);
                $do_insert++;
            }
        }

        # fill Record object with related columns:
        FILL_RELATED:
        foreach my $db_col ( keys %related_columns ) {
            next FILL_RELATED
                unless $related_columns{$db_col}{'is_not_empty'};
            $record_obj->column($db_col)->extdata(
                $related_columns{$db_col}{'order'} );
            $record_obj->column($db_col)->ext_fields(
                @{ $related_fields{$db_col}{'order'} } );
            $do_insert++;
        }

        if ($do_insert) {
            # run PreInsert Events:
            $self->RunEvent(
                {   elementname => $blockname,
                    eventtype   => 'PreInsert',
                    eventargs   => {
                        record_obj => $record_obj,
                        blockname  => $blockname
                    },
                }
            );

            $record_obj->insert;
            if ( $record_obj->status ) {
                $self->status(1);
                $self->errors( scalar $record_obj->errors );
                $record_obj->del_errors;
                last EXIT;
            }
            $status_msg =
                __( "1 record inserted in table '[_1]'", $record_obj->name );


            # run PostInsert Events:
            $self->RunEvent(
                {   elementname => $blockname,
                    eventtype   => 'PostInsert',
                    eventargs   => {
                        record_obj => $record_obj,
                        blockname  => $blockname
                    },
                }
            );
        }
        else {
            if ( !$self->status ) {
                $status_msg =
                    __( "You want to insert an empty record into table '[_1]'?",
                    $self->GetValue( $ds_name, 'TableName' ) );
            }
        }
    }    # end EXIT label

    $self->form_status_msg( $blockname . ': ' . $status_msg ) if $status_msg;
    return;
}
1;

