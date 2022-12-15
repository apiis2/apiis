use strict;
use warnings;
our $apiis;

#########################################################################
# noch offen
# - CheckRasse()
# - CheckBreeder()
# - db_zb_abt setzen
#########################################################################


#########################################################################
# - holt aus der Db die interne Nummer eines Tieres
# - wird keine Nummer gefunden, kann wahlweise eine Fehlermeldung 
#   ausgegeben werden oder das Tier neu erzeugt werden.
#   Folgende Keys müssen belegt sein
#   $args->{'ext_unit'}     = 10-herdbuch
#   $args->{'ext_id'}       = 1-32
#   $args->{'ext_animal'}   = 20000
#   $args->{'spitze'}       = 18
#   $args->{'createanimal'} = 1
#   $args->{'birth_dt'}     = 10.02.2009
#########################################################################   

sub GetDbAnimal {

    my $args        =shift;

    if (exists $args->{'db_animal'} and $args->{'db_animal'}) {
        return $args->{'db_animal'};
    }


    my $db_animal;

    #-- Notwendige Hash-Keys belegen 
    $args->{'ext_unit'}     ='' if (!exists $args->{'ext_unit'});
    $args->{'ext_id'}       ='' if (!exists $args->{'ext_id'});
    $args->{'ext_animal'}   ='' if (!exists $args->{'ext_animal'});

    #-- Wenn Nummer unvollständig ist, dann Fehlerobject erzeugen
    if (($args->{'ext_unit'}    eq '') or 
        ($args->{'ext_id'}      eq '')   or
        ($args->{'ext_animal'}  eq '')) {    

            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type       => 'DATA',
                    severity   => 'CRIT',
                    from       => 'LO',
                    ext_fields => ['ext_animal'],
                    msg_short  => "Tiernummer unvollständig: "
                        . $args->{'ext_unit'} . ' | '
                        . $args->{'ext_id'} . ' | '
                        . $args->{'ext_animal'} . '',
                )
            );
            goto ERR;
    }

    #-- Tiernummer holen und closing_dt für die Tiernummer holen 
    my $sql = "select a.db_animal, a.closing_dt 
               from entry_transfer a inner join unit on a.db_unit=unit.db_unit 
		       where (ext_unit   ='$args->{'ext_unit'}' and 
                      ext_id     ='$args->{'ext_id'}'   and 
                      ext_animal ='$args->{'ext_animal'}')";

    #-- SQL wegschreiben bei debug siehe apiisrc 
    $apiis->log('debug', "SQL: $sql");

    #-- SQL ausführen
    my $sql_ref = $apiis->DataBase->sys_sql( $sql );

    #-- Wenn SQL fehlerhaft, Fehlermeldung erzeugen unr Status setzen
    if ( $sql_ref->status and ( $sql_ref->status == 1 ) ) {
        $apiis->errors( scalar $sql_ref->errors );
        $apiis->status(1);
        goto ERR;
    }
    
    # Auslesen des Ergebnisses der Datenbankabfrage
    my @animals;
    while ( my $q = $sql_ref->handle->fetch ) {
        push( @animals, [@$q]);
    }

    #-- Wenn @animals leer, dann gibt es keine Nummer
    #-- Fehlermeldung 
    if (!@animals) {
        
        #-- aus Wurfdaten ein Tier anlegen
        if (exists $args->{'createanimal'} and $args->{'createanimal'} ) {

            $db_animal=CreateAnimal($args);
            goto ERR;
        }

        #--Fehlermeldung erzeugen und Ende  
        else {
            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type       => 'DATA',
                    severity   => 'CRIT',
                    from       => 'LO',
                    ext_fields => ['ext_animal'],
                    msg_short  => "Keine Tiernummer gefunden: "
                        . $args->{'ext_unit'} . ' | '
                        . $args->{'ext_id'} . ' | '
                        . $args->{'ext_animal'} . '',
                )
            );
            goto ERR;
        }
    }
   
    #-- Wenn es mehrere Nummer gibt, dann offene heraussuchen 
    my $ds;
    for (my $i=0; $i<=$#animals; $i++) {

        #-- Datensatznummer übergeben, wenn offener Kanal (nur einer möglich)
        $ds=$i if (!$animals[0]->[1]);
    }

    #-- Wenn $ds definiert ist, gibt es einen offenen Nummern kanal
    if ( defined $ds ) {
        return $animals[$ds]->[0];
    }
    
    #-- Wenn kein offner Nummernkanal, dann Fehler auslösen 
    else {
            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type       => 'DATA',
                    severity   => 'CRIT',
                    from       => 'LO',
                    ext_fields => ['ext_animal'],
                    msg_short  => "Tiernummer geschlossen: "
                        . $args->{'ext_unit'} . ' | '
                        . $args->{'ext_id'} . ' | '
                        . $args->{'ext_animal'} . '',
                )
            );
        goto ERR;
    }

ERR:        
    return $db_animal;
}
1;
