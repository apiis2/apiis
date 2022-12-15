
/*Zusammenfassen der Tiere mit Fruchtbarkeit und selektieren nach DL in extra Tabelle*/
/*Nur Tiere mit mehr als 2 Würfen */

select b.db_animal as db_animal, 
       (select upper(ext_id) || '-' || ext_animal
        from unit a1 inner join transfer b1 on a1.db_unit=b1.db_unit
        where b1.db_animal=b.db_animal order by a1.ext_unit asc ,entry_dt desc limit 1) as ext_animal,
       a.db_sire as db_sire, 
       a.db_dam as db_dam,
        count(b.db_animal) as cntWuerfe, avg(b.born_alive_no) as avgFerkel, sum(b.born_alive_no) as sumFerkel
from animal a inner join litter b on a.db_animal=b.db_animal
 where a.db_breed=(select db_code from codes where class='BREED' and ext_code='1')
 group by b.db_animal,a.db_sire, a.db_dam
 having count(b.db_animal)>2;

