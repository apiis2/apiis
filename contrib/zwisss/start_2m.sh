#!/bin/bash

#########################################################
#
# Shell-Srcipt to start pest and vce automatically
# It is designed for 2-trait models
# 
# modifikations for pest must be in change_model_pest.pl
# modifikations for vce must bi in change_model_vce.pl
#
# the order of traits in start_2m.sh must be the same like in
# change_model_*
#
# Note: Paths of parameterfiles or programms must be consistence
#
# See to change_model_pest.pl, change_model_vce.pl
#
# ulf.mueller@koellitsch.lfl.smul.sachsen.de
#
##########################################################

####### section of configuration #########################

v='0 1 2 3 4 5 6 7 8 9';
t=(ltz usf imf fuvz ffl usmd rmfl ptz ph1k dv);
# path of file change_model_*
p='../../../..';

# path of pest
pp='/home/b08guest/apiis/th/zwisss';

# path for vce
pv='/home/b08guest/apiis/th/zwisss';

######## end of section ##################################


for i in $v
do
  for j in $v
  do
    if test $i -eq $j
    then
       continue
    fi
    if test $j -lt $i
    then
       continue
    fi
    perl $p/change_model_pest.pl $i $j;
    k=${t[$i]}_${t[$j]};
    
    $pp/pest $k.par 300;
    if test -e efflist.pest;
    then
      rm -f *.pest;
      rm -f *.list;
    fi
  
    perl $p/change_model_vce.pl $i $j;
    $pv/vce $k.job;
    pwd >> vce.erg
    $k >> vce.erg
    less $k.job.cov-fmt >> vce.erg
    pwd >> vce.erg.long
    $k >> vce.erg
    less $k.job.lst >> vce.erg.long
    rm *.vce;
  
  done
done
