#!/bin/bash

######### Edit
project='leicoma';
model='mslmr';
password='fwihbv';
typ="0";
path=$APIIS_HOME/$project/zwisss/$model;
############ End

cd $path;
for h in $typ;
do
  perl extract_for_blup_$model.pl -p project -d $USER -w $password;
done

##################### step 3 #####################################
# vi pestmodel
##################################################################
# - modify parameterfile for pest using information in file
#   $path/structure.txt
# - change covariables to 0
# - max_iter =2 is enough to create a pestfile
# - OUTFILE='mslmr.dat.vce' [text
# - OUTFILE='mslmr.ped.vce' [text
# - start pest to create a vce-datafile with all traits
##################################################################

pest $model.pest 500;

##################### step 4 #####################################
#  modify change_model_pest.pl
##################################################################
# - cp $APIIS_HOME/contrib/zwisss/change_model_pest.pl $APIIS_HOME/$project/zwisss/
# - replace model-section and treated_as_missing-section with parameter
#   from your $model.pest
################################################################## 


##################### step 5 #####################################
#  modify change_model_vce.pl
##################################################################
# - cp $APIIS_HOME/contrib/zwisss/change_model_vce.pl $APIIS_HOME/$project/zwisss/
# - replace model-section 
#   from your $model.vce
################################################################## 


##################### step 6 #####################################
#  prepare template for pest and vce 
##################################################################
#  template.vce:
#    Einträge unter dependent löschen
#    Einträge unter independent aus vce-datenfile kopieren
#    unter datefile format so einstellen, dass zwei-Merkmalsmodelle
#    gerechnet werden können
#    alle Einträge unter Model entfernen
#
#  template.pest 
#    alle Einträge unter model entfernen
#    alle Einträge unter treated_as_missing entfernen
# 
##################################################################


