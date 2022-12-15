

/* Tier ist männlich und als Vater UND als Mutter in der Datenbank mit Litter*/
/* in diesem Fall wird der Vater als falsch angesehen und auf unbekannt gesetzt*/
select 
(select ext_unit || '-' || ext_id || '-' || ext_animal  from transfer a1 inner join unit b1
 on a1.db_unit=b1.db_unit  where a1.db_animal=a.db_animal  order by b1.ext_unit limit 1) as male_as_sire_and_dam_with_litter,
a.db_animal as db_animal
into temporary table t_wrong_number
from litter a inner join animal b on a.db_animal=b.db_animal
where b.db_sex in (select db_code from codes where class='SEX' and (ext_code='1' or ext_code='3')) and
a.db_animal in (select distinct db_dam from animal) 
;

select * from t_wrong_number
;

/* Update: die Väter aller Tiere mit der falschen Nummer auf unbekannt setzen */
update animal set db_sire=1
where db_sire in (select db_animal from t_wrong_number)
;

/* Update: Wenn Nummer auf Väterseite vorkommt, dann auf unbekannt setzen */
update litter set db_sire=1
where db_sire in (select db_animal from t_wrong_number)
;

/* Update: Geschlecht zuletzt auf weiblich setzen*/
update animal set db_sex=(select db_code from codes where class='SEX' and ext_code='2')
where db_animal in (select db_animal from t_wrong_number)
;

drop table t_wrong_number
;

/*****************************************************************************************/
/* Tier ist weiblich und als Vater UND als Mutter in der Datenbank mit Litter*/
/* in diesem Fall wird der Vater als falsch angesehen und auf unbekannt gesetzt*/
select 
(select ext_unit || '-' || ext_id || '-' || ext_animal  from transfer a1 inner join unit b1
 on a1.db_unit=b1.db_unit  where a1.db_animal=a.db_animal  order by b1.ext_unit limit 1) as female_as_sire_and_dam_with_litter,
a.db_animal as db_animal
into temporary table t_wrong_number
from litter a inner join animal b on a.db_animal=b.db_animal
where b.db_sex in (select db_code from codes where class='SEX' and (ext_code='3' or ext_code='2')) and
      a.db_animal in (select distinct db_sire from animal) 
;

select * from t_wrong_number
;

/* Update: die Väter aller Tiere mit der falschen Nummer auf unbekannt setzen */
update animal set db_sire=1
where db_sire in (select db_animal from t_wrong_number)
;

/* Update: Wenn Nummer auf Väterseite vorkommt, dann auf unbekannt setzen */
update litter set db_sire=1
where db_sire in (select db_animal from t_wrong_number)
;

drop table t_wrong_number
;

/*****************************************************************************************/
/* Tier ist männlich  und kommt als Vater UND als Mutter in der Datenbank ohne Litter*/
/* in diesem Fall wird die Mutter als falsch angesehen und auf unbekannt gesetzt*/
select 
(select ext_unit || '-' || ext_id || '-' || ext_animal  from transfer a1 inner join unit b1
 on a1.db_unit=b1.db_unit where a1.db_animal=a.db_animal order by b1.ext_unit limit 1) as male_as_sire_and_dam_without_litter,
a.db_animal as db_animal
into temporary table t_wrong_number
from animal a
where a.db_sex in (select db_code from codes where class='SEX' and (ext_code='1' or ext_code='3')) and
a.db_animal in (select distinct db_dam from animal) and
a.db_animal in (select distinct db_sire from animal) 
;

select * from t_wrong_number
;

/* Update: die Väter aller Tiere mit der falschen Nummer auf unbekannt setzen */
update animal set db_dam=2
where db_dam in (select db_animal from t_wrong_number)
;

drop table t_wrong_number
;

/*****************************************************************************************/
/* Tier ist weiblich  und kommt als Vater UND als Mutter in der Datenbank ohne Litter*/
/* in diesem Fall wird der Vater als falsch angesehen und auf unbekannt gesetzt*/
select 
(select ext_unit || '-' || ext_id || '-' || ext_animal  from transfer a1 inner join unit b1
 on a1.db_unit=b1.db_unit  where a1.db_animal=a.db_animal  order by b1.ext_unit limit 1) as female_as_animal_sire_and_dam_without_litter,
a.db_animal as db_animal
into temporary table t_wrong_number
from animal a
where a.db_sex in (select db_code from codes where class='SEX' and (ext_code='3' or ext_code='2')) and
a.db_animal in (select distinct db_dam from animal) and
a.db_animal in (select distinct db_sire from animal) 
;

select * from t_wrong_number
;

/* Update: die Väter aller Tiere mit der falschen Nummer auf unbekannt setzen */
update animal set db_sire=1
where db_sire in (select db_animal from t_wrong_number)
;

/* Update: Wenn Nummer auf Väterseite vorkommt, dann auf unbekannt setzen */
update litter set db_sire=1
where db_sire in (select db_animal from t_wrong_number)
;

drop table t_wrong_number
;

/*****************************************************************************************/
/* Tier ist männlich  und kommt als Mutter in der Datenbank vor*/
/* in diesem Fall wird das Geschlecht als falsch angesehen und auf weiblich gesetzt gesetzt*/
select 
(select ext_unit || '-' || ext_id || '-' || ext_animal  from transfer a1 inner join unit b1
 on a1.db_unit=b1.db_unit  where a1.db_animal=a.db_animal  order by b1.ext_unit limit 1) as male_as_sire,
a.db_animal as db_animal
into temporary table t_wrong_number
from animal a 
where a.db_sex in (select db_code from codes where class='SEX' and (ext_code='3' or ext_code='1')) and
      a.db_animal in (select distinct db_dam from animal) 
;

select * from t_wrong_number
;

/* Update: Geschlecht zuletzt auf weiblich setzen*/
update animal set db_sex=(select db_code from codes where class='SEX' and ext_code='2')
where db_animal in (select db_animal from t_wrong_number)
;


drop table t_wrong_number
;

/* * ************************************************************************************** */
/* Tier ist weiblich  und kommt als Vater in der Datenbank vor*/
/* in diesem Fall wird das Geschlecht als falsch angesehen und auf männlich gesetzt gesetzt*/
select 
(select ext_unit || '-' || ext_id || '-' || ext_animal  from transfer a1 inner join unit b1
 on a1.db_unit=b1.db_unit  where a1.db_animal=a.db_animal  order by b1.ext_unit limit 1) as female_as_sire,
a.db_animal as db_animal
into temporary table t_wrong_number
from animal a 
where a.db_sex in (select db_code from codes where class='SEX' and (ext_code='3' or ext_code='2')) and
      a.db_animal in (select distinct db_sire from animal) 
;

select * from t_wrong_number
;

/* Update: Geschlecht zuletzt auf weiblich setzen*/
update animal set db_sex=(select db_code from codes where class='SEX' and ext_code='1')
where db_animal in (select db_animal from t_wrong_number)
;


drop table t_wrong_number
;

/* *************************************************************************************** */
/* Tier ist weiblich  und kommt als Vater in der Datenbank vor*/
/* in diesem Fall wird das Geschlecht als falsch angesehen und auf männlich gesetzt gesetzt*/
select 
(select ext_unit || '-' || ext_id || '-' || ext_animal  from transfer a1 inner join unit b1
 on a1.db_unit=b1.db_unit  where a1.db_animal=a.db_animal  order by b1.ext_unit limit 1) as male_equal_dam,
a.db_animal as db_animal
into temporary table t_wrong_number
from animal a 
where a.db_sire=a.db_dam;

select * from t_wrong_number
;

/* Update: Geschlecht zuletzt auf weiblich setzen*/
update animal set db_sire=1, db_dam=2
where db_animal in (select db_animal from t_wrong_number)
;


drop table t_wrong_number
;

