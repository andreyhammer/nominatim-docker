#!/bin/bash -xv

# Modified version of script by mdeweerd (originally by spin0us)
# to work with Nominatim v3.2.0, etc.
#
# Source: https://gist.githubusercontent.com/mdeweerd/9bc5f60f2d6733e907f3/raw/cf307d83adb2b308fc00e612ff58875dcb4972e0/update_database.sh

# Hint:
#
# Use "bashdb ./update_database.sh" and bashdb's "next" command for step-by-step
# execution.

# ******************************************************************************

# REPLACE WITH LIST OF YOUR "COUNTRIES":
#
COUNTRIES=""

# SET TO YOUR NOMINATIM build FOLDER PATH:
#
NOMINATIMBUILD="/app/src/build"

# SET TO YOUR update data FOLDER PATH:
#
UPDATEDIR="/data/update"

UPDATEBASEURL="https://download.geofabrik.de"
UPDATECOUNTRYPOSTFIX="-updates"

# If you do not use Photon, let Nominatim handle (re-)indexing:
#
FOLLOWUP="$NOMINATIMBUILD/utils/update.php --index"
#
# If you use Photon, update Photon and let it handle the index
# (Photon server must be running and must have been started with "-database",
# "-user" and "-password" parameters):
#
#FOLLOWUP="curl http://localhost:2322/nominatim-update"

# ******************************************************************************

UPDATEDONE=0 # 0 = no, 1 = yes.

# For each country, check, if configuration exists (if not, create one)
# and then import the diff:
#
for COUNTRY in $COUNTRIES;
do
    DIR="$UPDATEDIR/$COUNTRY"
    FILE="$DIR/configuration.txt"
    BASEURL="$UPDATEBASEURL/$COUNTRY$UPDATECOUNTRYPOSTFIX"
    FILENAME=${COUNTRY//[\/]/_}

    if [ ! -f ${FILE} ];
    then
        mkdir -p ${DIR}
        osmosis --rrii workingDirectory=${DIR}/.
        echo baseUrl=${BASEURL} > ${FILE}
        echo maxInterval = 0 >> ${FILE}
        cd ${DIR}
        wget ${BASEURL}/state.txt
    fi

    osmosis --rri workingDirectory=${DIR}/. --wxc ${DIR}/${FILENAME}.osc.gz

    # For each diff file, do the import:
    #
    LIST1=$DIR/*.osc.gz # Maybe not necessary (file empty?)?
    LIST2=*.osc.gz
    LIST="$LIST1 $LIST2"
    for OSC in $LIST;
    do
        if [ -f ${OSC} ];
        then
           ${NOMINATIMBUILD}/utils/update.php --import-diff ${OSC}
           rm ${OSC}
           UPDATEDONE=1 # 0 = No, 1 = Yes.
        fi
    done
done

# Re-index, if (maybe) needed:
#
if ((${UPDATEDONE}));
then
    ${FOLLOWUP}
fi
