#############################################################################
# $Id: Update.pm,v 1.37 2021/11/30 09:56:14 ulf Exp $
# Provides methods to handle events in a form.
##############################################################################
package Apiis::Form::Event::Update;

use strict;
use warnings;
use Apiis;
use base 'Apiis::Init';

=head2 _update_block (internal)

B<_update_block> is the internal method to handle block updates. It currently
takes these input parameters as a hash reference:

   blockname => $blockname,
   implicit => 0|1,          # default is 0

Example:

   $self->Apiis::Form::Event::Update::_update_block(
      {   blockname => $block,
          implicit  => 1
      }
   );

The parameter 'blockname' is mandatory. 'implicit' is used to distinguish
between intentionally (=explicitly) initiated updates (e.g. by pressing an
Update button) or implicitely initiated updates (e.g. by selecting next record
in a query, where changes occurred).

B<_update_block> writes the updates into the database (without commit), if no
errors occur, returns an error message otherwise.

=cut

sub _update_block {
    my ( $self, $args_ref ) = @_;
    my $status_msg;
    my $did_update = 0;
    my $blockname  = $args_ref->{'blockname'};

    EXIT: {
        if ( !defined $blockname ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::_update_block',
                    backtrace => Carp::longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'blockname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # other passed switches:
        # implicit update situation occurs, if you update a query record an
        # press 'next' record:
        my $implicit = $args_ref->{'implicit'};

        # only allow DataSources of type Record:
        my $ds_name = $self->GetValue( $blockname, 'DataSource' );
        last EXIT if $self->GetValue( $ds_name, 'Type' ) ne 'Record';

        # get record objects from queries or create new Record:
        my $record_objs_ref = $self->GetValue( $ds_name, '__query_records' );
        my ( $curr_index, $from_query );
        if ($record_objs_ref) {
            # we have already records from a former query:
            $curr_index = $self->GetValue( $ds_name, '__curr_index' );
            $from_query = 1;
        }
        else {
            # we do an update without a former query:
            $curr_index = 0;
            my $tablename = $self->GetValue( $ds_name, 'TableName' );
            # arrayref!
            $record_objs_ref =
                [ Apiis::DataBase::Record->new( tablename => $tablename ) ];
        }

        # initialize before REPEAT-Block:
        my $do_update   = 0;
        my $max_repeats = 0;

        REPEAT: {
            # take the appropriate Record object:
            my $record_obj = $record_objs_ref->[$curr_index];
            next REPEAT if !defined $record_obj;
            my $max_rows_set;

            if ( $record_obj->status ) {
                $self->status(1);
                $self->errors( scalar $record_obj->errors );
                $record_obj->del_errors;    # as they are propagated
                $record_obj->status(0);
                last EXIT;
            }

            # loop thru each DS-column and collect data:
            my ( %related_columns, %related_fields );
            my $columns_ref = $self->GetValue( $ds_name, '_column_list' );

            COLUMN:
            foreach my $thiscol (@$columns_ref) {
                my $db_col = $self->GetValue( $thiscol, 'DBName' );
                my $field  = $self->GetValue( $thiscol, '_field' );
                next COLUMN if !defined $field;

                #-- scip if update only for a special field 
                if (( exists $self->{'_activ_update_fields_from_cgi'}) and 
                    (!exists $self->{'_activ_update_fields_from_cgi'}->{$field})) {
                    next COLUMN ;
                }

                # do we have repeated Fields (Tabular)?:
                if (not $max_rows_set and $self->GetValue( $field, 'Repeat' )){
                    $max_repeats = scalar @{$record_objs_ref};
                    $max_rows_set++;
                }

                # get the data from the array of _data_refs:
                my $data_ref;
                if ($max_repeats) {
                    $data_ref =
                        $self->GetValue( $field, '_data_refs' )->[$curr_index];
                }
                else {
                    $data_ref = $self->GetValue( $field, '_data_refs' )->[0];
                    # $data_ref = $self->GetValue( $field, '_data_ref' );
                }
                my $data;
                $data = $$data_ref if $data_ref;

                # catch multiselection, where $data is an array reference:
                if ( ref $data eq 'ARRAY' ) {
                    # only one element?:
                    if ( scalar @$data == 1 ) {
                        $data = $data->[0];
                    }
                    else {
                        $self->status(1);
                        my $err_short = __(
                            q{Cannot update multiple values in Field '[_1]'},
                            $field
                        );
                        my $values = q{['} . join( q{','}, @$data ) . q{']};
                        my $err_long = __( "Values: [_1]", $values );

                        $self->errors(
                            Apiis::Errors->new(
                                type       => 'DATA',
                                severity   => 'ERR',
                                from       => '_update_block',
                                ext_fields => [$field],
                                msg_long   => $err_long,
                                msg_short  => $err_short,
                                )
                        );
                        next COLUMN;
                    }
                }
                # from here on we expect $data as being defined, at least as
                # empty string:
                $data = q{} if !defined $data;

                # Translate back if field has its own datasource for _list_ref:
                if ( $self->GetValue( $field, '_my_field_datasource' ) ) {
                        $data = $self->decode_list_ref( $field, $data );
                }

                # related columns?:
                my $coltype = $self->GetValue( $thiscol, 'Type' );
                if ( $coltype eq 'Related' ) {
		    # store only if data is not empty and 
		    # the previous related column were all filled
                    my $rel_col = $self->GetValue( $thiscol, 'RelatedColumn' );
                    my $db_col = $self->GetValue( $rel_col, 'DBName' );
                    my $order  = $self->GetValue( $thiscol, 'RelatedOrder' );

                    # define is_not_empty as it does not exist the first time:
		    $related_columns{$db_col}{'is_not_empty'} = -1 if (not exists $related_columns{$db_col}{'is_not_empty'});
		    $related_columns{$db_col}{'is_not_empty'} = 0 if (not defined  $data or $data eq q{});
		    # if 'is_not_empty' is 0 then at least one related column was undefined, skip the others:
		    next COLUMN unless ($related_columns{$db_col}{'is_not_empty'});
                    $related_columns{$db_col}{'order'}[$order]  = $data;
                    $related_fields{$db_col}{'order'}[$order]  = $field;
                    $related_columns{$db_col}{'is_not_empty'} = 1 if $data ne q{};
                    # unresolved/ToDo: if the related column points into
                    # another datasource/table. Not quite easy :^(
                }
                else {
                    LABEL1: {
                        # related columns (here: the refered column)
                        # are handled later:
                        last LABEL1
                            if $self->GetValue( $thiscol, '_related_from' );

                        # do we handle intdata?:
                        if ( $self->GetValue( $field, '_displays_intdata' ) ) {
                            my $int_data =
                                $record_obj->column($db_col)->intdata;
                            $int_data = q{} if !defined $int_data;
                            if ( $int_data eq $data and $data ne q{} ) {
                                $record_obj->column($db_col)->encoded(1);
                                last LABEL1;
                            }

                            # store changes in intdata:
                            $record_obj->column($db_col)->intdata($data);
                            $record_obj->column($db_col)->encoded(1);
                            $do_update++;
                            last LABEL1;
                        }
                        my ($ext_data) = $record_obj->column($db_col)->extdata;
                        $ext_data = q{} if !defined $ext_data;
                        last LABEL1 if ( $ext_data eq $data and $data ne q{} );

                        # store changes in extdata:
                        $record_obj->column($db_col)->extdata($data);
                        $record_obj->column($db_col)->ext_fields($field);
                        $do_update++;
                    }    # end label LABEL1
                }
            }

            # now handle related columns:
            RELATED_COLS:
            foreach my $db_col ( keys %related_columns ) {
                next RELATED_COLS
                    if !$related_columns{$db_col}{'is_not_empty'};

                # fill extdata and extfields:
                $record_obj->column($db_col)->extdata(
                    $related_columns{$db_col}{'order'}
                );
                $record_obj->column($db_col)->ext_fields(
                    @{ $related_fields{$db_col}{'order'} }
                );
                $do_update++;
            }

            if ($do_update) {
	        # run PreUpdate Events:
	        $self->RunEvent(
                    {   elementname => $blockname,
			eventtype   => 'PreUpdate',
			eventargs   => {
			   record_obj => $record_obj,
			   blockname  => $blockname
			},
		    }
		);

                # first check the mirror for changes:
                if ( $record_obj->mirrored and !$record_obj->mirror_differs ) {
                    if ( $max_repeats > $curr_index ) {
                        $curr_index++;
                        goto REPEAT;
                    }
                    last REPEAT;
                }
                $did_update++;

                # commit changes if no AutoCommit?:
                ASK: {
                    # only in query records we can track changes:
                    last ASK if !$from_query;

                    # no need to ask on autocommit:
                    my $autocommit =
                        $self->GetValue( $blockname, 'AutoCommit' );
                    last ASK if $autocommit;

                    # fire explicitly invoked updates anyway:
                    last ASK if !$implicit;

                    # Ugly: This is widget specific, which shouldn't be here.
                    # But how can we pass back the question and proceed here
                    # later?
                    if ( $self->gui_type eq 'Tk' ) {
                        require Apiis::Form::Tk::Misc;
                        import Apiis::Form::Tk::Misc qw( ask_ync );

                        my $txt =
                           __('Do you want to commit changes to the database?');
                        my $answer = ask_ync(
                            {   toplevel => $self->top,
                                text     => $txt,
                                buttons  => [ __('Yes'), __('No') ],
                            }
                        );
                        if ( lc $answer ne 'yes' ) {
                            if ( $max_repeats > $curr_index ) {
                                $curr_index++;
                                goto REPEAT;
                            }
                            last REPEAT;
                        }
                    }
                }

                # ok, now update:
                $record_obj->update;

                if ( $record_obj->status ) {
                    # store for each error the current (tabular) index:
                    for my $rec_err ( $record_obj->errors ) {
                        $rec_err->ext_fields_idx( $curr_index );
                    }

                    # move record_obj errors to form object:
                    $self->status(1);
                    $self->errors( $record_obj->errors );

                    # clear record objects for later use (in navigation):
                    $record_obj->del_errors;
                    $record_obj->status(0);
                    # last EXIT;
                }
                else {
                    # write back the refreshed record object:
                    $record_objs_ref->[$curr_index] = $record_obj;

                    # update the form fields:
                    $self->_ro2fields(
                        {   datasource => $ds_name,
                            record_obj => $record_obj,
                            row_index  => $curr_index,
                        }
                    );

                    my $rows = $record_obj->rows;
                    if ( defined $rows and $rows > 0 ) {
                        $status_msg =
                            __( "[_1] record updated in table '[_2]'",
                            $rows, $record_obj->name );
                    }
		    # run PostUpdate Events:
		    $self->RunEvent(
				    {   elementname => $blockname,
					eventtype   => 'PostUpdate',
					eventargs   => {
							record_obj => $record_obj,
							blockname  => $blockname
						       },
				    }
				   );
                }
            }
            else {
                $status_msg = __( "No update done in table '[_1]'?",
                    $record_obj->name ) if !$did_update;
            }

            if ( $max_repeats > $curr_index ) {
                $curr_index++;
                goto REPEAT;
            }
        }    # end label REPEAT
    }    # end label EXIT
    $self->form_status_msg($status_msg) if $status_msg;
}

##############################################################################
1;
