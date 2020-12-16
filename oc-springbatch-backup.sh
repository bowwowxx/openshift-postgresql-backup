#!/bin/bash

###########################
#### BACLUP CONFIG     ####
###########################
#domain-ds spring-batch-ds 
FIN_VERSION=0.0.1
PROJECR_NAME=database
WORK_DIR=/tmp
DB_FOLDER=db
PG_SHELL=pg-backup.sh

BACKUP_FILENAME="$(date +\%Y-\%m-\%d)"
POD_NAME=${1:-spring-batch-ds}
NFS_FOLDER=${2:-db3}

###########################
#### SETTING PROJECT   ####
###########################
echo "1.GET OC PROJECT"
oc project $PROJECR_NAME
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, $PROJECR_NAME ERROR"
	exit 1
fi

###########################
#### GET POD INFO      ####
###########################
DSPOD_INSTANCE_NAME=$(oc get pods \
	-l "name=$POD_NAME" \
	--template "{{ with index .items ${POD_INDEX:-0} }}{{ .metadata.name }}{{ end }}")	
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, $DSPOD_INSTANCE_NAME ERROR"
	exit 1
fi


###########################
#### SEND BACKUP SHELL ####
###########################
echo "2.SEND BASH TO PROJECT"
oc cp pg-backup.sh $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR DB BACKUP FAIL"
	exit 1
fi

###########################
#### RUN DB BACKUP     ####
###########################
echo "3.RUN BACKUP POSTGRESQL DB"
oc exec "$DSPOD_INSTANCE_NAME" -it -- bash -c "$WORK_DIR/$PG_SHELL $POD_NAME $WORK_DIR"
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR DB BACKUP FAIL"
	exit 1
fi

###########################
#### COPY FILES        ####
###########################
echo "4.COPY BACKUP FILE"
oc cp $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR/$DB_FOLDER $DB_FOLDER
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, OC COPY $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR/$WORK_DIR  ERROR"
	exit 1
fi


###########################
####   CHECKSUM        ####
###########################
echo "5.CHECKSUM FILE"
for ENTRY in "$DB_FOLDER"/*.checksum; do
	CHECK_SUM=$(md5sum -c $ENTRY | awk '{print $2}')
	if [ "OK" == $CHECK_SUM ]; then
		echo "$ENTRY CHECKSUM OK"
	else
		echo "Sorry, $ENTRY FILE CHECKSUM ERROR"
		exit 1
	fi
done

###########################
####  MOVE FILE TO NFS ####
###########################
echo "6.MOVE FILE TO $NFS_FOLDER"
[ -d $NFS_FOLDER ] || mkdir -p $NFS_FOLDER
mv -f $DB_FOLDER/* "$NFS_FOLDER"
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR/$DB_FOLDER MOVE TO NFS FAIL"
	exit 1
fi

###########################
#### REMOVE FILES      ####
###########################
echo "7.CLEAR TEMP FILE"
oc exec "$DSPOD_INSTANCE_NAME" -it -- bash -c "rm -rf $WORK_DIR/$DB_FOLDER $WORK_DIR/$PG_SHELL"
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR/$DB_FOLDER REMOVE FAIL"
	exit 1
fi


echo -e "backup end!"
