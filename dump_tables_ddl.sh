#!/bin/sh
SCRIPT_DIR=/usr/local/scripts/mysql_scripts
source $SCRIPT_DIR/vars.sh

SCHEMA_NAME=$1

while read line
do
    mysql --host=${HOST_NAME} --user=${USER_NAME} --password=${PASSWD} -N -e "show create table $line"
done < $SCHEMA_NAME\_tables.lst
