#!/bin/bash

###########################
#### BACLUP CONFIG     ####
###########################
BACKUP_USER=postgres
HOSTNAME=localhost
USERNAME=postgres
ENABLE_CUSTOM_BACKUPS=yes
ENABLE_SQL_BACKUPS=no

POD_NAME=${1:-dev-aors-domain-ds}
WORK_DIR=${2:-/tmp}
BACKUP_FILENAME=${3:-$(date +\%Y-\%m-\%d)}
DB_FOLDER=${4:-db}
DUMP_DIR=$WORK_DIR/$DB_FOLDER

# Number of days to keep daily backups
DAYS_TO_KEEP=1

###########################
#### PRE-BACKUP CHECKS ####
###########################

# Make sure we're running as the required backup user
if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ]; then
	echo "This script must be run as $BACKUP_USER. Exiting." 1>&2
	exit 1
fi

###########################
### INITIALISE DEFAULTS ###
###########################

if [ ! $HOSTNAME ]; then
	HOSTNAME="localhost"
fi

if [ ! $USERNAME ]; then
	USERNAME="postgres"
fi

###########################
#### START THE BACKUPS ####
###########################

# echo "Making backup directory in $FINAL_WORK_DIR"
if ! mkdir -p $WORK_DIR/$DB_FOLDER; then
	echo "Cannot create backup directory in $WORK_DIR. Go and fix it!" 1>&2
	exit 1
fi

###########################
#### PGISREADY         ####
###########################

if ! pg_isready -h "$HOSTNAME" -U "$USERNAME" ; then
	echo "PG CONNECT ERROR" 1>&2
	exit 1
fi

###########################
###### ALLDB BACKUPS ######
###########################

FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn order by datname;"

echo -e "\n\nPerforming full backups"
echo -e "--------------------------------------------\n"

for DATABASE in $(psql -h "$HOSTNAME" -U "$USERNAME" -At -c "$FULL_BACKUP_QUERY" postgres); do
	if [ $ENABLE_SQL_BACKUPS = "yes" ]; then
		echo "Plain backup of $DATABASE"

		set -o pipefail
		if ! pg_dump -Fp -h "$HOSTNAME" -U "$USERNAME" "$DATABASE" | gzip >$WORK_DIR"/$BACKUP_FILENAME-$DATABASE".sql.gz.in_progress; then
			echo "[!!ERROR!!] Failed to produce plain backup database $DATABASE" 1>&2
			exit 1
		else
			mv $WORK_DIR"/$BACKUP_FILENAME-$DATABASE".sql.gz.in_progress $DUMP_DIR"/$BACKUP_FILENAME-$POD_NAME-$DATABASE".sql.gz
		    CHECKPATH=$DB_FOLDER/$BACKUP_FILENAME-$POD_NAME-$DATABASE.sql.gz
			echo $(md5sum $WORK_DIR/"$DB_FOLDER/$BACKUP_FILENAME-$POD_NAME-$DATABASE".sql.gz | awk '{ print $1, "'"$CHECKPATH"'"}') > $WORK_DIR/$DB_FOLDER"/$BACKUP_FILENAME-$POD_NAME-$DATABASE".sql.gz.checksum
		fi
		set +o pipefail
	fi

	if [ $ENABLE_CUSTOM_BACKUPS = "yes" ]; then
		echo "Custom backup of $DATABASE"

		if ! pg_dump -Fc -h "$HOSTNAME" -U "$USERNAME" "$DATABASE" -f $WORK_DIR"/$BACKUP_FILENAME-$DATABASE".in_progress; then
			echo "[!!ERROR!!] Failed to produce backup database $DATABASE" 1>&2
			exit 1
		else
			mv $WORK_DIR"/$BACKUP_FILENAME-$DATABASE".in_progress $DUMP_DIR"/$BACKUP_FILENAME-$POD_NAME-$DATABASE"
			CHECKPATH=$DB_FOLDER/$BACKUP_FILENAME-$POD_NAME-$DATABASE
			echo $(md5sum $WORK_DIR/"$DB_FOLDER/$BACKUP_FILENAME-$POD_NAME-$DATABASE" | awk '{ print $1, "'"$CHECKPATH"'"}') > $WORK_DIR/"$DB_FOLDER/$BACKUP_FILENAME-$POD_NAME-$DATABASE".checksum
		fi
	fi
done

# Delete daily backups $keepdays old or more
find $WORK_DIR/$DB_FOLDER -type f -prune -mtime +$DAYS_TO_KEEP -exec rm -f {} \;

echo -e "database backups end!"
