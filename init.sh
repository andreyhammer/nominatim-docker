#!/bin/bash

GEOFABRIK_URL=http://download.geofabrik.de
COUNTRY_POSTFIX=-latest.osm.pbf
DATA_DIR=/data
UPDATE_DIR=$DATA_DIR/update
PG_DATA=/var/lib/postgresql/11/main
PG_CONF=/etc/postgresql/11/main/postgresql.conf

#Download pbf if not exists
for COUNTRY_ in $NOMINATIM_COUNTRIES
do
    COUNTRY=`basename $COUNTRY_`
    if [ ! -f $DATA_DIR/$COUNTRY$COUNTRY_POSTFIX ]; then
        echo "Downloading $COUNTRY.."
        curl  $GEOFABRIK_URL/$COUNTRY_$COUNTRY_POSTFIX -o $DATA_DIR/$COUNTRY$COUNTRY_POSTFIX
    fi

done


for COUNTRY_PATH_ in `ls -1 $DATA_DIR/*$COUNTRY_POSTFIX`
do
    COUNTRY_FROM_FILE=`basename $COUNTRY_PATH_ | cut -d "-" -f 1`
    for COUNTRY_ in $NOMINATIM_COUNTRIES
    do
        COUNTRY=`basename $COUNTRY_`
        if [ $COUNTRY == $COUNTRY_FROM_FILE ];then
            mkdir -p $UPDATE_DIR/$COUNTRY_
            #generate state.txt file
            SEQ_NUM=`osmium fileinfo -g header.option.osmosis_replication_sequence_number $COUNTRY_PATH_`
            REPL_TS=`osmium fileinfo -g header.option.osmosis_replication_timestamp $COUNTRY_PATH_ | sed 's|:|\\\:|g'`
            echo "sequenceNumber=$SEQ_NUM" >> $UPDATE_DIR/$COUNTRY_/state.txt
            echo "timestamp=$REPL_TS" >> $UPDATE_DIR/$COUNTRY_/state.txt
        fi
    done
done

chown -R postgres:postgres $UPDATE_DIR

#Merge pbf if we have more than one pbf file or rename single country file to merged.osm.pbf
if [ `ls -1 $DATA_DIR/*$COUNTRY_POSTFIX |wc -l` -gt 1 ]; then
    echo "Merge pbf files"
    osmium merge -v --progress $DATA_DIR/*$COUNTRY_POSTFIX -o $DATA_DIR/merged.osm.pbf
    echo "Remove countries pbf"
    rm -f $DATA_DIR/*$COUNTRY_POSTFIX
else
    echo "Rename single country filename to merged.osm.pbf"
    mv $DATA_DIR/*$COUNTRY_POSTFIX $DATA_DIR/merged.osm.pbf
fi

#Init postgres database and populate database
mkdir -p $PG_DATA
chown postgres:postgres $PG_DATA

sudo -u postgres /usr/lib/postgresql/11/bin/initdb -D $PG_DATA && \
sudo -u postgres /usr/lib/postgresql/11/bin/pg_ctl -D $PG_DATA -o "--config_file=$PG_CONF" start && \
sudo -u postgres createuser -s nominatim && \
sudo -u postgres createuser -SDR www-data && \
useradd -r nominatim
chown -R nominatim:nominatim ./src && \
sudo -u nominatim ./src/build/utils/setup.php --osm-file $DATA_DIR/merged.osm.pbf --all --threads $NOMINATIM_INIT_THREADS &&\
sleep 10 && \
sudo -u postgres /usr/lib/postgresql/11/bin/pg_ctl -D $PG_DATA -o "--config_file=$PG_CONF" stop

#Set countries for update
sed "s|^COUNTRIES=.*|COUNTRIES=\"$NOMINATIM_COUNTRIES\"|g" /app/update.sh > $DATA_DIR/update.sh