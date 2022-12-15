##############################################################################
# $Id: CallForm.pm,v 1.14 2014/12/08 08:56:55 heli Exp $
# opens new Form
##############################################################################
package Apiis::Form::Event::CallForm;

use strict;
use warnings;
use Carp;

use Apiis;
use Apiis::Misc qw( is_true );
use base 'Apiis::Init';
our $apiis;
use JSON::XS;

sub callform {
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
                    backtrace => Carp::longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'eventname', __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # get parameters for this event:
        my $parameter_ref = $self->get_event_par_ref( { eventname => $event } );
        last EXIT if !$parameter_ref;

        my $formname = $parameter_ref->{'formname'}[0];
        if ( not defined $formname ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'Apiis::Form::Event::_call_form',
                    backtrace => Carp::longmess('invoked'),
                    msg_short => sprintf(
                        q{No key '%s' passed to '%s'},
                        q{formname}, __PACKAGE__
                    ),
                )
            );
            last EXIT;
        }

        # get the right form path:
        if ( !-f $formname ) {
            $formname = $apiis->formpath . '/' . $formname;
        }
        if ( !-f $formname ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'CRIT',
                    from      => __PACKAGE__,
                    msg_short =>
                        sprintf( "XML file '%s' does not exist", $formname ),
                )
            );
            last EXIT;
        }

        # create the new form:
        my $gui_type  = $self->gui_type;                         # Tk, HTML, ...
        my $module    = 'Apiis::Form::' . $gui_type;
        my $new_f_obj = $module->new( xmlfile => $formname, );

        if ( $new_f_obj->status ) {
            $self->status(1);
            $self->errors( scalar $new_f_obj->errors );
            last EXIT;
        }

        my $from_master_ref = $parameter_ref->{'master_sourcefield'};
        my $to_client_ref   = $parameter_ref->{'client_targetfield'};
        my $disable_source_ref   = $parameter_ref->{'disable_sourcefield'};
        my $disable_target_ref   = $parameter_ref->{'disable_targetfield'};

        if ($from_master_ref) {
            for my $idx ( 0 .. @$from_master_ref - 1 ) {
                my $src_data_ref =
                    $self->GetValue( $from_master_ref->[$idx], '_data_ref' );
                my $target_data_ref =
                    $new_f_obj->GetValue( $to_client_ref->[$idx], '_data_ref' );
                $$target_data_ref = $$src_data_ref if $src_data_ref;
                $idx++;
            }
        }

        #-- Sourcen mit Parametern aktualisieren 
        $new_f_obj->Apiis::Form::Init::DataSource::_get_datasources;

        # Initial query is config option as we don't always want one:
        my $do_query = $parameter_ref->{'initial_query'}[0];
        if ( is_true($do_query) ) {
            for my $block ( $new_f_obj->blocknames ) {
                $new_f_obj->query_block( { blockname => $block } );
            }
        }
        # last EXIT if $new_f_obj->status;

        # run the subform (Tk must wait for the results):
        my ( $wait_for, %run_args );
        if ( lc $gui_type eq 'tk' ) {
            $wait_for = 0;
            %run_args = (
                toplevel     => $self->top,
                waitvariable => \$wait_for,    # ignored by HTML
            );
            $new_f_obj->run( \%run_args );
            $self->top->waitVariable( \$wait_for );
        }
        else {
            my $query = CGI->new();
            $new_f_obj->{'_query'} = $query;
	    
            my $jsond = JSON::XS->new->utf8->decode ( $self->{_cgi}->{json} );
#           my $json = JSON->new( unmapping=>1);
#   	    my $jsond= $json->from_json($self->{_cgi}->{json});
            if ($parameter_ref->{'disable_sourcefield'}) {
	      for (my $i=0;$i<=$#{$parameter_ref->{'disable_targetfield'}}; $i++) {
	        if (($jsond->{data}[0]->{ $parameter_ref->{'disable_sourcefield'}[$i]  }[0] eq "") or 
		    ($jsond->{data}[0]->{ $parameter_ref->{'disable_sourcefield'}[$i]  }[0] == 0)) {
		      $new_f_obj->{'_disable_targetfield'}->{ $parameter_ref->{'disable_targetfield'}[$i]  }=1
		}
	      }
	    }  
            $new_f_obj->{'_cgi'}   = $self->{'_cgi'};
            $new_f_obj->PrintHeaderInit();
            $new_f_obj->CreateJSONData( { 'newform' => '1' } );
            $self->{newform}->{data}    = $new_f_obj->PrintBody();
            $self->{newform}->{name}    = $new_f_obj->formname;
            $self->{newform}->{options} = $new_f_obj->{_formoptions};
        }

        # now propagate the values to the invoking form:
        my $from_client_ref = $parameter_ref->{'client_sourcefield'};
        my $to_master_ref   = $parameter_ref->{'master_targetfield'};

        if ($from_client_ref) {
            for my $idx ( 0 .. @$from_client_ref - 1 ) {
                my $src_data_ref =
                    $new_f_obj->GetValue( $from_client_ref->[$idx],
                    '_data_ref' );
                my $target_data_ref =
                    $self->GetValue( $to_master_ref->[$idx], '_data_ref' );
                $$target_data_ref = $$src_data_ref if $src_data_ref;
                $idx++;
            }
        }
    }    # end label EXIT
    return;
}
##############################################################################

1;

__END__

=head2 _call_form

input: eventname
output: none (another form is invoked)

event parameters are defined in the XML file:

   formname (required)
   [master|client]_sourcefield (optional)
   [master|client]_targetfield (optional)

=cut

