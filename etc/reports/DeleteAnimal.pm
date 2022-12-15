sub GetData {
    my ( $self, $ext_unit,$ext_id,$ext_animal,$db_animal ) = @_;
    my $structure = ['field'];

#if ( $password ne 'agrum1' ) {
#        $data = [["Zugriff abgelehnt -> falsches Password"]];
#        return $data, $structure;
#    }

    if (!$db_animal or ( $db_animal eq '' )) {
        push( @{$data}, ["Keine interne Tier-ID angegeben."] );
        return $data, $structure;
    }   

    if (!$ext_animal or ( $ext_animal eq '' )) {
        push( @{$data}, ["Keine externe Tiernummer angegeben."] );
        return $data, $structure;
    }   

    my $sql     = "Set datestyle to 'german'";
    my $sql_ref = $apiis->DataBase->sys_sql($sql);

    # Tiernummer suchen und mit db_animal vergleichen 
    # Wenn Tier nicht gefunden, dann nicht vorhanden in dieser Kombination extern-intern 
    $sql="select a.db_animal from transfer a inner join unit b on a.db_unit=b.db_unit 
          where b.ext_unit='$ext_unit' and b.ext_id='$ext_id' and a.ext_animal='$ext_animal' and
                a.db_animal='$db_animal' ";
    $sql_ref = $apiis->DataBase->sys_sql($sql);
    if ( $sql_ref->status and ($sql_ref->status == 1) ) {
        $apiis->status(1);
        $apiis->errors( $sql_ref->errors );
        return;
    }
    if ( ( !$sql_ref->status ) and ( $sql_ref->{_rows} eq '0E0' ) ) {
        push( @{$data}, ["Kein Tier in der Kombination externe/interne Nummer gefunden: $ext_unit - $ext_id - $ext_animal
                ($db_animal)"] );
        return $data, $structure;
    }

    foreach my $table ( $apiis->Model->tables ) {

        my $ok;
        #--- next table, if no column db_animal in table
        map { $ok = 1 if ( ( $_ eq 'db_animal' ) ) } @{ $apiis->Model->table($table)->cols };
        next if ( !$ok );

        my $sql = "select db_animal from $table where db_animal=$db_animal";

        #print $sql;
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        if ( $sql_ref->status and ($sql_ref->status == 1) ) {
            $apiis->status(1);
            $apiis->errors( $sql_ref->errors );
            return;
        }

        #-- Schleife über alle Daten, abspeichern im array
        if ( ( !$sql_ref->status ) and ( $sql_ref->{_rows} ne '0E0' ) ) {
            $sql     = "delete from $table where db_animal=$db_animal";
            $sql_ref = $apiis->DataBase->sys_sql($sql);
            if ( $sql_ref->status and ($sql_ref->status == 1) ) {
                $apiis->status(1);
                $apiis->errors( $sql_ref->errors );
                return;
            }
            else {
	        my $st="Datensätze gelöscht";
	        $st="Datensatz gelöscht" if ($sql_ref->{_rows}==1);
                push( @{$data}, ["$table: $sql_ref->{_rows} $st"] );
            }
        }
    }
    $sql     = "update animal set db_sire=1 where db_sire=$db_animal";
    $sql_ref = $apiis->DataBase->sys_sql($sql);
    $st=$sql_ref->{_rows};
    $st=0 if (! $sql_ref->{_rows});
    push( @{$data}, ["animal: $st x db_sire => 1 gesetzt"] );

    $sql     = "update animal set db_dam=2 where db_dam=$db_animal";
    $sql_ref = $apiis->DataBase->sys_sql($sql);
    $st=$sql_ref->{_rows};
    $st=0 if (! $sql_ref->{_rows});
    push( @{$data}, ["animal: $st x  db_dam => 2 gesetzt"] );

    $apiis->DataBase->dbh->commit;

    if ( $#{$data} == -1 ) {
        push( @{$data}, 'Keine Daten' );
    }
    return $data, $structure;

}

1;

