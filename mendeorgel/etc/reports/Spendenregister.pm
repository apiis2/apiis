sub  Spendenregister {

  my $sql="Set datestyle to 'german'";
  my $sql_ref = $apiis->DataBase->sys_sql($sql);
  
  $sql="select 
      manual,
      manual_no,
      register,
      register_no,
      ton,
      ton_no,
      preis,
      spende,
      firma_name,
      first_name,
      second_name,
      street,
      zip,
      town
      from address
      order by manual_no, register_no, ton_no
      ;";

    $sql_ref = $apiis->DataBase->sys_sql($sql);
    if ($sql_ref->status and ($sql_ref->status == 1))  {
        $apiis->status(1);
        $apiis->errors($sql_ref->errors);
        return;
    }

    #-- Schleife über alle Daten, abspeichern im array
    my $data=[]; 
    my $structure=['field'];
    my $i=1;my @tr=();

    push(@{$data}, [
 '
 <style type="text/css">
body{
    background-color:#FFFFFF;
}
table {
    background-color:#FFFFFF;
}
td.data_13 { background-color:#FFFFFF; width:600px }
td.sr {
    padding:10px;
    background-color:#eae2d2;
    color:#000000;
    text-align:center;
    font-weight:bold;
}
div.sname {font-family:helvetica, sans-serif; font-size:36px; color:#34648d;}
div.ston {font-family:verdana, new century schoolbook;color:#743a2e;}
div.sregister {font-family:baskerville, serif;color:#34648d;}
div.smanual {font-family:arial ,new century schoolbook;color:#d2944e;}

  </style>']);

    push(@{$data}, [ 'Wir bedanken uns bei allen Patinnen und Paten für die Unterstützung <br>der Sanierung der Mende-Orgel in der St. Bartholomäus Kirche in Belgern. ']);
    while( my $q = $sql_ref->handle->fetch ) {
   
            map{ if (!$_) {$_=''} } @$q;    
    
            $q->[2]=~s/(\d\d?)$/&nbsp;$1'/g;
            $q->[4]=~s/^(.+?)([0123]+)$/$1<sup>$2<\/sup>/g; 

            $td.='<td class="sr"><div class="sname">'.$q->[9].' ' .$q->[10].'</div><br>'
                    .'<div class="sregister">Register: '.$q->[2].'</div>'
                    .'<div class="smanual">'.$q->[0].'</div>'
                    .'<div class="ston">Orgelpfeife '.$q->[4].'</div>'
                    .'</td>';

            if ($i>2) {
                
                push(@tr, $td);
                $i=1;
                $td='';
            }
            else {
                $i++;
            }
    }

    push(@{$data}, [
            '<table border="1"><TR>'.join('</TR></TR>',@tr).'</TR></table>'
    ]);
    if ( $#{$data} == -1 ) {
        push( @{$data}, 'Keine Daten' );
    }

    return $data, $structure;
}
1;
