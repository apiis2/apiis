#!/bin/bash
##############################################################################
# $Id: process_uploads.sh,v 1.25 2012/12/04 08:14:10 heli Exp $
##############################################################################
# cronjob (for root) to process the downloaded file of the popreport

function usage () {
    echo "
    usage: process_uploads.sh [options]
       -i <indir>      - Name of the incoming directory
       -l <logfile>    - Name of the logfile
       -u <user>       - user who runs the jobs
       -g <group>      - group of user, who runs the jobs
       -a <apiishome>  - value of APIIS_HOME
    "
    exit 1;
}

while getopts "i:l:u:g:a:p:h" opt; do
    case $opt in 
        i ) P_INDIR=$OPTARG;;
        l ) P_LOG=$OPTARG;;
        u ) P_USER=$OPTARG;;
        g ) P_GROUP=$OPTARG;;
        a ) P_APIISHOME=$OPTARG;;
        p ) P_PROJ_DIR=$OPTARG;;
        h ) usage;;
        * ) exit;
    esac
done

# some configuration:
INCOMING=${P_INDIR-'/var/lib/postgresql/incoming'}
LOG=${P_LOG-'/var/log/popreport.log'}
USER=${P_USER-'www-data'}
GROUP=${P_GROUP-'popreport'}
APIIS_HOME=${P_APIISHOME-'/home/popreport/production/apiis'}
PROJ_DIR=${P_PROJ_DIR-'/var/lib/postgresql/projects'}
# end configuration
PATH=${APIIS_HOME}/bin:$PATH

HASHES='##############################################################################'
NEXT=`/bin/ls -d ${INCOMING}/20* 2>/dev/null |sort -n |head -1`
DATE=`date +%F-%H.%M.%S`
CPU_NO=`cat /proc/cpuinfo |grep ^processor |wc -l`
HALF=$((${CPU_NO}/2))
if [ $HALF -eq 0 ]; then
    HALF=1
fi

if [ -z "$NEXT" ]; then
    # nothing to do
    exit
fi

WORKING=`/bin/ls -d ${INCOMING}/working* 2>/dev/null |wc -l`
if [ "$WORKING" -ge $HALF ]; then
    exit
fi

if [ ! -d $NEXT ]; then
    echo $HASHES >>$LOG
    echo "${DATE}: Should not happen: $NEXT is not a directory!" >>$LOG
    echo $HASHES >>$LOG
    exit
fi

echo $HASHES >>$LOG
DATE=`date +%F-%H.%M.%S`
echo "${DATE}: processing $NEXT" >>$LOG
STARTDATE=`date "+%F %T"`

BASE=`basename $NEXT`
DATA="${INCOMING}/working_$BASE"
mv $NEXT $DATA
echo "startdate=${STARTDATE}" >>"${DATA}/param"

# for later use:
BASE2=`basename $DATA`
BASE3=`echo $BASE2 |sed -e 's/working_//'`
DONE="${INCOMING}/done_$BASE3"

/bin/chmod -R 0770 $DATA
/bin/chown -R ${USER}:${GROUP} $DATA

EMAIL=`grep ^email= ${DATA}/param  | sed -e 's/^email=//'`
BREED=`grep ^breed= ${DATA}/param  | sed -e 's/^breed=//'`
MALE=`grep ^male= ${DATA}/param  | sed -e 's/^male=//'`
FEMALE=`grep ^female= ${DATA}/param  | sed -e 's/^female=//'`
DATEFORMAT=`grep ^dateformat= ${DATA}/param  | sed -e 's/^dateformat=//'`
DATESEP=`grep ^datesep= ${DATA}/param  | sed -e 's/^datesep=//'`
GETTAR=`grep ^get_tar= ${DATA}/param  | sed -e 's/^get_tar=//'`

# remove special characters:
BREED=`echo $BREED |tr -cd '[:alnum:]'`
# BREED=`echo $BREED |tr -cd '[:graph:]'`  # läßt noch () durch, was die Shell verwirrt
# BREED=`echo $BREED |tr -s '$üÜöÖäÄß ()[]{}' '.'`
MALE=`echo $MALE |tr -s '$üÜöÖäÄß ()[]{}' '.'`
FEMALE=`echo $FEMALE |tr -s '$üÜöÖäÄß ()[]{}' '.'`

if [ "$GETTAR" == "yes" ]; then
    TAR="-g on"
fi
if [ -n "$DATESEP" ]; then
    DATESEP="-s $DATESEP"
fi

echo "Now running run_popreport_file ...." >>$LOG
$APIIS_HOME/bin/run_popreport_file \
    -b "$BREED" \
    -d ${DATA}/datafile \
    -m "$MALE" \
    -f "$FEMALE" \
    -y $DATEFORMAT $DATESEP \
    -e $EMAIL $TAR \
    -I $DATA \
    -P $PROJ_DIR \
    -D >>$LOG 2>&1
# PARAMS="-b \"$BREED\" -d ${DATA}/datafile -m \"$MALE\" -f \"$FEMALE\" -y $DATEFORMAT $DATESEP -e $EMAIL $TAR -I $DATA -D"
# EXE="$APIIS_HOME/bin/run_popreport_file"
# su -s /bin/bash -lc "$EXE $PARAMS" popreport
echo "Running run_popreport_file done" >>$LOG

mv $DATA $DONE

# keep head and tail of datafile:
# /usr/bin/head $DONE/datafile >$DONE/datafile.head
# /usr/bin/tail $DONE/datafile >$DONE/datafile.tail
ENDDATE=`date "+%F %T"`
echo "enddate=${ENDDATE}" >>"${DONE}/param"

E_ELAPSED="$APIIS_HOME/bin/datediff"
ELAPSED=$($E_ELAPSED "$STARTDATE" "$ENDDATE")
# ELAPSED=`su -s /bin/bash -lc "$E_ELAPSED '$STARTDATE' '$ENDDATE'" popreport`
echo "elapsed_time=${ELAPSED}" >>"${DONE}/param"

# deactivate for debugging/rerunning jobs:
# /bin/rm -f $DONE/datafile

DATE=`date +%F-%H.%M.%S`
echo "${DATE}: `basename $NEXT` finished" >>$LOG

# vim: tw=120:
