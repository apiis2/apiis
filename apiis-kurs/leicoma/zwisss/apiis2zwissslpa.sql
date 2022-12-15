select 
  (select upper(ext_id) || '-' || ext_animal
   from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
   where b1.db_animal=a.db_animal order by a1.ext_unit asc ,b1.opening_dt desc limit 1) as ext_animal,
  (select ext_id from unit inner join locations on unit.db_unit=locations.db_location
   where locations.db_location notnull and locations.db_animal=a.db_animal order by entry_dt asc limit 1) as standort,
  (select short_name from codes where db_code=a.db_breed) as gk,
  a.birth_dt as dat_geb,
  (select upper(ext_id) || '-' || ext_animal
   from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
   where b1.db_animal=a.db_sire order by a1.ext_unit asc ,b1.opening_dt desc limit 1) as ext_sire,
  (select upper(ext_id) || '-' || ext_animal
   from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
   where b1.db_animal=a.db_dam  order by a1.ext_unit asc, b1.opening_dt desc limit 1) as ext_dam,
  NULL as stall_nr,
  NULL as dg,
  c1.event_dt as dat_ank,
  c.test_wt as lm_ank,
  c1.event_dt-a.birth_dt as lt_geb_ank,
  round((c.test_wt/(c1.event_dt-a.birth_dt)*1000)::numeric,0) as ltz_geb_ank,
  a.leaving_dt as dat_abg,
  (select short_name from codes where db_code=a.db_leaving) as abg_grund,
  NULL as abg_urs,
  d1.event_dt as dat_pa,
  d1.event_dt-a.birth_dt as lt_pa,
  d.test_wt as lm_pa,
  round((d.test_wt/(d1.event_dt-a.birth_dt)*1000)::numeric,0) as ltz_pa,
  e1.event_dt as dat_pe,
  e1.event_dt-a.birth_dt as lt_pe,
  e.test_wt as lm_pe,
  round((e.test_wt/(e1.event_dt-a.birth_dt)*1000)::numeric,0) as ltz,
  f1.event_dt as dat_schl,
  (select short_name from codes where db_code=a.db_sex) as geschlecht,
  (select exit_dt from locations a where a.db_animal=x.db_animal and a.db_location=x.db_location and 
   db_exit_action=(select db_code from codes where ext_code='sale' and class='EXIT_ACTION')) as dat_verk,
  x.ext_id as station
  	
from animal a inner join 
(select distinct a.db_animal as db_animal, a.db_location as db_location, b.ext_id as ext_id from locations a inner join unit b on a.db_location=b.db_unit where b.ext_unit='station' and (b.ext_id='lpa-21' or b.ext_id='lpa-13' or b.ext_id='lpa-14')) as x
 on a.db_animal=x.db_animal
 left outer join weight c on x.db_animal=c.db_animal inner join event c1 on c.event_id=c1.event_id 
                                                     inner join codes c2 on (c1.db_event_type=c2.db_code and c2.ext_code='ankauf')
 left outer join weight d on x.db_animal=d.db_animal inner join event d1 on d.event_id=d1.event_id 
                                                     inner join codes d2 on (d1.db_event_type=d2.db_code and d2.ext_code='pbeginn')
 left outer join weight e on x.db_animal=e.db_animal inner join event e1 on e.event_id=e1.event_id 
                                                     inner join codes e2 on (e1.db_event_type=e2.db_code and e2.ext_code='pende')
 left outer join slaughter f on x.db_animal=f.db_animal inner join event f1 on f.event_id=f1.event_id 
                                                     inner join codes f2 on (f1.db_event_type=f2.db_code and
                                                     f2.ext_code='schlachtung')
;
