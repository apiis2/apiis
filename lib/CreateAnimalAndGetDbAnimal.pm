use strict;
use warnings;
use CreateAnimal;

#########################################################################
# - holt aus der Db die interne Nummer eines Tieres
# - wird keine Nummer gefunden, kann wahlweise eine Fehlermeldung 
#   ausgegeben werden oder das Tier neu erzeugt werden.
#   Folgende Keys müssen belegt sein
#   $args->{'ext_unit'}     = 10-herdbuchnummer
#   $args->{'ext_id'}       = 1-32
#   $args->{'ext_animal'}   = 20000
#   $args->{'spitze'}       = 18
#   $args->{'createanimal'} = 1
#   $args->{'createanimalonlyfromlitter'}=1 -> Abbruch, wenn kein Wurf
#   $args->{'createdam}     =1 -> Abbruch, wenn kein Wurf
#   $args->{'birth_dt'}     = 10.02.2009
#   $args->{'db_dam'}       = 12345
########################################################################### 

sub CreateAnimalAndGetDbAnimal {

    my $args        =shift;

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
            goto Exit;
    }

    #-- Tiernummer holen und closing_dt für die Tiernummer holen 
    my $sql = "select db_animal, transfer.closing_dt 
               from transfer inner join unit on transfer.db_unit=unit.db_unit 
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
        goto Exit;
    }
    
    # Auslesen des Ergebnisses der Datenbankabfrage
    my @animals;
    while ( my $q = $sql_ref->handle->fetch ) {
        push( @animals, [@$q]);
    }

    #-- Wenn @animals leer, dann gibt es keine Nummer
    #-- Fehlermeldung 
    if (!@animals) {
       
        #-- Wenn eine Nummer erstellt werden soll 
        if ($args->{'createanimal'}) {
            
            #-- aus Wurfdaten ein Tier anlegen
            if (        $args->{'db_dam'}
                    and $args->{'createanimalonlyfromlitter'}) {

                #-- SQL zum Wurf heraussuchen
                my $sql = "select a.db_animal, a.db_sire, a.delivery_dt 
                        from litter a 
                        where a.db_animal    =$args->{'db_dam'} and
                                a.delivery_dt  =TO_DATE('".$args->{'birth_dt'}."','DD MM YYYY')";

                #-- SQL wegschreiben bei debug siehe apiisrc 
                $apiis->log('debug', "SQL: $sql");

                #-- SQL ausführen
                my $sql_ref = $apiis->DataBase->sys_sql( $sql );

                #-- Wenn SQL fehlerhaft, Fehlermeldung erzeugen unr Status setzen
                if ( $sql_ref->status and ( $sql_ref->status == 1 ) ) {
                    $apiis->errors( scalar $sql_ref->errors );
                    $apiis->status(1);
                    goto Exit;
                }
                
                # Auslesen des Ergebnisses der Datenbankabfrage
                my @wuerfe;
                while ( my $q = $sql_ref->handle->fetch ) {
                    push( @wuerfe, [@$q]);
                }

                #-- wenn es keine Würfe mit den Einstellungen gibt, Fehler auslösen
                if (!@wuerfe) {
                        $apiis->status(1);
                        $apiis->errors(
                            Apiis::Errors->new(
                                type       => 'DATA',
                                severity   => 'CRIT',
                                from       => 'CreateAnimal',
                                ext_fields => ['ext_animal'],
                                msg_short  => "Keinen adäquaten Wurf gefunden.\nMutter: "
                                    . $args->{'ext_unit_dam'} . ' | '
                                    . $args->{'ext_id_dam'} . ' | '
                                    . $args->{'ext_animal_dam'} . ", \nWurfdatum: ". $args->{'birth_dt'},
                            )
                        );
                    goto Exit;
                }
                else {
                    $args->{'db_sire'}=$wuerfe[1];
                }

            }
            
            #-- erstelle Tier mit den entsprechenden Daten. 
            $db_animal=CreateAnimal($args);
                
            goto Exit;
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
            goto Exit;
        }
    }
  
    else {

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
            goto Exit;
        }
    }

Exit:        
    return $db_animal;
}
1;
