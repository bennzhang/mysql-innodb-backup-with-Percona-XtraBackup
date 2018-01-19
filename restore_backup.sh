#!/bin/sh

SCRIPT_DIR=/usr/local/scripts/mysql_scripts
source $SCRIPT_DIR/vars.sh

SCHEMA_NAME=$1
TABLES_LIST_FILE=$SCRIPT_DIR/$SCHEMA_NAME\_tables.lst

echo "dump original DDL ......"
mysqldump -d -u ${USER_NAME} -p${PASSWD} ${SCHEMA_NAME} > ${SCHEMA_NAME}\_DDL.sql

echo "drop/recreate tables ......"
mysql --host=${HOST_NAME} --user=${USER_NAME} --password=${PASSWD} < ${SCHEMA_NAME}\_DDL.sql

echo "discard tablespaces ......"
echo "  + create discard tablespaces sql"
$SCRIPT_DIR/create_discard_tablespace_sql.sh ${SCHEMA_NAME} > $SCHEMA_NAME\_discard_tablespace.sql
echo "  + run discard tablespaces sql"
mysql --host=${HOST_NAME} --user=${USER_NAME} --password=${PASSWD} < ${SCHEMA_NAME}\_discard_tablespace.sql

echo "copy backed up files from ${BACKUP_DIR} to ${DATA_DIR}
$SCRIPT_DIR/mv_back_backups.sh ${SCHEMA_NAME}

echo "import tablespaces ......"
echo "  + create import tablespaces sql"
$SCRIPT_DIR/create_import_tablespace_sql.sh ${SCHEMA_NAME} > $SCHEMA_NAME\_import_tablespace.sql
echo "  + run import tablespaces sql"
mysql --host=${HOST_NAME} --user=${USER_NAME} --password=${PASSWD} < ${SCHEMA_NAME}\_import_tablespace.sql

echo "clean up cfg files"
sudo rm ${DATA_DIR}/${SCHEMA_NAME}/*.cfg

echo "Restore Complete!!!!"
