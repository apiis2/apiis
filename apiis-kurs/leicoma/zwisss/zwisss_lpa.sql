set datestyle to 'german';

select animal, bvr3_ltz as ltz, bvr3_usf as usf, bvr3_usmd as usmd, bvr3_ptz as ptz, bvr3_fuvz as fuvz, bvr3_rmfl as rmfl, 
           bvr3_ffl as ffl, bvr3_imf as imf, bvr3_ph1k as ph1k, bvr3_dv as dv,tbv3 as tbv,tbv6 as tbv1, tbv8 as tbv2
    into temporary table t3
    from th_3_bv
    union
    select animal, bvr4_ltz, bvr4_usf, bvr4_usmd, bvr4_ptz, bvr4_fuvz, bvr4_rmfl, bvr4_ffl, bvr4_imf, bvr4_ph1k, bvr4_dv, tbv4 ,tbv7, tbv9
    from th_4_bv;

create index ti3 on t3 (animal);

select animal into temporary table z1 from th_1_bv where tbv1 notnull 
  union
  select animal from th_2_bv where tbv2 notnull 
  union
  select animal from th_3_bv  
  union
  select animal from th_4_bv 
  union
  select animal from th_5_bv;

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
  round(c2.lgf::numeric,1) as dlgf,
  round(c2.mgg::numeric,2) as dmgg,
  round(c2.sgg::numeric,2) as dsgg,
  round((0.4*b2.bvr2_lgf1+0.6*b2.bvr2_lgf2_e)::numeric,2) as lgf,
  round(b2.bvr2_mgg::numeric,2) as mgg,
  round(b2.bvr2_sgg::numeric,2) as sgg,
  round(b2.tbv2::numeric,1) as gzwfb2,
  
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
  round(b3.ltz::numeric,1) as ltz,
  round(b3.usf::numeric,2) as usf,
  round(b3.usmd::numeric,2) as usmd,
  round(b3.ptz::numeric,1) as ptz,
  round(b3.fuvz::numeric,1) as fuvz,
  round(b3.rmfl::numeric,2) as rmfl,
  round(b3.ffl::numeric,2) as ffl,
  round(b3.imf::numeric,2) as imf,
  round(b3.ph1k::numeric,2) as ph1k,
  round(b3.dv::numeric,2) as dv,
  /*41*/ 
  round(b3.tbv::numeric,1) as gzwmsl,
  round(b3.tbv1::numeric,1) as gzwskq,
  round(b3.tbv2::numeric,1) as gzwflq,

  /* Feldtest*/
  c5.da5_ntz as dntz,
  c5.da5_mffom as dmffom,
  c5.da5_flm as dflm,
  c5.da5_spm as dspm,
  round(b5.bvr5_ntz::numeric,1) as ntz,
  round(b5.bvr5_mffom::numeric,2) as mffom,
  round(b5.bvr5_flm::numeric,2) as flm,
  round(b5.bvr5_spm::numeric,2) as spm,
  round(b5.tbv5::numeric,1) as gzwft,
  round(b6.tbv9::numeric,1) as gzw,
  c6.sc_mf_bonn as mfb,
  c6.sc_carcass_lt as il,
  c7.aufwand as fua,
  c3.sjm as sjm,
  (select ext_code from codes where db_code=c8.db_grade) as khkl,
  c8.sc_carcass_wt_warm as kskmw,
  ((select event_dt from event where event_id=c8.event_id)-a.birth_dt) as kalter,
  c3.lm,
  case when c3.pelm notnull then
  (select (basis-c3.pelm)*faktor+c3.usf from v_ssd_corrections where pruefart='s' and ext_sex=a2.ext_code and ext_breed=a1.ext_code) 
  else
  (select (basis-c3.lm)*faktor+c3.usf from v_ssd_corrections where pruefart='f' and ext_sex=a2.ext_code and ext_breed=a1.ext_code) 
  end as us_k
       
from 
  z1 as z 
  inner join animal a on a.db_animal=z.animal
  inner join codes a1 on a.db_breed=a1.db_code
  inner join codes a2 on a.db_sex=a2.db_code

  left outer join th_1_bv b1 on z.animal=b1.animal
  left outer join th_2_bv b2 on z.animal=b2.animal
  left outer join t3 as b3 on z.animal=b3.animal
  left outer join th_5_bv b5 on z.animal=b5.animal
  left outer join th_6_bv b6 on z.animal=b6.animal
  left outer join (
  select th_1_daten.animal, avg(case when da1_lgf2_e notnull then da1_lgf2_e else case when da1_lgf1 notnull then da1_lgf1 end end) as lgf from th_1_daten inner join th_1_bv on th_1_daten.animal=th_1_bv.animal where tbv1 notnull group by th_1_daten.animal
  ) as c1 on z.animal=c1.animal
  left outer join (
  select animal, avg(lgf) as lgf, avg(mgg) as mgg, avg(sgg) as sgg from (
    select th_2_daten.animal, da2_lgf1 as lgf, da2_mgg as mgg, da2_sgg as sgg from th_2_daten  inner join th_2_bv on th_2_daten.animal=th_2_bv.animal where th_2_daten.da2_mgg notnull or tbv2 notnull
    union 
    select th_2_daten.animal, da2_lgf2_e as lgf, da2_mgg as mgg, da2_sgg as sgg  from th_2_daten inner join th_2_bv on th_2_daten.animal=th_2_bv.animal where th_2_daten.da2_mgg notnull or th_2_bv.tbv2 notnull) as x
  group by animal) as c2 on z.animal=c2.animal
  left outer join 
  
  (select th_3_daten.animal, da3_ltz as ltz, da3_usf as usf, da3_usmd as usmd, da3_ptz as ptz, da3_fuvz as fuvz,
         da3_rmfl as rmfl, da3_ffl as ffl, da3_imf as imf, da3_ph1k as ph1k, da3_dv as dv,da3_bjq as bjq, da3_abt as sjm, da3_lmf as lm, da3_pelm as pelm
  from th_3_daten inner join th_3_bv on th_3_daten.animal=th_3_bv.animal 
  union 
  select th_4_daten.animal, da4_ltz as ltz, da4_usf as usf, da4_usmd as usmd, da4_ptz as ptz, da4_fuvz as fuvz,
         da4_rmfl as rmfl, da4_ffl as ffl, da4_imf as imf, da4_ph1k as ph1k, da4_dv as dv,da4_bjq as bjq, da4_abt as sjm, da4_lmf as lm, da4_pelm as pelm
  from th_4_daten  inner join th_4_bv on th_4_daten.animal=th_4_bv.animal ) as c3 on z.animal=c3.animal

  left outer join th_5_daten as c5 on c5.animal=z.animal
  left outer join slaughter_extended as c6 on c6.db_animal=z.animal
  left outer join slaughter as c8 on c8.db_animal=z.animal
  left outer join (select db_animal as db_animal, aufwand as aufwand from feed inner join event on feed.event_id=event.event_id inner join codes on event.db_event_type=codes.db_code where ext_code='pende') as c7 on c7.db_animal=z.animal
;
