#!/bin/bash

############ Edit ##############################
# project="project1 project2"

project="horse";

# temp directory for sessiondata, pdf-files, tex-files
tmp="/home/b08mueul/apiis/tmp";

# define subdirectories for menus
# menudirectories="";
menudirectories="1 2";
menulabel="0_Menues";

# define subdirectories for forms 
# formdirectories="Schluessel Ladestroeme";
formdirectories="Schluessel Ladestroeme";
formlabel="1_Formulare";

# define subdirectories for reports
# reportdirectories="InitDB";
reportdirectories="InitDB";
reportlabel="2_Berichte";

# ref_breedprg=0|1 
# 0 - no support to load historical datas
# 1 - create links and directories 
ref_breedprg=0;

############ END ###############################

echo $APIIS_HOME;
# test if APIIS_HOME is set and directory $APIIS_HOME exists

if [ $APIIS_HOME ] && [ -d $APIIS_HOME ]; then 
  echo -e "APIIS_HOME: $APIIS_HOME";
  cd $APIIS_HOME;
else 
  echo -e "APIIS_HOME not set -> exit";
  exit;
fi

if [ ${ref_breedprg} -eq 1  ]  && [ ! -d $APIIS_HOME/ref_breedprg ] ; then 
  echo -e "ref_breedprg not checked out -> exit";
  exit;
fi

# test if $APIIS_HOME/bin in the PATH-variable
if [[ ! $PATH =~ "$APIIS_HOME/bin" ]]; then 
  echo 'ERROR: $APIIS_HOME/bin not in $PATH';
fi


# creates a new directory for temp-files and set accessrights
#
if  ! test -d $tmp  ; then
  mkdir $tmp;
  chmod ugo+rwx $tmp;
  echo -e "create new directory $tmp";
fi
  
# creates a new directory for sessiondata
#
if  ! test -d $tmp/sessiondata ; then
  mkdir $tmp/sessiondata;
  chmod ugo+rwx $tmp/sessiondata;
  echo -e "create new directory $tmp/sessiondata";
fi

# creates a new directory for sessiondata
#
if  ! test -d $tmp/apiis_arm_sessiondata  ; then
  mkdir $tmp/apiis_arm_sessiondata;
  chmod ugo+rwx $tmp/apiis_arm_sessiondata;
  echo -e "create new directory $tmp/apiis_arm_sessiondata";
fi

# loop for all projects

for vproject in ${project}
do

  # creates a new directory for the specified project
  #
  if ! test -d $APIIS_HOME/$project; then
    mkdir $APIIS_HOME/$project;
    echo -e "create new directory $APIIS_HOME/$project";
  fi
  
  cd $APIIS_HOME/$project;
  pwd;
  
  # create necessary directories within each project
  #
  z="var var/log bin doc etc etc/menu etc/myreports mkdir etc/reports etc/forms etc/menus lib lib/images initial initial/mail initial/firststep initial/archiv etc/menus etc/forms etc/reports";

  for vdir in ${z}
  do
    if ! test -d $vdir
    then
      mkdir $vdir;
      echo -e  "  create $vdir";
    else 
      echo -e  "  $vdir --> ok";
    fi
  done
  chmod go+w var;
  chmod go+w var/log;

  cd $APIIS_HOME/${vproject}/etc;
  if [ ! -h model.dtd ]; then 
    ln -s $APIIS_HOME/etc/model.dtd .
  fi
  
  for mm in ${menudirectories}
  do
    if ! test -d $APIIS_HOME/${vproject}/etc/menus/$mm
    then
      mkdir $APIIS_HOME/${vproject}/etc/menus/$mm;
      echo -e  "  create $APIIS_HOME/${vproject}/etc/menus/$mm";
    else 
      echo -e  "  $APIIS_HOME/${vproject}/etc/menus/$mm --> ok";
    fi

    # create links for menus
    cd $APIIS_HOME/${vproject}/etc/menus/$mm;
    if [ ! -h form.dtd ]; then 
      ln -s $APIIS_HOME/etc/form.dtd .
    fi
  done
  
  for mm in ${formdirectories}
  do
    if ! test -d $APIIS_HOME/${vproject}/etc/forms/$mm
    then
      mkdir $APIIS_HOME/${vproject}/etc/forms/$mm;
      echo -e  "  create $APIIS_HOME/${vproject}/etc/forms/$mm";
    else 
      echo -e  "  $APIIS_HOME/${vproject}/etc/forms/$mm --> ok";
    fi

    # create links for menus
    cd $APIIS_HOME/${vproject}/etc/forms/$mm;
    if [ ! -h form.dtd ]; then 
      ln -s $APIIS_HOME/etc/form.dtd .
    fi
  done
  
  # create links for reports
  for mm in ${reportdirectories}
  do
    if ! test -d $APIIS_HOME/${vproject}/etc/reports/$mm
    then
      mkdir $APIIS_HOME/${vproject}/etc/reports/$mm;
      echo -e  "  create $APIIS_HOME/${vproject}/reports/forms/$mm";
    else 
      echo -e  "  $APIIS_HOME/${vproject}/etc/reports/$mm --> ok";
    fi

    # create links for menus
    cd $APIIS_HOME/${vproject}/etc/reports/$mm;
    if [ ! -h report.dtd ]; then 
      ln -s $APIIS_HOME/etc/report.dtd .
    fi
  done

  #--- if load historical datas
  #
  if [ ${ref_breedprg} -eq 1  ]; then

    cd $APIIS_HOME/${vproject}/lib;
    if [ ! -h AccessRights.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/lib/AccessRights.pm .
    fi

    cd $APIIS_HOME/${vproject}/etc;
    if [ ! -h AR.xml ]; then
      ln -s $APIIS_HOME/ref_breedprg/etc/AR.xml .
    fi
    
    cd $APIIS_HOME/${vproject}/initial;
    pwd;
    if [ ! -h S3_load_codes.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/S3_load_codes.pm S3_load_codes.pm
    fi
    if [ ! -h S5_load_jobs.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/S5_load_jobs.pm S5_load_jobs.pm
    fi
    if [ ! -h O2_load_keys.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/O2_load_keys.pm O2_load_keys.pm
    fi
    if [ ! -h S7_collect_dup_animal.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/S7_collect_dup_animal.pm S7_collect_dup_animal.pm
    fi
    if [ ! -h S8_load_ext_animal.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/S8_load_ext_animal.pm S8_load_ext_animal.pm
    fi
    if [ ! -h S9_transfer_to_animal.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/S9_transfer_to_animal.pm S9_transfer_to_animal.pm
    fi
    if [ ! -h S10_load_data.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/S10_load_data.pm S10_load_data.pm
    fi
    if [ ! -h S14_fill_last_action.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/S14_fill_last_action.pm S14_fill_last_action.pm
    fi
    if [ ! -h S16_load_codes.pm ]; then
      ln -s $APIIS_HOME/ref_breedprg/initial/S16_load_codes.pm S16_load_codes.pm
    fi
  pwd;
  fi


done
