#!/bin/sh

SCRIPT_DIR=/usr/local/scripts/mysql_scripts
source $SCRIPT_DIR/vars.sh

SCHEMA_NAME=$1
TABLES_LIST_FILE=$SCRIPT_DIR/$SCHEMA_NAME\_tables.lst

echo "--backup"
sudo /usr/bin/xtrabackup --user=${USER_NAME} --password=${PASSWD} --tables-file=${TABLES_LIST_FILE} --backup --parallel=4 --target-dir=${BACKUP_DIR} --datadir=${DATA_DIR}

echo "--prepare --export"
sudo /usr/bin/xtrabackup --prepare --export --target-dir=${BACKUP_DIR}

