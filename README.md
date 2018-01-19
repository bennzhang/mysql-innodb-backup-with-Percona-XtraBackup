# Percona XtraBackup innodb backup and restores file copy 
This document shows how to use `Percona XtraBackup` to backup and recover the mysql innodb tables using file copy ways for MySQL 5.6 above. You can download and install `Percona XtraBackup` from [here](https://www.percona.com/downloads/XtraBackup/LATEST/). 

```
yum install https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.4.9/binary/redhat/7/x86_64/percona-xtrabackup-24-2.4.9-1.el7.x86_64.rpm
```

```
$ xtrabackup --version
xtrabackup version 2.4.9 based on MySQL server 5.7.13 Linux (x86_64) (revision id: a467167cdd4)
```

## 2 Backup database

### 2.1 get schema table list

Run `get_tables.sh` below to get all tables from one schema and save into a file `${TABLE_SCHEMA}_tables.lst`.  You need to pass in the schema name use `$1`.  for example `./get_tables.sh test` will get all tables from schema `test`. 

```
#!/bin/sh

SCRIPT_DIR=/usr/local/scripts/mysql_scripts
source $SCRIPT_DIR/vars.sh

SCHEMA_NAME=$1

mysql --host=${HOST_NAME} --user=${USER_NAME} --password=${PASSWD} -N -e "SELECT CONCAT(TABLE_SCHEMA,'.',TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${SCHEMA_NAME}'" > $SCHEMA_NAME\_tables.lst
```

`-N` : ignore column header. 


### 2.2 --backup 

All `Xtrabackup` backup options can be found [here](https://www.percona.com/doc/percona-xtrabackup/LATEST/xtrabackup_bin/xbk_option_reference.html)
```
sudo /usr/bin/xtrabackup --user=${USER_NAME} --password=${PASSWD} --tables-file=${TABLES_LIST_FILE} --backup --parallel=4 --target-dir=${BACKUP_DIR} --DATA_DIR=${DATA_DIR}
```

### 2.3 --prepare --export

+ --prepare
You need to prepare backup in order to restore it. Data files are not point-in-time consistent until they’ve been prepared, because they were copied at different times as the program ran, and they might have been changed while this was happening. If you try to start InnoDB with these data files, it will detect corruption and crash itself to prevent you from running on damaged data. The xtrabackup --prepare step makes the files perfectly consistent at a single instant in time, so you can run InnoDB on them [Reference](https://www.percona.com/doc/percona-xtrabackup/LATEST/backup_scenarios/full_backup.html#preparing-a-backup).  You can run the prepare operation on any machine; it does not need to be on the originating server or the server to which you intend to restore. 

+ --export 
This command makes it possible to copy table files for backups. It creates files necessary for exporting tables. See [Restoring Individual Tables](https://www.percona.com/doc/percona-xtrabackup/LATEST/xtrabackup_bin/restoring_individual_tables.html).  This command is combined with `--prepare`

```
sudo /usr/bin/xtrabackup --prepare --export --target-dir=${BACKUP_DIR}
```

After run it, you will see some files for each table like below. These files are all you need to import the table into a server running Percona Server with XtraDB or MySQL 5.7

```
$ find ${BACKUP_DIR}/${SCHEMA_NAME} 

${BACKUP_DIR}/${SCHEMA_NAME}/table1.cfg
${BACKUP_DIR}/${SCHEMA_NAME}/table1.exp
${BACKUP_DIR}/${SCHEMA_NAME}/table1.ibd
${BACKUP_DIR}/${SCHEMA_NAME}/table1.frm
```

One script `backup.sh` is provided. This script needds pass in one parameter - SCHEMA_NAME. For example, `backup.sh test` will backup whole innodb tables of `test` database. 

## 3 Restore databse

### 3.1 drop/recreate tables 

+ Get whole DDLs

You can get whole DDLs from this command. 
```
 mysqldump -d -u ${USER_NAME} -p${PASSWD} ${SCHEMA_NAME} > ${SCHEMA_NAME}\_DDL.sql
```

+ Drop and recreate tables 
```
mysql --host=${HOST_NAME} --user=${USER_NAME} --password=${PASSWD} < ${SCHEMA_NAME}\_DDL.sql
```

### 3.2 Discard Tablespaces

Use this script to generate discard tablespace sql file `./create_discard_tablespace_sql.sh SCHEMA_NAME` and save into a file `$SCHEMA_NAME\_discard_tablespace.sql`

```
#!/bin/sh
SCHEMA_NAME=$1

echo "USE $SCHEMA_NAME;"
while read line
do
   echo "ALTER TABLE $line DISCARD TABLESPACE;"
done < $SCHEMA_NAME\_tables.lst
```

run discard tablespace sql. 

```
mysql --host=${HOST_NAME} --user=${USER_NAME} --password=${PASSWD} < ${SCHEMA_NAME}\_discard_tablespace.sql
```

### 3.3 Copy backed up files from BACKUP_DIR to DATA_DIR
You just needs to copy `*.cfg` and `*ibd` files.  `mv_back_backups.sh`

```
#!/bin/sh
SCRIPT_DIR=/usr/local/scripts/mysql_scripts
source $SCRIPT_DIR/vars.sh

SCHEMA_NAME=$1

while read line
do
   sudo cp -rpv ${BACKUP_DIR}/${SCHEMA_NAME}/*.cfg ${DATA_DIR}/${SCHEMA_NAME}
   sudo cp -rpv ${BACKUP_DIR}/${SCHEMA_NAME}/*.ibd ${DATA_DIR}/${SCHEMA_NAME}
done < $SCHEMA_NAME\_tables.lst

sudo chown -R mysql:mysql ${DATA_DIR}
```

### 3.4 Import tablesapce 

Use this script to generate import tablespace sql file `./create_import_tablespace_sql.sh SCHEMA_NAME` and save into a file `$SCHEMA_NAME\_import_tablespace.sql`

```
#!/bin/sh
SCHEMA_NAME=$1

echo "USE $SCHEMA_NAME;"
while read line
do
   echo "ALTER TABLE $line IMPORT TABLESPACE;"
done < $SCHEMA_NAME\_tables.lst
```

run import discard tablespace sql. 

```
mysql --host=${HOST_NAME} --user=${USER_NAME} --password=${PASSWD} < ${SCHEMA_NAME}\_import_tablespace.sql
```

### 3.5 Cleanup after import 

```
rm ${DATA_DIR}/${SCHEMA_NAME}/*.cfg
```

### 3.6 Put them together 
```
$ cat restore_backup.sh

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
```

## 4 whole picture
```
$ tree .
.
├── create_discard_tablespace_sql.sh
├── create_import_tablespace_sql.sh
├── dump_tables_ddl.sh
├── export_backup.sh
├── get_tables.sh
├── mv_back_backups.sh
├── restore_backup.sh
├── test_DDL.sql
├── test_discard_tablespace.sql
├── test_import_tablespace.sql
├── test_tables.lst
└── vars.sh
```

`vars.sh` is your configuration files.  `export_backup.sh` is main script to backup and `restore_backup.sh` is main script to restore. 

