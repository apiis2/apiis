drop table t_brockmann; 

/*Zusammenfassen der Tiere mit Fruchtbarkeit und selektieren nach DL in extra Tabelle*/
/*Nur Tiere mit mehr als 2 Würfen */
select b.db_animal as db_animal, a.db_sire as db_sire, a.db_dam as db_dam,
        count(b.db_animal) as cntWuerfe, avg(b.born_alive_no) as avgFerkel, sum(b.born_alive_no) as sumFerkel
into temporary table t_brockmann
from animal a inner join litter b on a.db_animal=b.db_animal
 where a.db_breed=(select db_code from codes where class='BREED' and ext_code='1')
 group by b.db_animal,a.db_sire, a.db_dam
 having count(b.db_animal)>2;


/*Ermitteln der Anzahl Tiere pro Vater (vHG)und pro Mutter (mHG)*/
Select x.db_sire, 
       (select upper(ext_id) || '-' || ext_animal
        from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
        where b1.db_animal=x.db_sire order by a1.ext_unit asc ,entry_dt desc limit 1) as ext_animal,
       count(x.db_animal) as cntTiere, sum(x.cntWuerfe) as sumWuerfe, avg(x.avgFerkel) as avgFerkel, 
       sum(x.sumFerkel) as sumFerkel  from t_brockmann x group by x.db_sire, ext_animal having count(x.db_animal)>20
union 
Select db_dam, 
       (select upper(ext_id) || '-' || ext_animal
        from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
        where b1.db_animal=x.db_dam order by a1.ext_unit asc ,entry_dt desc limit 1) as ext_animal,
	count(db_animal) as cntTiere, sum(cntWuerfe) as sumWuerfe, avg(avgFerkel) as avgFerkel, sum(sumFerkel) as sumFerkel  from t_brockmann x  group by db_dam having count(db_animal)>5;

