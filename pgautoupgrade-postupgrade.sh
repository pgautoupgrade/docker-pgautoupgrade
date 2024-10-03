#!/usr/bin/env bash

set -e

if [ $# -ne 2 ]; then
	echo "Required number of arguments not passed to post upgrade script.  2 expected, $# received"
	exit 1
fi

PGDATA=$1
PGAUTO_ONESHOT=$2

# Wait for PostgreSQL to start and become available
COUNT=0
RUNNING=1
while [ $RUNNING -ne 0 ] && [ $COUNT -le 20 ]; do
	# Check if PostgreSQL is running yet
	echo "------ Checking if PostgreSQL is running, loop count ${COUNT} ------"
	set +e
	pg_isready -q
	RUNNING=$?
	set -e

	if [ $RUNNING -eq 0 ]; then
		echo "PostgreSQL is running.  Post upgrade tasks will start shortly"
	else
		echo "PostgreSQL is not yet running, lets wait then try again..."
		sleep 3
	fi

	COUNT=$((COUNT+1))
done

if [ $RUNNING -ne 0 ]; then
	echo "PostgreSQL did not start before timeout expired"
	exit 2
fi

# Get the list of databases in the database cluster
DB_LIST=$(echo 'SELECT datname FROM pg_catalog.pg_database WHERE datistemplate IS FALSE' | psql -1t --csv postgres)

# Update query planner statistics
echo "----------------------------"
echo "Updating query planner stats"
echo "----------------------------"

for DATABASE in ${DB_LIST}; do
	echo "VACUUM (ANALYZE, VERBOSE, INDEX_CLEANUP FALSE)" | psql -t --csv "${DATABASE}"
done

echo "-------------------------------------"
echo "Finished updating query planner stats"
echo "-------------------------------------"

# Reindex the databases
echo "------------------------"
echo "Reindexing the databases"
echo "------------------------"

# For each database, reindex it
for DATABASE in ${DB_LIST}; do
	echo "-------------------------------"
	echo "Starting reindex of ${DATABASE}"
	echo "-------------------------------"

	echo 'REINDEX DATABASE CONCURRENTLY' | psql -t --csv "${DATABASE}"

	echo "-------------------------------"
	echo "Finished reindex of ${DATABASE}"
	echo "-------------------------------"
done

echo "-------------------------------"
echo "End of reindexing the databases"
echo "-------------------------------"

# If "one shot" mode was requested, then shut down PostgreSQL
if [ "x${PGAUTO_ONESHOT}" = "xyes" ]; then
	echo "****************************************************************************************************"
	echo "'One shot' automatic upgrade was requested, so exiting now that the post upgrade tasks have finished"
	echo "****************************************************************************************************"
	pg_ctl stop -D "${PGDATA}"
else
	echo "*************************************************************************************************"
	echo "Post upgrade tasks have finished successfully.  PostgreSQL should now be fully updated and online"
	echo "*************************************************************************************************"
fi

# Run a sync before exiting, just to ensure everything is flushed to disk before docker terminates the process
sync