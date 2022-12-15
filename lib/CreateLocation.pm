use strict;
use warnings;

our $apiis;

#########################################################################
# - holt aus der Db die interne Nummer eines Tieres
# - wird keine Nummer gefunden, kann wahlweise eine Fehlermeldung 
#   ausgegeben werden oder das Tier neu erzeugt werden.
#   Folgende Keys müssen belegt sein
#   $args->{'db_animal'}    = 100000
#
#   $args->{'entry_dt'}     = '01.01.2006
#   $args->{'exit_dt'}      = '01.02.2006
#
#   $args->{'ext_unit_location'} = pruefort
#   $args->{'ext_id_location'}   = 13
#
#   $args->{'ext_exit_action'}   = sale
#   $args->{'ext_entry_action'}   = buy
#
#   $args->{'ext_location'}       = 
#   $args->{'entry_dt'}           =
#   $args->{'exit_dt'}            =

#########################################################################   

sub CreateLocation {

    my $args        =shift;

    #-- für den neuen Besitzer einen neuen Datensatz anlegen
    my $locations = Apiis::DataBase::Record->new( tablename => 'locations' );
        
    #-- interne Tiernummer, muss nicht mehr decodiert werden 
    $locations->column( 'db_animal' )->intdata( $args->{'db_animal'} );
    $locations->column( 'db_animal' )->encoded( 1 );
    $locations->column( 'db_animal' )->ext_fields( 'ext_animal' );

    #-- Ort 
    $locations->column( 'db_location' )->extdata(  $args->{'ext_unit_location'},$args->{'ext_id_location'} );
    $locations->column( 'db_location' )->ext_fields( 'ext_id_location' );
        
    #-- Ankaufsdatum 
    if (!exists $args->{'entry_dt'}) {
        $args->{'entry_dt'}=$apiis->today();
    }

    $locations->column( 'entry_dt' )->extdata( $args->{'entry_dt'} );
    $locations->column( 'entry_dt' )->ext_fields( 'entry_dt' );

    #-- Ankaufsgrund 
    if (!exists $args->{'ext_entry_action'}) {
        $args->{'ext_entry_action'}='init';
    }
    if ((!exists $args->{'ext_exit_action'}) and (exists $args->{'exit_dt'})) {
        $args->{'ext_exit_action'}='exit';
    }


    $locations->column( 'db_entry_action' )->extdata( $args->{'ext_entry_action'} );
    $locations->column( 'db_entry_action' )->ext_fields( 'ext_entry_action' );

    if ($args->{'exit_dt'} ) {
        #-- Exit-Datum = Schlachtdatum
        $locations->column( 'exit_dt' )->extdata( $args->{'exit_dt'} );
        $locations->column( 'exit_dt' )->ext_fields( 'exit_dt' );
            
        #-- Verkfaufsgrund
        $locations->column( 'db_exit_action' )->extdata( $args->{'ext_exit_action'} );
        $locations->column( 'db_exit_action' )->ext_fields( 'ext_exit_action' );
    }    

    #-- neuen DS anlegen 
    $locations->insert;

    #-- Fehlerobject initialisieren, wenn kein Insert möglich 
    if ( $locations->status ) {
        $apiis->errors( scalar $locations->errors );
        $apiis->status( 1 );
    }

    return;
}
1;

