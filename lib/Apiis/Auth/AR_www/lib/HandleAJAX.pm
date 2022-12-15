package ARM::HandleAJAX;
##############################################################################
# $Id: HandleAJAX.pm,v 1.3 2006/07/22 11:09:48 marek Exp $
##############################################################################
use Apiis::Init;
use open ':utf8';
use open ':std';

=head1 NAME

HandleAJAX.pm

=head1 DESCRIPTION
 
   This module is responsible for handling all AJAX actions.

=cut

######################################################################

sub main {
    my ( $action, $form_input ) = @_;
    my $results_string;

    $action =~ /^ajax(.*)/;
    my $form = $1;

    if ( $form eq "descriptors_define_sql" ) {
        $results_string = descriptors_define_sql( $form_input->{'sql'} );
    }

    return $results_string;
}

sub descriptors_define_sql {
    my $sql = shift;
    my $results_string;

    EXIT: {
        my $sql_ref_1 = $apiis->DataBase->sys_sql($sql);
        if ( $sql_ref_1->status ) {
            $apiis->errors( $sql_ref_1->errors );
            $results_string =
                  @{ $apiis->errors }[0]->msg_short . " --> "
                . @{ $apiis->errors }[0]->msg_long;
            last EXIT;
        }

        my @results;
        my $rows = $sql_ref_1->handle->rows;
        $apiis->log( 'debug', "Numbers of returned rows: " . $rows );

        if ($rows) {
            while ( my @ret = $sql_ref_1->handle->fetchrow_array ) {
                my $value = $ret[0];
                if ( $value ne '' and !( grep ( /^$value$/, @results ) ) ) {
                    push @results, $value;
                }
            }
            $results_string = join( ', (=)', @results );
            $results_string = join( '', "(=)", $results_string );
        }
        else {
            $results_string = __("No records returned.");
        }
    }
    return $results_string;
}

######################################################################

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

1;
