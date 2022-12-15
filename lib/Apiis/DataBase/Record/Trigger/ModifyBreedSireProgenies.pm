##############################################################################
# $Id: ModifyBreedSireProgenies.pm,v 1.1 2011-05-20 11:43:16 ulm Exp $
##############################################################################
package Apiis::DataBase::Record::Trigger::ModifyBreedSireProgenies;

use strict;
use warnings;
our $VERSION = '$Revision: 1.1 $';

use Apiis;

##############################################################################

=head1 NAME

ModifyBreedSireProgenies

=head1 SYNOPSIS

Example entry in Model file:

   POSTINSERT => ['ModifyBreedSireProgenies db_sire'],

=head2 ModifyBreedSireProgenies()

=cut

sub ModifyBreedSireProgenies {
    my ( $self, $col_name, @args ) = @_;

#    return 1 if $self->check_ModifyBreedSireProgenies( $col_name, @args );

    #-- Check, ob Vater geändert wurde:
    #-- Recordobject definieren 
    my $litter = Apiis::DataBase::Record->new( tablename => 'litter', );
    
    #-- Tiernummer und parity definieren 
    $litter->column( 'db_animal' )->intdata( $self->column('db_animal')->intdata );
    $litter->column('db_animal')->encoded(1);

    $litter->column( 'parity' )->intdata( $self->column('parity')->intdata );
    $litter->column('parity')->encoded(1);

    my @q_litters = $litter->fetch( expect_rows    => 'one',
                                    expect_columns => [qw/ db_animal db_sire parity delivery_dt /], );

    if ($litter->status) {
        $self->errors($litter->errors);
        $self->status(1);
        return;
    }

    my $q_litter = shift @q_litters;

    my $db_sire_old     = $q_litter->column( 'db_sire' )->intdata;
    my $delivery_dt_old = $q_litter->column( 'delivery_dt' )->intdata;
    my $ext_breed;

    #-- Rasse checken
    if (($self->column('db_sire')->intdata ne  $db_sire_old ) and (  $self->column('db_sire')->intdata ne '1'  )) {

        #-- Rasse des Ferkels 
        my $sql = "select user_get_db_breed_progenies( ".$self->column('db_sire')->intdata.", "
                   .$self->column('db_animal')->intdata." )";

        my $sql_ref = $apiis->DataBase->sys_sql($sql);
                
        #-- Fehlerbehandlung 
        if ( $sql_ref->status and ( $sql_ref->status == 1 ) ) {
            $self->errors( $sql_ref->errors);
            $self->status(1);
            return;
        }   
           
        # Auslesen des Ergebnisses der Datenbankabfrage
        while ( my $q = $sql_ref->handle->fetch ) {
            $ext_breed = $q->[0];
        }
    }
     
    if (($self->column('delivery_dt')->intdata ne  $delivery_dt_old ) or 
        ($self->column('db_sire')->intdata ne  $db_sire_old )) {
    
        #-- Recordobject definieren 
        my $animal = Apiis::DataBase::Record->new( tablename => 'animal', );
    
        #-- Suchparameter für Tiere in animal definieren
        $animal->column( 'db_dam' )->intdata( $self->column('db_animal')->intdata );
        $animal->column('db_dam')->encoded(1);

        $animal->column( 'parity' )->intdata( $self->column('parity')->intdata );
        $animal->column('parity')->encoded(1);

        #-- Suche auslösen 
        my @q_animals = $animal->fetch( expect_rows    => 'many',
                                        expect_columns => [qw/ db_animal db_dam db_sire parity birth_dt db_breed  /], );

        #-- Fehlercheck 
        if ($animal->status) {
            $self->errors($animal->errors);
            $self->status(1);
            return;
        }
        
        #-- Schleife über alle gefundenen Tiere, Daten ändern und wegschreiben
        foreach my $rec_obj (@q_animals) {
            
            #-- Geburtsdatum ändern
            if ( $self->column('delivery_dt')->intdata ne  $delivery_dt_old ) {

                $rec_obj->column('birth_dt')->intdata( $self->column('delivery_dt')->intdata  );
                $rec_obj->column('birth_dt')->encoded(1);
            }

            #-- wenn Vater geändert wurde
            if ( $self->column('db_sire')->intdata ne  $db_sire_old ) {

                $rec_obj->column('db_sire')->intdata( $self->column('db_sire')->intdata  );
                $rec_obj->column('db_sire')->encoded(1);
    
                $rec_obj->column('db_breed')->extdata( $ext_breed );
            }

            #-- wegschreiben nach animal 
            $rec_obj->update;

            #-- Fehlerbehandlung 
            if ($rec_obj->status) {
                $self->status(1);
                $self->errors( $rec_obj->errors);

                return;
            }   
        }
    }
}

=head2 check_ModifyBreedSireProgenies()

B<check_ModifyBreedSireProgenies()> checks the correctness of the input parameters.
In case of errors it returns a non-true returnvalue.

=cut

sub check_ModifyBreedSireProgenies {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;

    unless ($col_name) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type     => 'CONFIG',
                severity => 'ERR',
                from     => 'ModifyBreedSireProgenies',
                db_table => $self->tablename,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] needs a column name as parameter", 'ModifyBreedSireProgenies'
                ),
            )
        );
    }
    if (@args) {
        $local_status = 1;
        my $err_id = $self->errors(
            Apiis::Errors->new(
                type      => 'CONFIG',
                severity  => 'WARNING',
                from      => 'ModifyBreedSireProgenies',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'TRIGGER' ),
                msg_long => __(
                    "Trigger [_1] only needs a column name as parameter, not '[_2]'",
                    'ModifyBreedSireProgenies',
                    join( ',', @args )
                ),
            )
        );
        if ( my $ef_ref = $self->column($col_name)->ext_fields ) {
            $self->error($err_id)->ext_fields($ef_ref);
        }
    }
    return $local_status || 0;
}

1;

=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>
Helmut Lichtenberg <heli@tzv.fal.de>
Ulf Müller <um@zwiss.de>

=cut

