#!/bin/bash
##############################################################################
# $Id: cleanup_incoming.sh,v 1.9 2013/02/13 13:37:46 heli Exp $
##############################################################################
# do some cleanup in the incoming directory of popreport

INCOMING=/var/lib/postgresql/incoming
DONE=/var/lib/postgresql/done
MAILTO=( "heli@tzv.fal.de" "eg@tzv.fal.de" )
TMPFILE=.mailto-$$

shopt -s nullglob # return undef if no dir found
cd $INCOMING

for dir in done_20*
do
    POPULATION=
    INBREED=
    LOOPGRAPH=
    TITLEPAGE=
    shopt -u nullglob # here we don't want nullglob

    cd $dir
    POPULATION=`/bin/ls Population*pdf 2>/dev/null`
    INBREED=`/bin/ls Inbreeding*pdf 2>/dev/null`
    LOOPGRAPH=`/bin/ls loopgraph*pdf  2>/dev/null`
    TITLEPAGE=`/bin/ls titlepage.pdf  2>/dev/null`

    echo -e "Folgende pdf-Reports im Verzeichnis '$dir' wurden erzeugt:\n" >>$TMPFILE
    test -n "$POPULATION" && echo "    $POPULATION" >>$TMPFILE
    test -n "$INBREED"    && echo "    $INBREED" >>$TMPFILE
    test -n "$LOOPGRAPH"  && echo "    $LOOPGRAPH" >>$TMPFILE
    test -n "$TITLEPAGE"  && echo "    $TITLEPAGE" >>$TMPFILE

    ATTACH="-a param"
    test -n "$POPULATION" && ATTACH="$ATTACH $POPULATION"
    test -n "$INBREED"    && ATTACH="$ATTACH $INBREED"
    test -n "$LOOPGRAPH"  && ATTACH="$ATTACH $LOOPGRAPH"
    test -n "$TITLEPAGE"  && ATTACH="$ATTACH $TITLEPAGE"

    echo -e "\nJobverzeichnis nach ${DONE}/$dir verschoben." >>$TMPFILE

    JOBDATE=`echo $dir |sed -e s/done_//`
    # cat "$TMPFILE" |mutt -s "Bericht Popreport-Job $JOBDATE" $ATTACH -- ${MAILTO[@]} 

    cd $INCOMING
    rm -f $dir/$TMPFILE
    mv $dir $DONE
done

