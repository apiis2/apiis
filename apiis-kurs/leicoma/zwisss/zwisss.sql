set datestyle to 'german';

select animal, bvr2_ltz as ltz, bvr2_usf as usf, bvr2_usmd as usmd, bvr2_ptz as ptz, bvr2_fuvz as fuvz, bvr2_rmfl as rmfl,
           bvr2_ffl as ffl, bvr2_imf as imf, bvr2_ph1k as ph1k, bvr2_dv as dv
    into temporary table t3
    from leicoma_2_bv;

create index ti3 on t3 (animal);


select animal into temporary table z1 from leicoma_1_bv where tbv1 notnull 
  union
  select animal from leicoma_2_bv where tbv2 notnull;

create index zi1 on z1 (animal);

select 
  (select upper(ext_id) || '-' || ext_animal
   from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
   where b1.db_animal=a.db_animal order by a1.ext_unit asc ,b1.opening_dt desc limit 1) as ext_animal,
  (select ext_animal
   from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
   where b1.db_animal=a.db_animal order by a1.ext_unit asc,b1.opening_dt desc limit 1) as ext_animal1,
 (select upper(ext_id) || '-' || ext_animal
   from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
   where b1.db_animal=a.db_sire order by a1.ext_unit asc ,b1.opening_dt desc limit 1) as ext_sire,
 (select upper(ext_id) || '-' || ext_animal
   from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
   where b1.db_animal=a.db_dam  order by a1.ext_unit asc, b1.opening_dt desc limit 1) as ext_dam,
  a1.short_name as rasse,
  (select ext_id from unit inner join locations on unit.db_unit=locations.db_location 
   where locations.db_location notnull and locations.db_animal=a.db_animal order by entry_dt desc limit 1) as standort,
  a.birth_dt,
  (select case when exit_dt isnull then (select ext_code from codes inner join animal on animal.db_selection=codes.db_code where animal.db_animal=a.db_animal)::integer else 0 end  as aktiv from locations 
   where locations.db_animal=a.db_animal order by exit_dt desc limit 1) as aktiv,
  (select short_name from codes where db_code=a.db_sex) as geschlecht,
  (select short_name from codes inner join genes on genes.db_genes=codes.db_code where genes.db_animal=a.db_animal limit 1) as mhs,
  case when c3.sjm notnull then '' else c3.bjq end as bjq,
  a.name,

  /* Zeile 11 */
  /* 1. Zuchtwertschätzung FB1*/
  round(c1.lgf::numeric,1) as dlgf,
  round((0.4*b1.bvr1_lgf1+0.6*b1.bvr1_lgf2_e)::numeric,2) as lgf,
  round(b1.tbv1::numeric,1) as gzwfb,
  
  /* 2. Zuchtwertschätzung FB2*/
  '' as dlgf,
  '' as dmgg,
  '' as dsgg,
  '' as lgf,
  '' as mgg,
  '' as sgg,
  '' as gzwfb2,
  
  /* Zeile 21*/
  /* 3. Zuchtwertschätzung MSL-MR*/ 
  c3.ltz as dltz,
  c3.usf as dusf,
  c3.usmd as dusmd,
  c3.ptz as dptz,
  c3.fuvz as dfuvz,
  c6.sc_muscle_area_k as drmfl,
  c6.sc_fat_area_k as dffl,
  c3.ph1k as dph1k,
  c3.imf as dimf,
  c3.dv as ddv,
  /*31*/
  round(b2.ltz::numeric,1) as ltz,
  round(b2.usf::numeric,2) as usf,
  round(b2.usmd::numeric,2) as usmd,
  round(b2.ptz::numeric,1) as ptz,
  round(b2.fuvz::numeric,1) as fuvz,
  round(b2.rmfl::numeric,2) as rmfl,
  round(b2.ffl::numeric,2) as ffl,
  round(b2.imf::numeric,2) as imf,
  round(b2.ph1k::numeric,2) as ph1k,
  round(b2.dv::numeric,2) as dv,
  /*41*/ 
  '' as gzwmsl,
  '' as gzwskq,
  '' as gzwflq,

  /* Feldtest*/
  '' as dntz,
  '' as dmffom,
  '' as dflm,
  '' as dspm,
  '' as ntz,
  '' as mffom,
  '' as flm,
  '' as spm,
  '' as gzwft,
  '' as gzw,
  c6.sc_mf_bonn as mfb,
  c6.sc_carcass_lt as il,
  c7.aufwand as fua,
  c3.sjm as sjm,
  (select ext_code from codes where db_code=c8.db_grade) as khkl,
  c8.sc_carcass_wt_warm as kskmw,
  ((select event_dt from event where event_id=c8.event_id)-a.birth_dt) as kalter,
  c3.lm,
  c3.usf
       
from 
  z1 as z 
  inner join animal a on a.db_animal=z.animal
  inner join codes a1 on a.db_breed=a1.db_code
  inner join codes a2 on a.db_sex=a2.db_code

  left outer join leicoma_1_bv b1 on z.animal=b1.animal
  left outer join t3 as b2 on z.animal=b2.animal
  
  left outer join (
  select leicoma_1_daten.animal, avg(case when da1_lgf2_e notnull then da1_lgf2_e else case when da1_lgf1 notnull then da1_lgf1 end end) as lgf from leicoma_1_daten inner join leicoma_1_bv on leicoma_1_daten.animal=leicoma_1_bv.animal where tbv1 notnull group by leicoma_1_daten.animal
  ) as c1 on z.animal=c1.animal
  left outer join 
  
  (select leicoma_2_daten.animal, da2_ltz as ltz, da2_usf as usf, da2_usmd as usmd, da2_ptz as ptz, da2_fuvz as fuvz,
         da2_rmfl as rmfl, da2_ffl as ffl, da2_imf as imf, da2_ph1k as ph1k, da2_dv as dv,da2_bjq as bjq, da2_abt as sjm, da2_lmf as lm, da2_pelm as pelm
  from leicoma_2_daten inner join leicoma_2_bv on leicoma_2_daten.animal=leicoma_2_bv.animal) as c3 on z.animal=c3.animal 

  left outer join slaughter_extended as c6 on c6.db_animal=z.animal
  left outer join slaughter as c8 on c8.db_animal=z.animal
  left outer join (select db_animal as db_animal, aufwand as aufwand from feed inner join event on feed.event_id=event.event_id inner join codes on event.db_event_type=codes.db_code where ext_code='pende') as c7 on c7.db_animal=z.animal
;
