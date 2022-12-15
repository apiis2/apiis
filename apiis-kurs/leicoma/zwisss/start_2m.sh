#!/bin/bash

v='0 1 2 3 4 5 6 7 8';
t=(ltz usf imf fuvz  ffl  usmd rmfl ptz ph1k);
for i in $v
do
  for j in $v
  do
    if test ${i} -eq ${j}
    then
       continue
    fi
    if test ${j} -lt ${i}
    then
       continue
    fi
    perl change_model_pest.pl $i $j;
    k=${t[$i]}_${t[$j]};
    pest $k.pest 300;
    
    if test -e efflist.pest;
    then
      rm -f efflist.pest;
      rm -f *.list;
    fi
  
    perl change_model_vce.pl $i $j;
    vce $k.vce;
    pwd >> vce.erg
    echo $k >> vce.erg
    less $k.vce.cov-fmt >> vce.erg
    pwd >> vce.erg.long
    echo $k >> vce.erg
    less $k.vce.lst >> vce.erg.long
  done
done
