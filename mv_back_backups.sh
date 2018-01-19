#!/bin/sh

SCRIPT_DIR=/usr/local/scripts/mysql_scripts
source $SCRIPT_DIR/vars.sh

SCHEMA_NAME=$1

while read line
do
   cp -rpv ${BACKUP_DIR}/${SCHEMA_NAME}/*.cfg ${DATA_DIR}/${SCHEMA_NAME}/
   cp -rpv ${BACKUP_DIR}/${SCHEMA_NAME}/*.ibd ${DATA_DIR}/${SCHEMA_NAME}/
done < $SCHEMA_NAME\_tables.lst
