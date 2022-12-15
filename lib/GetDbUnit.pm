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
#   $args->{'ext_unit'}         = pruefort
#   $args->{'ext_id'}      = 16
#   $args->{'ext_unit_field'}      = 'fieldname'
#   $args->{'closing_dt'}       = 10.02.2008
#########################################################################   

sub GetDbUnit {

    my $args        =shift;
    my $create      =shift;

    if (exists $args->{'db_unit'} and $args->{'db_unit'}) {
        return $args->{'db_unit'};
    }

    my $db_unit;

    #-- Notwendige Hash-Keys belegen 
    $args->{'ext_unit'}         ='' if (!exists $args->{'ext_unit'});
    $args->{'ext_id'}           ='' if (!exists $args->{'ext_id'});

    #-- Wenn Nummer unvollständig ist, dann Fehlerobject erzeugen
    if (($args->{'ext_unit'}        eq '') or 
        ($args->{'ext_id'}          eq ''))   
    {    

            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type       => 'DATA',
                    severity   => 'CRIT',
                    from       => 'LO::GetDbUnit',
                    ext_fields => [ $args->{ 'ext_field'}],
                    msg_short  => "Unit-Angaben unvollständig: "
                        . $args->{'ext_unit'} . ' | '
                        . $args->{'ext_id'} . ' | ',
                )
            );
            goto ERR;
    }

    #--- aktuellen Unit holen 
    
    # Record Objekt anlegen und mit Werten befüllen:
    my $unit = Apiis::DataBase::Record->new( tablename => 'unit', );
	
    my @unit_id= (
	               $args->{'ext_unit'},
                   $args->{'ext_id'} );
    
    $unit->column('db_unit')->extdata(\@unit_id);

    # Query starten:
    my @query_records = $unit->fetch(
           expect_rows    => 'one',
           expect_columns => ['guid','db_unit'],
    );

    #-- Wenn Fehler, dann Fehler nach apiis übertragen und abbruch 
    if ( $unit->status ) {
        $apiis->errors(scalar $unit->errors);
        $apiis->status(1);
        goto ERR;
    }
    
    #-- wenn kein Datensatz gefunden wurden, dann Unit neu anlegen 
    if (! @query_records) {
   
        return undef if ($create and ($create eq 'no')) ;

        $unit->column('ext_unit')->extdata($args->{'ext_unit'});
        $unit->column('ext_unit')->ext_fields( $args->{ 'ext_unit_field'});

        #-- unit_id
        $unit->column('ext_id')->extdata($args->{'ext_id'});
        $unit->column('ext_id')->ext_fields( $args->{'ext_id_field'});

        #-- unit_id
        $unit->column('opening_dt')->extdata($args->{'opening_dt'});
        $unit->column('opening_dt')->ext_fields( $args->{'ext_id_field'});

        #-- Datensatz in der DB anlegen 
        $unit->insert();

        #-- Fehlerbehandlung
        if ( $unit->status ) {
            $apiis->errors(scalar $unit->errors);
            $apiis->status(1);
            goto ERR;
        }
    
        #-- Daten wegschreiben 

        $db_unit = $unit->column('db_unit')->intdata;
	}
    #-- unit gibt es, $db_unit füllen
    else {

        #-- interne db_unit aus Recordobject holen 
        $db_unit = $unit->column('db_unit')->intdata;
    }

    if ( $apiis->status ) {
        goto ERR;
    }
    
    return $db_unit;
    
ERR:

    return undef;
}
1;
