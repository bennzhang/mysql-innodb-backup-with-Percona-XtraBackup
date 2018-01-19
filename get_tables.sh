#!/bin/sh
SCRIPT_DIR=/usr/local/scripts/mysql_scripts
source $SCRIPT_DIR/vars.sh

SCHEMA_NAME=$1

mysql -h $HOST_NAME -u $USER_NAME -p$PASSWD -N -e "SELECT CONCAT(TABLE_SCHEMA,'.',TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${SCHEMA_NAME}'" > $SCHEMA_NAME\_tables.lst
