#!/bin/sh
SCHEMA_NAME=$1

echo "USE $SCHEMA_NAME;"
while read line
do
   echo "ALTER TABLE $line IMPORT TABLESPACE;"
done < $SCHEMA_NAME\_tables.lst
