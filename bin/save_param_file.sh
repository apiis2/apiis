#!/bin/bash
##############################################################################
# $Id: save_param_file.sh,v 1.4 2018/03/23 07:02:50 heli Exp $
##############################################################################
# Save the param files in the incoming directory of popreport and delete the
# rest.

INCOMING=/var/lib/postgresql/incoming
DONE=/var/lib/postgresql/done

shopt -s nullglob # return undef if no dir found
cd $INCOMING

for dir in done_20*
do
    mkdir -p ${DONE}/${dir}
    TMPFILE="${DONE}/${dir}/info"
    cd $dir
    mv param ${DONE}/${dir}
    PDF_FILES=( $(/bin/ls -1 *.pdf 2>/dev/null) )
    echo -e "Folgende pdf-Dateien im Verzeichnis '$dir' wurden erzeugt:\n" >>$TMPFILE
    for file in $(seq 0 $((${#PDF_FILES[@]} - 1))); do
        echo "    ${PDF_FILES[$file]}" >>$TMPFILE
    done
    chown -R root.root ${DONE}/${dir}
    chmod 440 ${DONE}/${dir}/*
    cd $INCOMING
    rm -rf $dir
done

