##############################################################################
# $Id: Tabular.pm,v 1.6 2006/09/22 09:53:46 heli Exp $
# Handling Tables
##############################################################################
package Apiis::Form::Tk::Tabular;

use warnings;
use strict;
our $VERSION = '$Revision: 1.6 $';

use Tk::Table;
use Data::Dumper;

sub _tabular {
   my ( $self, %args ) = @_;
   my $tabular    = $args{elementname};
   my $field_ref = $self->GetValue( $tabular, '_field_list' );
   my $count_cols = scalar @{$field_ref} if $field_ref; ## no critic
   my $rows       = $self->GetValue( $tabular, 'Rows' );
   my $maxrows    = $self->GetValue( $tabular, 'MaxRows' )||10;
   my $old_top    = $self->top;

   # create Tk::Table widget:
   my $table = $self->top->Table(
      -columns      => $count_cols || 0,
      -rows         => $rows || 0,
      -scrollbars   => $self->GetValue( $tabular, 'ScrollBars'   ) || '',
      -fixedrows    => $self->GetValue( $tabular, 'FixedRows'    ) || 0,
      -fixedcolumns => $self->GetValue( $tabular, 'FixedColumns' ) || 0,
   );

   # die Dumper($self->{_flat}{$tabular});
   $self->top( $table ); # change top level to tabular
   # $self->SetValue( $tabular, '_tabular_top', $table ); # for later use
   my %_done;
   my ( @fieldnames, @widgets, %tabular_template );
   my $misc_list_ref = $self->GetValue( $tabular, '_misc_blockelement_list' );
   foreach my $fieldname ( @$field_ref, @$misc_list_ref ) {
      my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
      my $tk_fieldtype = $self->fieldtype($fieldtype);
      next unless $tk_fieldtype;

      # require the widget module:
      my $module = 'Apiis::Form::Tk::' . $tk_fieldtype;
      if ( not exists $_done{$module} and not $self->can($module) ) {
         # load modules only once
         eval "require $module";  ## no critic
         if ($@) {
            $self->status(1);
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CODE',
                  severity  => 'CRIT',
                  from      => 'Apiis::Form::Tk::run',
                  msg_short => sprintf( "Error loading module '%s'", $module ),
                  msg_long  => scalar $@,
               )
            );
         } else {
            # push @ISA, $module;
         }
      }
      $_done{$module}++;

      # the commands are named after the Fieldtype, e.g _textfield for
      # type TextField or _label for type Label:
      my $command = $module . '::_' . $fieldtype;
      my $widget = $self->$command( elementname => $fieldname );
      if ( not defined $widget ) {
         $self->status(1);
         $self->errors(
            Apiis::Errors->new(
               type      => 'CODE',
               severity  => 'CRIT',
               from      => 'Apiis::Form::Tk::run',
               msg_short => &main::__( "Error loading module '[_1]'", $module ),
               msg_long  => &main::__( "Method '[_1]' returned no valid widget", $command
               ),
            )
         );
         $self->form_error( die => 0 );
      }
      push @fieldnames, $fieldname;
      push @widgets,    $widget;

      # store widgets in global reference:
      $self->PushValue( $fieldname, '_widget_refs', $widget );
      $tabular_template{$fieldname} = "$command"
        if $self->GetValue( $fieldname, 'Repeat' );
   }
   $self->SetValue( $tabular, '_tabular_template', \%tabular_template );

   my $j = 0;
   REPEAT: {
      ROW: for ( my $i = 0 ; $i <= $#widgets ; $i++ ) {
         my $field = $fieldnames[$i];
         my $widget = $widgets[$i];
         my $thisrow = $self->GetValue( $field, 'Row' );
         if ( $self->GetValue( $field, 'Repeat' ) ) {
            $thisrow += $j;
            if ( $j > 0 ) {
               # first row already done above
               # Now refer to the correct element of _data_refs:
               my $data_refs = $self->GetValue( $field, '_data_refs' );
               my $var;
               $data_refs->[$j] = \$var;
               $self->SetValue( $field, '_data_ref', $data_refs->[$j] );

               my $command       = $tabular_template{ $field };
               my $repeat_widget = $self->$command( elementname => $field );

               # store additional widgets also in global reference:
               $self->PushValue( $field, '_widget_refs', $repeat_widget );
               $table->put( $thisrow,
                  $self->GetValue( $field, 'Column' ),
                  $repeat_widget );
               next ROW;
            } else {
               $table->put( $thisrow,
                  $self->GetValue( $field, 'Column' ),
                  $widget );
            }
         } else {
            next if $j > 0;
            $table->put( $thisrow,
               $self->GetValue( $field, 'Column' ),
               $widget );
         }
      }
      $j++;
      goto REPEAT if $j <= $maxrows;
   } #end label REPEAT
   # print Dumper(\%tabular_template);
   # restore top level:
   $self->top($old_top);
   return $table;
}

1;

# vim:tw=80:cindent:aw:expandtab
