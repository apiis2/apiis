##############################################################################
# $Id: Query.pm,v 1.41 2014/12/08 08:56:55 heli Exp $
# Provides methods to navigate in a form's query.
##############################################################################
package Apiis::Form::Event::Query;

use strict;
use warnings;
use Apiis;
use base 'Apiis::Init';
use List::Util qw( first );
our $apiis;

sub _query_block {
   my ( $self, $arg_ref ) = @_;

   # get order of query blocks once:
   &Apiis::Form::Event::Query::_get_query_block_order
     if not $self->query_block_order;

   EXIT: {
      my $blockname = $arg_ref->{'blockname'};
      if ( not defined $blockname ) {
         $self->status(1);
         $self->errors(
            Apiis::Errors->new(
               type      => 'PARAM',
               severity  => 'ERR',
               from      => 'Apiis::Form::Event::_query_block',
               msg_short => sprintf( "No key '%s' passed to '%s'",
                            'blockname', __PACKAGE__),
               backtrace => Carp::longmess('invoked'),
            )
         );
         last EXIT;
      }

      my $ds_name = $self->GetValue( $blockname, 'DataSource' );
      last EXIT if $self->GetValue( $ds_name, 'Type' ) eq 'none';

      # check for changes, even if a new query is started:
      $self->Apiis::Form::Event::Query::_check_changes($blockname);
      last EXIT if $self->status;

      if ( $arg_ref->{'navigate'} ) {
         # query already done, just navigate:
         next if lc $self->GetValue( $blockname, 'Type' ) eq 'tabular';
         my $nav = 'Apiis::Form::Event::Query::' . $arg_ref->{'navigate'};
         no strict 'refs';  ## no critic please :^)
         $self->$nav($ds_name);
      } else {
         # create new query:
         $self->Apiis::Form::Event::Query::_get_query_records($ds_name);
      }
      last EXIT if $self->status;

      # show the record(s) of this block:
      $self->Apiis::Form::Event::Query::_show($ds_name);
      last EXIT if $self->status;

      # workaround, only messages of the masterblock are displayed:
      if ( $self->master_detail ) {
         $self->Apiis::Form::Event::Query::create_msg($ds_name)
           if $self->GetValue( $blockname, '_is_masterblock' );
      } else {
         $self->Apiis::Form::Event::Query::create_msg($ds_name);
      }
      last EXIT if $self->status;

      # trigger queries of detailblocks, if any:
      if ( $self->GetValue( $blockname, '_is_masterblock' ) ) {
          if ( defined $self->GetValue( $ds_name, '__max_index' ) ) {
              my $block_ref = $self->GetValue( $blockname, '_detailblocks' );
              for my $block (@$block_ref) {
                  $self->Apiis::Form::Event::Query::_query_block(
                      { blockname => $block } );
              }
          }
      }
      last EXIT if $self->status;
   }
}

sub _check_changes {
   my ( $self, $blockname ) = @_;
   my $ds_name = $self->GetValue( $blockname, 'DataSource' );


   # no query done before:
   return unless $self->GetValue($ds_name, '__query_records');
   my $rowid   = $self->GetValue( $ds_name,   '__rowid' );

   if ( defined $rowid ) {
      $self->update_block( { blockname => $blockname, implicit => 1 } );
   } else {
      $self->insert_block( { blockname => $blockname, implicit => 1 } );
   }
}

##############################################################################
# sort blocks in dependency of their relations (master/detail):
sub _get_query_block_order {
   my $self = shift;
   return if $self->query_block_order;    # already done

   my ( %blocks_seen, @blocksort, %blocksort );
   my $allblocks = scalar @{ $self->blocknames };
   UNSORTED: {
      for my $blockname ( $self->blocknames ) {
         next if $blocks_seen{$blockname};
         $blocks_seen{$blockname} = 1;
         if ( $self->GetValue( $blockname, '_is_masterblock' ) ) {
            if ( $self->GetValue( $blockname, '_is_detailblock' ) ) {
               push @blocksort,
                 @{ $self->GetValue( $blockname, '_detailblocks' ) };
               goto UNSORTED;             # restart loop
            } else {
               # ok, found the root block
               push @blocksort, $blockname;
               push @blocksort,
                 @{ $self->GetValue( $blockname, '_detailblocks' ) };
               goto UNSORTED;             # restart loop
            }
         }
         if ( $self->GetValue( $blockname, '_is_detailblock' ) ) {
            # already added above
            next;
         }
         push @blocksort, $blockname;
         last UNSORTED if scalar @blocksort == $allblocks;
      }
   }
   $self->query_block_order( \@blocksort );
}
##############################################################################
# Navigation:
sub _next {
   my ( $self, $ds_name ) = @_;
   return unless defined $self->GetValue( $ds_name, '__max_index' );
   # increment index:
   if ( $self->GetValue( $ds_name, '__curr_index' ) <
      $self->GetValue( $ds_name, '__max_index' ) )
   {
      $self->IncValue( $ds_name, '__curr_index' );
   } else {
      # start from beginning
      $self->SetValue( $ds_name, '__curr_index', 0 );
   }
}

sub _prev {
   my ( $self, $ds_name ) = @_;
   return unless defined $self->GetValue( $ds_name, '__max_index' );
   # decrement index:
   if ( $self->GetValue( $ds_name, '__curr_index' ) > 0 ) {
      $self->DecValue( $ds_name, '__curr_index' );
   } else {
      # wrap around:
      $self->SetValue( $ds_name, '__curr_index',
         $self->GetValue( $ds_name, '__max_index' ) );
   }
}

sub _first { $_[0]->SetValue( $_[1], '__curr_index', 0 ) }

sub _last {
   return unless defined $_[0]->GetValue( $_[1], '__max_index' );
   $_[0]->SetValue(
      $_[1], '__curr_index',
      $_[0]->GetValue( $_[1], '__max_index' )
   );
}

sub create_msg {
   my ( $self, $ds_name ) = @_;
   my $blockname = $self->GetValue( $ds_name, '_parent' );
   my $status_msg;
   if ( defined $self->GetValue( $ds_name, '__max_index' ) ) {
      my $max  = $self->GetValue( $ds_name, '__max_index' ) + 1;
      my $curr = $self->GetValue( $ds_name, '__curr_index' ) + 1;
      $status_msg = __('Record') . ": $curr/$max";
   } else {
      $status_msg = __('Query retrieved no records');
   }
   $self->form_status_msg("$blockname: $status_msg");
}
##############################################################################
# Get the appropriate record object via the $index and fill the field
# variables with the data.
sub _show {
    my ( $self, $ds_name ) = @_;
    my $index         = $self->GetValue( $ds_name, '__curr_index' );
    my $q_records_ref = $self->GetValue( $ds_name, '__query_records' );
    my @columns       = @{ $self->GetValue( $ds_name, '_column_list' ) };
    my $max_rows      = 0;    # how many repeats of _data_refs, if any
    
    #--max_rows = Number of records from query      
    $max_rows      = @{$q_records_ref} if ($q_records_ref); #mue

    my $curr_row      = 0;    # start with first row in _data_refs
    my $rowid_name    = $apiis->DataBase->rowid;
    my $blockname     = $self->GetValue( $ds_name, '_parent' );

    if ( defined $q_records_ref and scalar @$q_records_ref ) {
        $self->clear_block(
            {   blockname => $blockname,
                veryclean => 0,            # don't delete __query_records
            }
        );

        # set $max_rows if we have a repeat field:
        NEED_REPEAT:
        foreach my $thiscol (@columns) {
            my $fieldname = $self->GetValue( $thiscol, '_field' );
            next NEED_REPEAT if !defined $fieldname;
            if ( $self->GetValue( $fieldname, 'Repeat' ) ) {
                $max_rows = scalar @{$q_records_ref};
                last NEED_REPEAT;
            }
        }


        REPEAT: {
            my $thisrec = $q_records_ref->[$index];
            last REPEAT unless defined $thisrec;

            # store rowid of currently displayed record:
            my $rowid = $thisrec->column($rowid_name)->intdata;
            $self->SetValue( $ds_name, '__rowid', $rowid );

            # look for IdSet definitions before decoding:
            for my $thiscol (@columns) {
                my $idset_ref = $self->GetValue( $thiscol, '_idset_list' );
                if ($idset_ref) {
                    my @id_sets;
                    push @id_sets, $self->GetValue( $_, 'SetName' )
                        for @$idset_ref;
                    my $db_col = $self->GetValue( $thiscol, 'DBName' );
                    $thisrec->column($db_col)->id_set( \@id_sets );
                }
            }

            # decode and mirror always, as any changes will be auto-committed:
            $thisrec->decode_record;
            $thisrec->mirror_record;

            # load fields from record object:
            $self->_ro2fields(
                {   datasource => $ds_name,
                    record_obj => $thisrec,
                    row_index  => $curr_row,
                }
            );

            if ( $max_rows > $curr_row ) {
                # increment counters for repeated fields (e.g. in Tabular):
                $index++;
                $curr_row++;
                goto REPEAT;
            }
            $self->form_error( die => 0 ) if $self->status;
        }    # end REPEAT
    }
    else {
        # reset data_ref from fields to undef:
        RCOL:
        foreach my $thiscol (@columns) {
            my $thisfield = $self->GetValue( $thiscol, '_field' );
            next RCOL if !defined $thisfield;
            my @data_refs = @{ $self->GetValue( $thisfield, '_data_refs' ) };
            for ( my $i = 0; $i <= $#data_refs; $i++ ) {
                my $data_ref = $data_refs[$i];
                $$data_ref = undef;
            }
        }
    }
}

##############################################################################
# Fetches the record objects for this query and returns an arrayref to the
# list of record objects.
sub _get_query_records {
   my ($self, $ds_name) = @_;
   $self->SetValue( $ds_name, '__curr_index', 0 ); # reset index
   $self->SetValue( $ds_name, '__max_index', undef );
   my $status_msg;
   my $do_query = 0;

   EXIT: {
      last EXIT if lc $self->GetValue($ds_name,'Type') ne 'record';
      # create record object
      my $record_obj = Apiis::DataBase::Record->new(
         tablename => $self->GetValue($ds_name,'TableName'),
      );
      if ( $record_obj->status ){
         $self->status(1);
         $self->errors( scalar $record_obj->errors );
         $record_obj->del_errors;
         last EXIT;
      }
      
      my @db_col_list;
      my @ds_columns = @{ $self->GetValue( $ds_name, '_column_list' ) };

      # check for UseEntryView-flag in each column:
      for my $ds_col ( @ds_columns ){
          my $use_entry_view = $self->GetValue( $ds_col, 'UseEntryView' );
          if ( $use_entry_view ){
              my $db_col = $self->GetValue( $ds_col, 'DBName' );
              $record_obj->column($db_col)->use_entry_view(1);
          }
      }

      my $blockname = $self->GetValue( $ds_name, '_my_block' );
      if ( $self->GetValue( $blockname, '_is_detailblock' ) ){
         # detailfields have only one query argument, the data in MasterColumn:
         my $detailcol   = $self->GetValue( $blockname,   'DetailColumn' );
         my $db_col      = $self->GetValue( $detailcol, 'DBName' );
         my $mastercol   = $self->GetValue( $blockname,   'MasterColumn' );
         my $masterfield = $self->GetValue( $mastercol, '_field' );
         my $masterdata  = ${ $self->GetValue( $masterfield, '_data_ref' ) };
      
         # if (list)field has its own datasource:
         $masterdata = $self->decode_list_ref( $masterfield, $masterdata )
            if $self->GetValue($masterfield, '_my_field_datasource');
      
         $record_obj->column($db_col)->intdata($masterdata);
         $record_obj->column($db_col)->encoded(1);

         # propagate id_set definitions if there are any:
         my $idset_ref = $self->GetValue( $detailcol, '_idset_list' );
         if ($idset_ref) {
             my @id_sets;
             push @id_sets, $self->GetValue( $_, 'SetName' ) for @$idset_ref;
             $record_obj->column($db_col)->id_set(\@id_sets);
         }

         foreach my $thiscol ( @ds_columns ) {
            next if $self->GetValue( $thiscol, 'Type' ) ne 'DB';
            push @db_col_list, $self->GetValue( $thiscol, 'DBName' );
         }
         $do_query++;
      } else {
         $apiis->log('debug',
             "_get_query_records: going to collect data for query");
         my ( %related_columns );
         COLUMN2:
         foreach my $thiscol (@ds_columns) {
            my $fieldname = $self->GetValue( $thiscol, '_field' );
            next COLUMN2 if !defined $fieldname;
            my $data = ${ $self->GetValue( $fieldname, '_data_ref' ) };
            my $coltype = $self->GetValue( $thiscol, 'Type' );
            if ( $coltype eq 'Related' ) {
               # store only if data is not empty and 
               # the previous related column were all filled
               my $rel_col = $self->GetValue( $thiscol, 'RelatedColumn' );
               my $db_col  = $self->GetValue( $rel_col, 'DBName' );
               my $order   = $self->GetValue( $thiscol, 'RelatedOrder' );

               # just define 'is_not_empty' as it does not exist the first time:
               $related_columns{$db_col}{'is_not_empty'} = -1 if (not exists $related_columns{$db_col}{'is_not_empty'});
	       $related_columns{$db_col}{'is_not_empty'} = 0 if (not defined  $data or $data eq '');
	       # if 'is_not_empty' is 0 then at least one related column was undefined, skip the others:
	       next COLUMN2 unless ($related_columns{$db_col}{'is_not_empty'});
               $related_columns{$db_col}{'order'}[$order] = $data;
               $related_columns{$db_col}{'is_not_empty'} = 1 
                 if defined $data
                 and $data ne '';
               # unresolved/ToDo: if the related column points into
               # another datasource/table. Not quite easy :^(
            } elsif ( $coltype eq 'DB' ) {
               my $db_col = $self->GetValue( $thiscol, 'DBName' );
               push @db_col_list, $db_col;
               if ( defined $data and $data ne '' ) {
                   $data = $self->decode_list_ref( $fieldname, $data )
                       if $self->GetValue( $fieldname, '_my_field_datasource' );
                   if ( $self->GetValue( $fieldname, '_displays_intdata' ) ) {
                       $record_obj->column($db_col)->intdata($data);
                       $record_obj->column($db_col)->encoded(1);
                   }
                   else {
                       # if (list)field has its own datasource:
                       $record_obj->column($db_col)->extdata($data);
                   }
               
                   # propagate id_set definitions if there are any:
                   my $idset_ref = $self->GetValue( $thiscol, '_idset_list' );
                   if ($idset_ref) {
                       my @id_sets;
                       push @id_sets, $self->GetValue( $_, 'SetName' )
                           for @$idset_ref;
                       $record_obj->column($db_col)->id_set($idset_ref);
                   }
                   $do_query++;
               }
            }
         }
         # if we have related columns store the array of external data in
         # the related Column:
         DB_COL:
         foreach my $db_col ( keys %related_columns ) {
            next DB_COL if ! $related_columns{$db_col}{'is_not_empty'};
            $record_obj->column($db_col)->extdata(
                $related_columns{$db_col}{'order'} );
            $do_query++;
         }
      }
      
      if ($do_query) {
         my @q_records = $record_obj->fetch(
             expect_columns => \@db_col_list,
         );
         if ( $record_obj->status ) {
            $self->status(1);
            $self->errors( scalar $record_obj->errors );
            $record_obj->del_errors;
            last EXIT;
         } else {
            if ( $#q_records == -1 ) {
               # clear block if query got no records:
               $self->clear_block( { blockname => $blockname } );
               $self->SetValue( $ds_name, '__max_index', undef );
               my $detail =  $self->GetValue( $blockname, '_is_detailblock' );
               if ( !$detail ) {
                   $self->form_status_msg(__("This query retrieved no record"));
               }
            } else {
               $self->SetValue( $ds_name, '__max_index', $#q_records );
               # store the record objects for each datastream:
               $self->SetValue( $ds_name, '__query_records', \@q_records );
            }
         }
      } else {
         $self->form_status_msg(
             __('You want to query and did not pass parameters') );
      }
   } # end label EXIT
   return;
}
##############################################################################
1;

