package SQLStatements;

sub CheckDate {

    $dat=shift;
    if ($dat=~/^[0-3]\d\.[01]\d\.[12][09]\d\d/) {
        return 'true';    
    }    
    else {
        return undef;
    }     
}


sub GetSchema {

    my $type    = shift;

    my $hs_eventtyp={
      'litter'=>{
     'animals_litter' =>{'trait'=>'animals_litter','table'=>'v_animals_litter','order'=>'0','decimals'=>'0','function'=>'SUM'},
     'nparity' =>{'trait'=>'n_parity','table'=>'v_n_parity','order'=>'0','decimals'=>'0','function'=>'SUM'},
     'ewa'=>{'trait'=>'ewa','table'=>'v_ewa', 'order'=>'1','decimals'=>'1','function'=>'AVG'},
     'zwz'=>{'trait'=>'zwz','table'=>'v_zwz', 'order'=>'1','decimals'=>'1','function'=>'AVG'},
     'born_alive_no'=>{'trait'=>'born_alive_no','table'=>'v_born_alive_no', 'order'=>'1','decimals'=>'1','function'=>'AVG'},
     'weaned_no'      =>{'trait'=>'weaned_no','table'=>'v_weaned_no','order'=>'1','decimals'=>'1','function'=>'AVG'},
    }};  

    return $hs_eventtyp->{$type};    
}

sub GetDescription {

    my $db_column=shift;

    %bezeichner=( 'db_animal'=>['Tiernummer','Tier','Tier','','',''],
                  'db_unit'=>['Unit','Unit','Unit','','',''],
                  ''=>['','','','','',''],
                  ''=>['','','','','',''],
    );

    if (exists $bezeichner{$db_column}) {
            return $bezeichner{$db_column};
        }    
    else {
            return [ $db_column, $db_column,$db_column,'','','' ];
        }    

}

sub SQLSetAnimals {
  my ($aktiv, $hb, $typ, $v1, $v2, $v3) = @_;
  my @inner; my @where;
  my $sql="select z.db_animal into temporary table SQLSetAnimals from animal z ";
  
##  #-- only aktiv animals
#  if ($aktiv and $aktiv ne '' ) {
#    push(@inner, " inner join locations a on a.db_animal=z.db_animal") ;
#    push(@where, " a.exit_dt isnull");
#  }

  #-- only one animal 
  if ($typ eq 'animal') {
    push(@inner, " inner join transfer c on z.db_animal=c.db_animal
                   inner join unit d on c.db_unit=d.db_unit");
    push(@where, " (d.ext_unit='$v1' and d.ext_id='$v2' and c.ext_animal='$v3') ");
  }

  #-- only one animal via db_unit 
  if ($typ eq 'animal_db_unit') {
    my @a=();
    push(@a,"c.db_unit=$v1 ") if ($v1 and ($v1 ne ''));
    push(@a,"c.ext_animal like '$v2'") if ($v2 and ($v2 ne ''));
		 
    push(@inner, " inner join transfer c on z.db_animal=c.db_animal ");
    push(@where, " (".join(' and ', @a).") ");
  }

  $sql.=join(' ',@inner);
  $sql.=' where '.join(' and ',@where);
  $sql.=' group by z.db_animal'; 

  #print $sql;

  return $sql;
}

sub SQLGetStammdaten {
    my $event_id = shift;
    my $sql;
  
    $sql="select x.db_animal,
          (select ext_id || '-' || ext_animal from transfer b inner join unit c on b.db_unit=c.db_unit
	   where b.db_animal=a.db_animal order by c.ext_unit limit 1) as animal,
          (select ext_id || '-' || ext_animal from transfer b inner join unit c on b.db_unit=c.db_unit
	   where b.db_animal=a.db_animal and c.ext_unit='20-jungtier' limit 1) as animal2,
          a.name,
	  a.birth_dt,
	  case when d.long_name isnull then d.ext_code else d.long_name end,
	  c.ext_code,
	  a.teats_l_no || '/' || a.teats_r_no,
	  ";
      
    	  $sql.=" current_date-a.birth_dt as alter,";
      
      $sql.="
	  d.ext_code
	  from SQLSetAnimals x inner join animal a on x.db_animal=a.db_animal
	                       left outer join codes  c on c.db_code=a.db_sex
	                       left outer join codes  d on d.db_code=a.db_breed
  ";

return $sql;

}

sub SQLGetAbstammung {
  my $sql;
  $sql="
   select 
   x.db_animal,
   x.typ,
   (select b1.ext_id || '-' || a1.ext_animal from transfer a1 inner join unit b1 on a1.db_unit=b1.db_unit 
                      where a1.db_animal=x.nummer order by b1.ext_unit limit 1) as ext_animal,
   (select case when short_name isnull then ext_code else short_name end from codes where db_code=a.db_breed),
   (select case when short_name isnull then ext_code else short_name end from codes inner join genes on db_code=db_genes 
    where db_animal=x.nummer),
   a.name
   
   from (
select db_animal as db_animal,'T' as typ, db_animal as nummer from SQLSetAnimals as x2
union
select a.db_animal, 'V', b1.db_sire from sqlsetanimals a inner join animal b1 on a.db_animal=b1.db_animal 
union
select a.db_animal, 'M', b1.db_dam from sqlsetanimals a inner join animal b1 on a.db_animal=b1.db_animal 
union
select a.db_animal, 'VV', b2.db_sire from sqlsetanimals a inner join animal b1 on a.db_animal=b1.db_animal inner join animal b2 on b1.db_sire=b2.db_animal
union
select a.db_animal, 'VM', b2.db_dam from sqlsetanimals a inner join animal b1 on a.db_animal=b1.db_animal inner join animal b2 on b1.db_sire=b2.db_animal
union
select a.db_animal, 'MV', b2.db_sire from sqlsetanimals a inner join animal b1 on a.db_animal=b1.db_animal inner join animal b2 on b1.db_dam=b2.db_animal
union
select a.db_animal, 'MM', b2.db_dam from sqlsetanimals a inner join animal b1 on a.db_animal=b1.db_animal inner join animal b2 on b1.db_dam=b2.db_animal) as x

    left outer join animal a on x.nummer=a.db_animal
    order by x.db_animal
  ";
  return $sql;
}
sub sql_pedigree {
    return "select distinct 
   z.db_animal,
   (select a1.ext_id || '-' || b1.ext_animal from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit  
    where b1.db_animal=x.db_sire order by a1.ext_unit limit 1) || ' ' || 
    case when x1.name isnull then '' else x1.name end  || ' ' || 
    case when x3.db_genes isnull then ' ' else (select case when short_name isnull then ext_code else short_name end from codes where codes.db_code=x3.db_genes)::text end as v,
   
   (select a1.ext_id || '-' || b1.ext_animal from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit  
    where b1.db_animal=x.db_dam order by a1.ext_unit limit 1) || ' ' || 
    case when x2.name isnull then '' else x2.name  end || ' ' || 
    case when x4.db_genes isnull then ' ' else (select case when short_name isnull then ext_code else short_name end from codes where codes.db_code=x4.db_genes)::text end as m,
   
   (select  a1.ext_id || '-' || b1.ext_animal || ' ' || case when c1.name isnull then '' else c1.name end  
    from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit left outer join animal c1 on b1.db_animal=c1.db_animal 
    where b1.db_animal=x1.db_sire order by a1.ext_unit limit 1) as vv,
   
   (select  a1.ext_id || '-' || b1.ext_animal || ' ' || case when c1.name isnull then '' else c1.name end  
    from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit left outer join animal c1 on b1.db_animal=c1.db_animal 
    where b1.db_animal=x1.db_dam order by a1.ext_unit limit 1) as vm,
   
   (select  a1.ext_id || '-' || b1.ext_animal || ' ' || case when c1.name isnull then '' else c1.name end  
    from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit left outer join animal c1 on b1.db_animal=c1.db_animal 
    where b1.db_animal=x2.db_sire order by a1.ext_unit limit 1) as mv,
   
   (select  a1.ext_id || '-' || b1.ext_animal || ' ' || case when c1.name isnull then '' else c1.name end  
    from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit left outer join animal c1 on b1.db_animal=c1.db_animal 
    where b1.db_animal=x2.db_dam order by a1.ext_unit limit 1) as mm
   
   from sqlsetanimals z inner join animal x on z.db_animal=x.db_animal
                        left outer join animal x1 on x1.db_animal=x.db_sire
                        left outer join animal x2 on x2.db_animal=x.db_dam
                        left outer join genes x3 on x3.db_animal=x.db_sire
                        left outer join genes x4 on x4.db_animal=x.db_dam";
}



sub sql_adresse_zuechter {
  my $sql;
  $sql="select 
               x.db_animal,
	      'breeder',
 	      case when firma_name isnull 
	      then case when first_name isnull then '' else first_name end   || ' ' ||
	           case when second_name isnull then '' else second_name || ', ' end
              else firma_name || ' ,'end ||
              case when street      isnull then '' else street || ', '       end ||
              case when zip         isnull then '' else zip    || ' '     end  ||
              case when town        isnull then '' else town        end
              from SQLSetAnimals x inner join animal a on x.db_animal=a.db_animal
						      inner join unit b on a.db_breeder=b.db_unit
				                      inner join address c on c.db_address=b.db_address
	union
      select 
              x.db_animal,
	      'owner' as ext_unit,
	      (select case when firma_name isnull 
                      then case when first_name isnull then '' else first_name end   || ' ' ||
	                   case when second_name isnull then '' else second_name || ', ' end 
                      else firma_name || ', ' end ||
	                          case when street      isnull then '' else street || ', '       end ||
	                          case when zip         isnull then '' else zip    || ' '     end  ||
	                         case when town        isnull then '' else town        end 
	       from locations d inner join unit b on d.db_location=b.db_unit
	                        inner join address c on c.db_address=b.db_address 
	       where d.db_animal=x.db_animal order by d.entry_dt desc limit 1)  	
	                         from SQLSetAnimals x 
	
  ";
  return $sql;
}

sub sql_adresse_owner {
  my $sql;
  $sql="select 
              x.db_animal,
	      'owner' as ext_unit,
	      (select case when first_name isnull then '' else first_name end   || ' ' ||
	                           case when second_name isnull then '' else second_name || ', ' end ||
	                          case when street      isnull then '' else street || ', '       end ||
	                          case when zip         isnull then '' else zip    || ' '     end  ||
	                         case when town        isnull then '' else town        end 
	       from locations d inner join unit b on d.db_location=b.db_unit
	                        inner join address c on c.db_address=b.db_address 
	       where d.db_animal=x.db_animal order by d.entry_dt desc limit 1)  	
	                         from SQLSetAnimals x 
  ";
  return $sql;
}

sub sql_adressen {

return "
  select db_address, ext_address, firma_name,  
         user_get_ext_code(db_title),
         user_get_ext_code(db_salutation), 
         case when db_salutation notnull then user_get_ext_code(db_salutation) || ' ' else '' end || 
         case when db_title notnull then user_get_ext_code(db_title) || ' ' else '' end || 
         case when first_name notnull then first_name || ' ' else '' end || 
         case when second_name notnull then second_name else '' end, 
         second_name, birth_dt,street,zip,
         case when zip notnull then zip || ' ' else '' end || 
         case when town notnull then town else '' end as town,
         county,
         (select case when short_name isnull then ext_code else short_name end from codes where db_code=db_country),
         (select case when short_name isnull then ext_code else short_name end from codes where db_code=db_language),
         phone_priv,phone_firma, phone_mobil, fax, email, http, hz, bank, iban, bic,
         (select case when short_name isnull then ext_code else short_name end from codes where db_code=db_payment),
         member_entry_dt, member_exit_dt
  from address	
  where ext_address notnull
  order by ext_address
"
}


sub sql_t_animals_per_farm {
  my ($owner,$format,$temptable)=@_; # $owner
  my $sql="
  select distinct b.db_animal as db_animal,
                a.ext_id || '-' || b.ext_animal as ext_animal,
                (select ext_code from codes where db_code=c.db_sex) as ext_sex,
                (select ext_code from codes where db_code=c.db_breed) as ext_breed,
                (select long_name from codes where db_code=c.db_breed) as ext_breed_long,
                c.db_sire,
                c.db_dam,
                c.name,
                c.birth_dt,
                date_part('year',age( c.birth_dt)) as alter ";
  if ($temptable) {
    $sql=$sql.' into temporary table t_animals_per_farm ';
  }
  $sql=$sql."
  from unit a inner join transfer b on a.db_unit=b.db_unit
            inner join animal c on b.db_animal=c.db_animal
            inner join unit d on b.db_farm=d.db_unit
  where b.closing_dt isnull and
        b.exit_dt isnull and
        b.db_farm notnull and
        a.ext_unit='10-herdbuch' and
        d.ext_id='$owner' and
        (d.ext_unit='breeder' or d.ext_unit='owner')";
  if ($format eq 'w') {
    $sql=$sql." and c.db_sex=(select db_code from codes where class='SEX' and ext_code='2')";
  }  
  if ($format eq 'm') {
    $sql=$sql." and c.db_sex=(select db_code from codes where class='SEX' and ext_code='1')";
  }  

  return "$sql";
}

sub sql_pedigree_t_animals_per_farm {
return "
select a.db_animal, a.db_sire, a.db_dam,b.db_sire, b.db_dam, c.db_sire, c.db_dam 
 from animal a inner join animal c on c.db_animal=a.db_dam 
               inner join animal b on b.db_animal=a.db_sire
	       inner join t_animals_per_farm d on d.db_animal=a.db_animal;
";

}

sub sql_animal_per_animal {
  my ($animal) = @_;
  my $sql="
  /*---------------------------------------------------------------------------------------------------------*/
  /* Animal */
  select x.db_animal as db_animal,
        (select ext_id || '-' || ext_animal from transfer,unit 
	 where transfer.db_unit=unit.db_unit  and db_animal=x.db_animal order by unit.ext_unit limit 1) as ext_animal,

        user_get_ext_code(x.db_sex,'l') as ext_sex, 
        
        (select birth_dt from animal  where db_animal=x.db_animal) as birth_dt, 
        (select ext_id || '-' || ext_animal from transfer,unit where transfer.db_unit=unit.db_unit and unit.ext_unit='10-herdbuch' and db_animal=x.db_sire limit 1) as ext_sire,
	(select ext_id || '-' || ext_animal from transfer,unit where transfer.db_unit=unit.db_unit and unit.ext_unit='10-herdbuch' and db_animal=x.db_dam limit 1) as ext_dam,
        x.parity ,
	(select ext_id from unit where db_unit=x.db_breeder) as breeder,
	x.leaving_dt,
/*        (select long_name from codes where db_code=x.db_leaving) as ext_culling, */
    user_get_ext_code(x.db_selection,'l') as ext_selection, 
	x.name as name, 
    x.la_rep as la_rep,	
	x.la_rep_dt as la_rep_dt,
	x.teats_l_no || '/' || x.teats_r_no as teats,	
	user_get_ext_code(x.db_breed,'l') as ext_breed, 
    user_get_ext_code(x.db_zb_abt,'l') as ext_zb_abt, 
    x.comments,
	'' as ext_auftyp,
    x.spitze as spitze,
    user_get_ext_code(x.db_test_result,'l') as ext_test_result,
    user_get_ext_code(x.db_test_type,'l') as ext_test_type
  from animal x  
  where x.db_animal=$animal"; 
  
  return $sql;
}

sub sql_litter_per_animal {
  my ($animal) = @_;
  my $sql="
  /*---------------------------------------------------------------------------------------------------------*/
  /* Litter */
  select db_animal, 
       a.delivery_dt,
       'Ablammung' as ext_event, 
       '' as ext_location, 
       '' as ext_sampler,
       'Bock' as tdb_sire,
       (select ext_id || '-' || ext_animal from transfer,unit where transfer.db_unit=unit.db_unit and unit.ext_unit='10-herdbuch' and db_animal=a.db_sire limit 1) as ext_sire,
       'LN:' as tparity,
       a.parity, 
       'weibl:' as tfemale_born_no,
       case when male_born_no isnull then born_alive_no else born_alive_no-male_born_no end as female_born, 
       'maennl:' as tmale_born_no,
       a.male_born_no, 
       'tot:' as tstill_born_no,
       a.still_born_no, 
       'NAbg.:' as tgh,
       a.weaned_no as tweanedn,
       'NAug.:' as tauf,
       a.foster_no as tfoster_no
  from litter a  
  where db_animal=$animal"; 
  
  return $sql;
}


sub sql_transfer1_per_animal {
  my ($animal) = @_;
  my $sql="
  /*---------------------------------------------------------------------------------------------------------*/
  /* transfer */
  select db_animal, 
       a.opening_dt,
       'oeffnen' as tneue_nr, 
       '' as ext_location, 
       '' as ext_sampler,
       '' as tnr,
       b.ext_unit || ' - ' || b.ext_id || '-' || a.ext_animal as ext_nummer,
       ', ' as tbes,
       (select ext_unit || '-' || ext_id from unit where db_unit=a.db_farm) as ext_breeder
  from unit b inner join transfer a on b.db_unit=a.db_unit  
  where a.opening_dt notnull and db_animal=$animal"; 
  
  return $sql;
}

sub sql_transfer2_per_animal {
  my ($animal) = @_;
  my $sql="
  /*---------------------------------------------------------------------------------------------------------*/
  /* transfer */
  select db_animal, 
       a.closing_dt,
       'schliessen' as tneue_nr, 
       '' as ext_location, 
       '' as ext_sampler,
       '' as tnr,
       b.ext_unit || ' - ' || b.ext_id || '-' || a.ext_animal as ext_nummer,
       ', ' as tbes,
       (select ext_unit || '-' || ext_id from unit where db_unit=a.db_farm) as ext_breeder
  from unit b inner join transfer a on b.db_unit=a.db_unit  
  where a.closing_dt notnull and db_animal=$animal"; 
  
  return $sql;
}

sub sql_transfer3_per_animal {
  my ($animal) = @_;
  my $sql="
  /*---------------------------------------------------------------------------------------------------------*/
  /* transfer */
  select db_animal, 
       a.entry_dt,
       (select ext_code from codes where db_code=db_entry_action) as tneue_nr, 
       '' as ext_location, 
       '' as ext_sampler,
       '' as tnr,
       b.ext_unit || ' - ' || b.ext_id || '-' || a.ext_animal as ext_nummer,
       ', ' as tbes,
       (select ext_unit || '-' || ext_id from unit where db_unit=a.db_farm) as ext_breeder
  from unit b inner join transfer a on b.db_unit=a.db_unit  
  where a.entry_dt notnull and db_animal=$animal"; 
  
  return $sql;
}
sub sql_transfer4_per_animal {
  my ($animal) = @_;
  my $sql="
  /*---------------------------------------------------------------------------------------------------------*/
  /* transfer */
  select db_animal, 
       a.exit_dt,
       (select ext_code from codes where db_code=db_exit_action) as tneue_nr, 
       '' as ext_location, 
       '' as ext_sampler,
       '' as tnr,
       b.ext_unit || ' - ' || b.ext_id || '-' || a.ext_animal as ext_nummer,
       ', ' as tbes,
       (select ext_unit || '-' || ext_id from unit where db_unit=a.db_farm) as ext_breeder
  from unit b inner join transfer a on b.db_unit=a.db_unit  
  where a.exit_dt notnull and db_animal=$animal"; 
  
  return $sql;
}


sub sql_units {

return "
  select ext_unit, ext_id, ext_address, 
         case when db_salutation notnull then user_get_ext_code(db_salutation) || ' ' else '' end || 
         case when db_title notnull then user_get_ext_code(db_title) || ' ' else '' end || 
         case when first_name notnull then first_name || ' ' else '' end || 
         case when second_name notnull then second_name else '' end, 
         case when zip notnull then zip || ' ' else '' end || 
         case when town notnull then town else '' end as town
  from address	right outer join unit on address.db_address=unit.db_address
  order by ext_unit, ext_id"
}

sub sql_adresse_absender {
  my ($class,$ext_id,$frmt) = @_;
  my $sql="
  /*---------------------------------------------------------------------------------------------------------*/
  /* Adresse */
  select case when firma_name isnull then
              case when db_salutation  isnull then '' else user_get_ext_code(db_salutation) || ' ' end 
         else 
	      '' 
         end as name1,
	 case when firma_name isnull then
              case when db_title       isnull then '' else user_get_ext_code(db_title) || ' ' end ||
              case when first_name  isnull then '' else first_name || ' ' end  ||
              case when second_name isnull then '' else second_name end  
	 else 
	      case when firma_name isnull then '' else firma_name || ' ' end 
         end as name2,
	 case when street      isnull then '' else street      end as street,
         case when zip         isnull then '' else zip || ' '  end ||
         case when town        isnull then '' else town        end as town
  from address b1 inner join unit c1 on b1.db_address=c1.db_address
  where c1.ext_unit='$class'  and c1.ext_id='$ext_id' limit 1";
  
  return $sql;
}

sub sql_adresse_anschreiben {
  my ($class,$ext_id,$frmt) = @_;
  my $sql="
  /*---------------------------------------------------------------------------------------------------------*/
  /* Adresse */
  select case when firma_name isnull then
              case when db_salutation  isnull then '' else user_get_ext_code(db_salutation) || ' ' end 
         else 
	      case when firma_name isnull then '' else firma_name || ' ' end 
         end as name1,
	 case when firma_name isnull then
              case when db_title       isnull then '' else user_get_ext_code(db_title) || ' ' end ||
              case when first_name  isnull then '' else first_name || ' ' end  ||
              case when second_name isnull then '' else second_name end  
	 else 
	      case when zu_haenden isnull then '' else zu_haenden || ' ' end 
         end as name2,
	 case when street      isnull then '' else street      end as street,
         case when town        isnull then '' else town        end as town,
         case when zip         isnull then '' else zip end as plz
  from address b1 inner join unit c1 on b1.db_address=c1.db_address
  where c1.ext_unit='$class'  and c1.ext_id='$ext_id' limit 1";
  
  return $sql;
}
1;

