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
#   $args->{'ext_unit_event'}         = pruefort
#   $args->{'ext_id_event'}           = 16
#   $args->{'ext_event_type'}   = els
#   $args->{'event_dt'}         = 10.02.2008
#########################################################################   

sub GetDbEvent {

    my $args        =shift;
    my $create      =shift;

    if (exists $args->{'db_event'} and $args->{'db_event'}) {
        return $args->{'db_event'};
    }

    my $db_event;

    #-- Notwendige Hash-Keys belegen 
    $args->{'ext_unit_event'}         ='' if (!exists $args->{'ext_unit_event'});
    $args->{'ext_id_event'}           ='' if (!exists $args->{'ext_id_event'});
    $args->{'ext_event_type'}   ='' if (!exists $args->{'ext_event_type'});
    $args->{'event_dt'}         ='' if (!exists $args->{'event_dt'});

    #-- Wenn Nummer unvollständig ist, dann Fehlerobject erzeugen
    if (($args->{'ext_unit_event'}        eq '') or 
        ($args->{'ext_id_event'}          eq '')   or
        ($args->{'event_dt'}        eq '')   or
        ($args->{'ext_event_type'}  eq '')) {    

            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type       => 'DATA',
                    severity   => 'CRIT',
                    from       => 'LO::GetDbEvent',
                    ext_fields => [ $args->{ 'ext_field'}],
                    msg_short  => "Event-Angaben unvollständig: "
                        . $args->{'ext_unit_event'} . ' | '
                        . $args->{'ext_id_event'} . ' | '
                        . $args->{'event_dt'} . ' | '
                        . $args->{'ext_event_type'} . '',
                )
            );
            goto ERR;
    }

    #--- aktuellen Event holen 
    
    # Record Objekt anlegen und mit Werten befüllen:
    my $event = Apiis::DataBase::Record->new( tablename => 'event', );
	
    my @event_id= ($args->{'ext_event_type'}, 
	               $args->{'event_dt'}, 
	               $args->{'ext_unit_event'},
                   $args->{'ext_id_event'} );
    
    $event->column('db_event')->extdata(\@event_id);

    # Query starten:
    my @query_records = $event->fetch(
           expect_rows    => 'one',
           expect_columns => ['guid','db_event'],
    );

    #-- Wenn Fehler, dann Fehler nach apiis übertragen und abbruch 
    if ( $event->status ) {
        $apiis->errors(scalar $event->errors);
        $apiis->status(1);
        goto ERR;
    }
    
    #-- wenn kein Datensatz gefunden wurden, dann Event neu anlegen 
    if (! @query_records) {
   
        return undef if ($create and ($create eq 'no')) ;

        #-- db_event_type 
        $event->column('db_event_type')->extdata($args->{'ext_event_type'});
        $event->column('db_event_type')->ext_fields( $args->{ 'ext_field'});

        #-- event_dt
        $event->column('event_dt')->extdata($args->{'event_dt'});
        $event->column('event_dt')->ext_fields( $args->{'ext_field'});

        #-- db_location 
        $event->column('db_location')->extdata($args->{'ext_unit_event'}, $args->{'ext_id_event'});
        $event->column('db_location')->ext_fields( $args->{'ext_field'});
          
        if (exists $args->{'ext_samp_id'} and exists $args->{'ext_samp_unit'} and 
                   ($args->{'ext_samp_id'} and ($args->{'ext_samp_id'} ne '')) and 
                   ($args->{'ext_samp_unit'} ne '')) {
            #-- db_sampler 
            $event->column('db_sampler')->extdata($args->{'ext_samp_unit'}, $args->{'ext_samp_id'});
            $event->column('db_sampler')->ext_fields( $args->{'ext_field'});
        }
        #-- Datensatz in der DB anlegen 
        $event->insert();

        #-- Fehlerbehandlung
        if ( $event->status ) {
            $apiis->errors(scalar $event->errors);
            $apiis->status(1);
            goto ERR;
        }
    
        #-- Daten wegschreiben 
#        $apiis->DataBase->dbh->commit;

        $db_event = $event->column('db_event')->intdata;
	}
    #-- event gibt es, $db_event füllen
    else {

        #-- interne db_event aus Recordobject holen 
        $db_event = $event->column('db_event')->intdata;
    }

    if ( $apiis->status ) {
        goto ERR;
    }
    
    return $db_event;
    
ERR:

    #-- keine Tiernummer zurück, da Fehler 
#    $apiis->DataBase->dbh->rollback;
    return undef;
}
1;
