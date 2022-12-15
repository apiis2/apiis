#####################################################################
# load object: LO_NewAnimal
# $Id: LO_NewAnimal.pm,v 1.1 2014/10/30 05:04:00 ulm Exp $
#####################################################################
# This is the Load Object for a new record.
# events:
#           1. Insert new record into ANIML, TRANSFER
#
# Conditions:
# 1. The load object is one transevent: either it succeeds or
#    everything is rolled back.
# 2. The Load_object is aborted on the FIRST error.
#####################################################################
sub LO_NewAnimal {
    my $self     = shift;
    my $hash_ref = shift();
    my $err_ref;

    #    $hash_ref = {
    #        Tanimal_ext_unit   => '15-herdbuchnummer',
    #        Tanimal_ext_id     => '1-we06029',
    #        Tanimal_ext_animal => '3314',
    #        Vanimal_ext_unit   => '15-herdbuchnummer',
    #        Vanimal_ext_id     => '1-we06000',
    #        Vanimal_ext_animal => '4728',
    #        Manimal_ext_unit   => '15-herdbuchnummer',
    #        Manimal_ext_id     => '2-we06000',
    #        Manimal_ext_animal => '62953',
    #        sex                => '1',
    #        breed            => '6',
    #        birth_dt          => '15.01.2004',
    #        name              => 'Gero',
    #        farbe             => undef,
    #        ablammnummer      => undef,
    #        owner             => 'st06046',
    #        db_selection      => '1',
    #        gebtyp            => undef,
    #        mz                => undef,
    #        zb_abt            => '1',
    #        ext_traits_name1  => 'BN',
    #        ext_traits_value1 => '8',
    #        ext_traits_name2  => undef,
    #        ext_traits_value2 => undef,
    #    };

    #    require apiis_alib;

    ##################################################################
    # %data_hash must have the following keys from @LO_keys and the
    # appropriate values from the datastream:
    ##################################################################
    my @LO_keys = qw ( Tanimal_ext_unit Tanimal_ext_id Tanimal_ext_animal
        Vanimal_ext_unit Vanimal_ext_id Vanimal_ext_animal
        Manimal_ext_unit Manimal_ext_id Manimal_ext_animal
        sex breed birth_dt name farbe scrapie wurfnummer
        owner db_selection gebtyp mz zb_abt
        ext_traits_name1 ext_traits_value1 ext_traits_name2 ext_traits_value2
    );

    #    # some basic checks:
    #    my ( $err_status, $err_ref ) = main::CheckLO( $hash_ref, \@LO_keys );
    #    return ( $err_status, $err_ref ) if $err_status;
    ##################################################################

    $hash_ref->{'db_sire'} = 1;
    $hash_ref->{'db_dam'}  = 2;
    $hash_ref->{'db_breed_sire'} = '';
    $hash_ref->{'db_breed_dam'}  = '';

            #-- Rasse ermitteln
            $sql = "select 
                a.db_id_sire as db_breed_sire,
                a.db_id_dam as db_breed_dam
                from checkallel a 
                where a.db_id_animal=$hash_ref->{ 'breed' }";

            $sql_ref = $apiis->DataBase->sys_sql($sql);
            if ( ( !$sql_ref->status ) and ( $sql_ref->{_rows} ne '0E0' ) ) {
                while ( my $q = $sql_ref->handle->fetch ) {
                    $hash_ref->{'db_breed_sire'}  = $q->[0];
                    $hash_ref->{'db_breed_dam'}  = $q->[1];
                }
            }
    
    if (($hash_ref->{'db_breed_sire'}  eq '') or ($hash_ref->{'db_breed_dam'}  eq '')) {
        #-- sonst Fehler 
        $self->status( 1 );
        $err_ref = Apiis::Errors->new(
            type      => 'CONFIG',
            severity  => 'ERR',
            from      => 'LO_NewAnimal',
            msg_short => __('Rasse der Eltern kann nicht aus Rasse des Tieres ermittelt werden -> Es muss ein neuer Eintrag in checkallel erzeugt werden.'),
        );
    }

    EXIT: {
        for my $elter ( 'Vater', 'Mutter', 'Tier' ) {
            my ( $ext_animal_field, $ext_unit_field, $ext_id_field );
            if ( $elter eq 'Vater' ) {
                $ext_animal       = $hash_ref->{'Vanimal_ext_animal'};
                $ext_unit         = lc( $hash_ref->{'Vanimal_ext_unit'} );
                $ext_id           = $hash_ref->{'Vanimal_ext_id'};
                $db_breed         = $hash_ref->{'db_breed_sire'};
                $ext_animal_field = 'Vanimal_ext_animal';
                $ext_unit_field   = 'Vanimal_ext_unit';
                $ext_id_field     = 'Vanimal_ext_id';
            }
            elsif ( $elter eq 'Mutter' ) {
                $ext_animal       = $hash_ref->{'Manimal_ext_animal'};
                $ext_unit         = lc( $hash_ref->{'Manimal_ext_unit'} );
                $ext_id           = $hash_ref->{'Manimal_ext_id'};
                $db_breed         = $hash_ref->{'db_breed_dam'};
                $ext_animal_field = 'Manimal_ext_animal';
                $ext_unit_field   = 'Manimal_ext_unit';
                $ext_id_field     = 'Manimal_ext_id';
            }
            else {
                $ext_animal       = $hash_ref->{'Tanimal_ext_animal'};
                $ext_unit         = lc( $hash_ref->{'Tanimal_ext_unit'} );
                $ext_id           = $hash_ref->{'Tanimal_ext_id'};
                $db_breed         = $hash_ref->{'breed'};
                $ext_animal_field = 'Tanimal_ext_animal';
                $ext_unit_field   = 'Tanimal_ext_unit';
                $ext_id_field     = 'Tanimal_ext_id';
            }

            # Nachschauen, ob es das Tier in der Datenbank gibt

            my $transfer = Apiis::DataBase::Record->new( tablename => 'transfer', );
            $transfer->column('ext_animal')->extdata($ext_animal);
            $transfer->column('db_unit')->extdata( $ext_unit, $ext_id );
            my @q_transfers = $transfer->fetch(
                expect_rows    => 'one',
                expect_columns => qw/ db_animal /,
            );
            my $q_transfer = shift @q_transfers;
            my $db_animal = $q_transfer->column('db_animal')->intdata if ($q_transfer);

            if ( defined $db_animal ) {
                $hash_ref->{'db_sire'}   = $db_animal if ( $elter eq 'Vater' );
                $hash_ref->{'db_dam'}    = $db_animal if ( $elter eq 'Mutter' );
                $hash_ref->{'db_animal'} = $db_animal if ( $elter eq 'Tier' );
            }
            else {

                # now fill transfer record:
                my $now = $apiis->now;
                if ( ($ext_animal) and ( $ext_animal ne '' ) ) {


                    $transfer = Apiis::DataBase::Record->new( tablename => 'transfer', );
                
                    #-- db_animal wird nicht mit pre_insert gesetzt
                    my $db_animal=$apiis->DataBase->seq_next_val('seq_transfer__db_animal');

                    $transfer->column('db_animal')->intdata($db_animal);
                    $transfer->column('db_animal')->encoded(1);
                    
                    $transfer->column('db_unit')->extdata( $ext_unit, $ext_id );
                    $transfer->column('db_unit')->ext_fields( $ext_unit_field, $ext_id_field );

                    $transfer->column('ext_animal')->extdata($ext_animal);
                    $transfer->column('ext_animal')->ext_fields($ext_animal_field);

                    $transfer->column('opening_dt')->extdata($now);

                    $transfer->column('id_set')->extdata($ext_unit);

                    $transfer->insert();

                    if ( $transfer->status ) {
                        $self->status(1);
                        $err_ref = scalar $transfer->errors;
                        last EXIT;
                    } 

                    #-- übernahme db_animal  
                    $hash_ref->{'db_animal'}=$transfer->column('db_animal')->intdata();

                    if ( ( $elter eq 'Tier' ) and ( $hash_ref->{'owner'} ne '' ) ) {
                        $locations = Apiis::DataBase::Record->new( tablename => 'locations', );
                        $locations->column('db_animal')->intdata( $hash_ref->{'db_animal'} );
                        $locations->column('db_animal')->encoded(1);
                        $locations->column('db_location')->intdata( $hash_ref->{'owner'}  );
                        $locations->column('db_location')->encoded(1);
                        $locations->column('db_location')->ext_fields('owner');
                        $locations->column('entry_dt')->extdata($now);
                        $locations->column('db_entry_action')->extdata('init');
                        $locations->insert;

                        if ( $locations->status ) {
                            $self->status(1);
                            $err_ref = scalar $locations->errors;
                            last EXIT;
                        }
                    }

                    my $animal = Apiis::DataBase::Record->new( tablename => 'animal', );
                    $animal->column('db_animal')->intdata(  $hash_ref->{'db_animal'} );
                    $animal->column('db_animal')->encoded(1);
                    if ( $elter eq 'Tier' ) {

                        $animal->column('db_sire')->intdata( $hash_ref->{'db_sire'} );
                        $animal->column('db_sire')->encoded(1);
                        $animal->column('db_dam')->intdata( $hash_ref->{'db_dam'} );
                        $animal->column('db_dam')->encoded(1);

                        $animal->column('db_sex')->intdata( $hash_ref->{'sex'} );
                        $animal->column('db_sex')->encoded(1);
                        $animal->column('db_sex')->ext_fields('sex');

                        $animal->column('db_breed')->intdata( $db_breed );
                        $animal->column('db_breed')->encoded(1);
                        $animal->column('db_breed')->ext_fields('breed');

                        $animal->column('birth_dt')->extdata( $hash_ref->{'birth_dt'} );
                        $animal->column('birth_dt')->ext_fields('birth_dt');

                        $animal->column('name')->extdata( $hash_ref->{'name'} );
                        $animal->column('name')->ext_fields('name');

                        $animal->column('parity')->extdata( $hash_ref->{'parity'} );
                        $animal->column('parity')->ext_fields('parity');

                        $animal->column('db_selection')->intdata( $hash_ref->{'db_selection'} );
                        $animal->column('db_selection')->encoded(1);
                        $animal->column('db_selection')->ext_fields('db_selection');

                        $animal->column('db_zb_abt')->intdata( $hash_ref->{'zb_abt'} );
                        $animal->column('db_zb_abt')->encoded(1);
                        $animal->column('db_zb_abt')->ext_fields('zb_abt');
                    }
                    elsif ( $elter eq 'Vater' ) {
                        $hash_ref->{'db_sire'} = $db_animal;
                        $animal->column('db_breed')->intdata( $db_breed );
                        $animal->column('db_breed')->encoded(1);
                        $animal->column('db_breed')->ext_fields('breed');

                        $animal->column('db_sex')->extdata('1');
                        $animal->column('db_sire')->intdata('1');
                        $animal->column('db_sire')->encoded(1);
                        $animal->column('db_dam')->intdata('2');
                        $animal->column('db_dam')->encoded(1);
                    }
                    else {
                        $animal->column('db_breed')->intdata( $db_breed );
                        $animal->column('db_breed')->encoded(1);
                        $animal->column('db_breed')->ext_fields('breed');

                        $hash_ref->{'db_dam'} = $db_animal;
                        $animal->column('db_sex')->extdata('2');
                        $animal->column('db_sire')->intdata('1');
                        $animal->column('db_sire')->encoded(1);
                        $animal->column('db_dam')->intdata('2');
                        $animal->column('db_dam')->encoded(1);
                    }

                    $animal->insert;
                    if ( $animal->status ) {
                        $self->status(1);
                        $err_ref = scalar $animal->errors;
                        last EXIT;
                    }
                }
            }
            next if ( $elter ne 'Tier' );
            for ( my $i = 0; $i < 5; $i++ ) {

                my $ext_key;
                my $ext_value;
                my $ext_key_field;
                my $ext_value_field;
                if ( $i == 0 ) {
                    $ext_key         = $hash_ref->{'ext_traits_name1'};
                    $ext_value       = $hash_ref->{'ext_traits_value1'};
                    $ext_key_field   = 'ext_traits_name1';
                    $ext_value_field = 'ext_traits_value1';
                }
                elsif ( $i == 1 ) {
                    $ext_key         = $hash_ref->{'ext_traits_name2'};
                    $ext_value       = $hash_ref->{'ext_traits_value2'};
                    $ext_key_field   = 'ext_traits_name2';
                    $ext_value_field = 'ext_traits_value2';
                }
                elsif ( $i == 2 ) {
                    $ext_key         = $hash_ref->{'ext_traits_name3'};
                    $ext_value       = $hash_ref->{'ext_traits_value3'};
                    $ext_key_field   = 'ext_traits_name3';
                    $ext_value_field = 'ext_traits_value3';
                }
                elsif ( $i == 3 ) {
                    $ext_key         = $hash_ref->{'ext_traits_name4'};
                    $ext_value       = $hash_ref->{'ext_traits_value4'};
                    $ext_key_field   = 'ext_traits_name4';
                    $ext_value_field = 'ext_traits_value4';
                }
                elsif ( $i == 4 ) {
                    $ext_key         = $hash_ref->{'ext_traits_name5'};
                    $ext_value       = $hash_ref->{'ext_traits_value5'};
                    $ext_key_field   = 'ext_traits_name5';
                    $ext_value_field = 'ext_traits_value5';
                }

                next if ( !$ext_value_field );
                next if ( !$hash_ref->{$ext_value_field} or ($hash_ref->{$ext_value_field} eq '' ));

                # externe Merkmale wegschreiben
                my $external_traits = Apiis::DataBase::Record->new( tablename => 'external_traits', );
                $external_traits->column('db_animal')->intdata( $hash_ref->{'db_animal'} );
                $external_traits->column('db_animal')->encoded(1);

                $external_traits->column('db_trait')->intdata($ext_key);
                $external_traits->column('db_trait')->encoded(1);
                $external_traits->column('db_trait')->ext_fields($ext_key_field);

                $external_traits->column('value')->extdata($ext_value);
                $external_traits->column('value')->ext_fields($ext_value_field);
                $external_traits->insert;

                if ( $external_traits->status ) {
                    $self->status(1);
                    $err_ref = scalar $external_traits->errors;
                    last EXIT;
                }
            }

            $self->status(0);
            $self->del_errors;
        }
    }

    if ( $self->status ) {
        $apiis->DataBase->dbh->rollback;
    }
    else {
        $apiis->DataBase->dbh->commit;
    }
    return ( $self->status, $err_ref );

}

1;

