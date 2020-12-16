#!/bin/bash

###########################
#### BACLUP CONFIG     ####
###########################

FIN_VERSION=0.0.1
PROJECR_NAME=dev-database
WORK_DIR=/tmp
FILENAME=${1:-2020-12-15-domain-ds-postgres}
USERNAME=postgres
DBNAME=postgres
CONTAINER_NAME=postgres

POD_NAME=${2:-domain-ds}
DSPOD_INSTANCE_NAME=$(oc get pods \
	-l "name=$POD_NAME" \
	--template "{{ with index .items ${POD_INDEX:-0} }}{{ .metadata.name }}{{ end }}")
echo $DSPOD_INSTANCE_NAME
###########################
#### SEND RESTROE DB   ####
###########################

if [ ! -f "$FILENAME" ]; then
    echo "$FILENAME does not exist."
    exit 1
fi

###########################
#### SEND RESTROE DB   ####
###########################

#docker cp $FILENAME $CONTAINER_NAME:/tmp
oc cp $FILENAME $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR DB COPY FAIL"
	exit 1
fi

###########################
#### RUN DB RESTIRE    ####
###########################

#docker exec -t $CONTAINER_NAME pg_restore -U $USERNAME -d $DBNAME -c /tmp/$FILENAME 
echo "RESTORE POSTGRESQL DB"
oc exec "$DSPOD_INSTANCE_NAME" -t -- bash -c "pg_restore -U postgres -d postgres -c $WORK_DIR/$FILENAME"
STATUS=$?
if [ $STATUS -eq 1 ]; then
	echo "Sorry, $PROJECR_NAME/$DSPOD_INSTANCE_NAME:$WORK_DIR DB RESTORE FAIL"
	exit 1
fi

echo -e "postgresql restore end!"
