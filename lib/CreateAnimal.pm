use strict;
use warnings;
use CreateLocation;

our $apiis;

#########################################################################
# - holt aus der Db die interne Nummer eines Tieres
# - wird keine Nummer gefunden, kann wahlweise eine Fehlermeldung 
#   ausgegeben werden oder das Tier neu erzeugt werden.
#   Folgende Keys müssen belegt sein
#   $args->{'ext_unit'}     = 10-herdbuchnummer
#   $args->{'ext_id'}       = 1-32
#   $args->{'ext_animal'}   = 20000
#   $args->{'spitze'}       = 18
#   $args->{'birth_dt'}     = 10.02.2009
#########################################################################   

sub CreateAnimal {

    my $args        =shift;

    my $db_animal;
    
    #-- übergebene Keys auf von undef => ''
    map { if (!$args->{$_}) {$args->{$_}=''}  } keys %$args;

    #-- Neue Tiernummer holen 
    $args->{'db_animal'} = $apiis->DataBase->seq_next_val('seq_transfer__db_animal');
    
    #------------------------- Transfer --------------------------
    
    #-- mit den Wurfdaten ein neues Tier in transfer erzeugen
    my $transfer = Apiis::DataBase::Record->new( tablename => 'transfer' );

    #-- interne Tiernummer
    $transfer->column('db_animal')->intdata($args->{'db_animal'});
    $transfer->column('db_animal')->encoded(1);
    $transfer->column('db_animal')->ext_fields(qw /ext_animal/);

    #-- ext_animal
    $transfer->column('ext_animal')->extdata( $args->{ 'ext_animal' } );
    $transfer->column('ext_animal')->ext_fields( 'ext_animal');

    #-- db_unit 
    $transfer->column('db_unit')->extdata( $args->{'ext_unit'}, $args->{'ext_id'} );
    $transfer->column('db_unit')->ext_fields( 'ext_animal' );

    #-- opening_dt 
    my $od = $args->{ 'birth_dt' } ;

    #-- opening_dt muss besetzt sein: mit aktuellem Datum, falls undef
    $od = $apiis->now  if ( !$od or ( $od eq '' ) );
    $transfer->column('opening_dt')->extdata( $od );
    $transfer->column('opening_dt')->ext_fields( 'ext_animal' );
 
    #-- id_set
    $transfer->column( 'id_set' )->extdata( $args->{'ext_unit'} );
    $transfer->column( 'id_set' )->ext_fields( 'ext_animal' );

    #-- neuen Eintrag in Transfer  
    $transfer->insert();

    #-- Fehlerbehandlung 
    if ( $transfer->status ) {
         $apiis->status(1);
         $apiis->errors( scalar $transfer->errors );

         goto ERR;
    }

    $args->{'db_animal'} = $transfer->column('db_animal')->intdata;

    #------------------------- Animal --------------------------

    #-- Tabelle animal befüllen
    my $animal = Apiis::DataBase::Record->new( tablename => 'animal', );

    #-- Schleife über alle zu befüllenden Spalten der Tabelle 
    foreach my $col ( @{ $apiis->Model->table( 'animal' )->cols }) {

        #-- externe_spalten
        my $ext_col=$col;
        $ext_col   =~s/^db_/ext_/g;

        #-- Spalten wie in Tabelle 
        if (($args->{$col}) and ($args->{$col} ne '')) {

            #--  
            if (( $col eq 'db_animal')      or ( $col eq 'db_dam') or
                ( $col eq 'db_sire')        or ( $col eq 'db_sex') or
                ( $col eq 'db_breed')       or ( $col eq 'db_selection' ) or 
                ($col eq 'db_test_result')  or ($col eq 'db_zb_abt' ) or
                ($col eq 'db_leaving' )     or ($col eq 'db_breeder' ) or
                ($col eq 'db_society' )     ) {

                #-- auf intern umstellen 
                $animal->column( $col )->intdata( $args->{ $col } );
                $animal->column( $col )->encoded(1);
            }
            else {
                $animal->column( $col) ->extdata( $args->{ $col });
            }


            $animal->column( $col )->ext_fields( $col);
        }

        #-- externe Werte 
        elsif (($args->{$ext_col}) and ($args->{$ext_col} ne ''))  {

            if ($col eq 'db_animal') {
                $animal->column( $col) ->extdata( $args->{ 'ext_unit' }, $args->{ 'ext_id' }, $args->{ 'ext_animal' } );
            }
            if ($col eq 'db_sire') {
                $animal->column( $col) ->extdata( $args->{ 'ext_unit_sire' }, $args->{ 'ext_id_sire' }, $args->{ 'ext_animal_sire' } );
            }
            if ($col eq 'db_dam') {
                $animal->column( $col) ->extdata( $args->{ 'ext_unit_dam' }, $args->{ 'ext_id_dam' }, $args->{ 'ext_animal_dam' } );
            }
            if ($col eq 'db_breeder') {
                $animal->column( $col) ->extdata( 'breeder',  $args->{ 'ext_breeder' } );
            }
            if ($col eq 'db_society') {
                $animal->column( $col) ->extdata( 'society',  $args->{ 'ext_society' } );
            }
            if ($col eq 'db_sex') {
                $animal->column( $col) ->extdata( $args->{ 'ext_sex' } );
            }
            if ($col eq 'db_breed') {
                $animal->column( $col) ->extdata( $args->{ 'ext_breed' } );
            }
            if ($col eq 'db_leaving') {
                $animal->column( $col) ->extdata( $args->{ 'ext_leaving' } );
            }
            if ($col eq 'db_selection') {
                $animal->column( $col) ->extdata( $args->{ 'ext_selection' } );
            }
            if ($col eq 'db_zb_abt') {
                $animal->column( $col) ->extdata( $args->{ 'ext_zb_abt' } );
            }
            if ($col eq 'db_test_result') {
                $animal->column( $col) ->extdata( $args->{ 'ext_test_result' } );
            }
            
            $animal->column( $col )->ext_fields($ext_col);
        }
    }

    #-- neuen Eintrag in Animal  
    $animal->insert();

    #-- Fehlerbehandlung 
    if ( $animal->status ) {
         $apiis->status(1);
         $apiis->errors( scalar $animal->errors );

         goto ERR;
    }

    #------------------------- Location  --------------------------
    if (exists $args->{'ext_id_location'} and ($args->{'ext_id_location'} ne '')) {
        
        CreateLocation($args);
    }

ERR:      

    if ($apiis->status) {
        return undef;
    }
    else {
        return $args->{'db_animal'};
    }
}
1;
