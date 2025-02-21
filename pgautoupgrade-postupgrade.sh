#!/usr/bin/env bash

set -e

if [ $# -ne 3 ]; then
	echo "Required number of arguments not passed to post upgrade script.  3 expected, $# received"
	exit 1
fi

PGDATA=$1
POSTGRES_DB=$2
PGAUTO_ONESHOT=$3

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
DB_LIST=$(echo 'SELECT datname FROM pg_catalog.pg_database WHERE datistemplate IS FALSE' | psql --username="${POSTGRES_USER}" -1t --csv "${POSTGRES_DB}")

# Update query planner statistics
echo "----------------------------"
echo "Updating query planner stats"
echo "----------------------------"

for DATABASE in ${DB_LIST}; do
	echo "VACUUM (ANALYZE, VERBOSE, INDEX_CLEANUP FALSE)" | psql --username="${POSTGRES_USER}" -t --csv "${DATABASE}"
done

echo "-------------------------------------"
echo "Finished updating query planner stats"
echo "-------------------------------------"

if [ "x${PGAUTO_REINDEX}" != "xno" ]; then
        # Reindex the databases
        echo "------------------------"
        echo "Reindexing the databases"
        echo "------------------------"

		if [[ "$PGTARGET" -le 15 ]]; then
			reindexdb --all --username="${POSTGRES_USER}"
		else
			reindexdb --all --concurrently --username="${POSTGRES_USER}"
		fi
        
        echo "-------------------------------"
        echo "End of reindexing the databases"
        echo "-------------------------------"
fi

# Update the extensions
echo "-----------------------"
echo "Updating the extensions"
echo "-----------------------"

# For each database, update its extensions
for DATABASE in ${DB_LIST}; do
	echo "-----------------------------------------"
	echo "Starting extension update for ${DATABASE}"
	echo "-----------------------------------------"

	EXTENSION_LIST=$(echo 'SELECT name FROM pg_catalog.pg_available_extensions WHERE default_version <> installed_version' | psql -t --csv "${DATABASE}")

	for EXTENSION in ${EXTENSION_LIST}; do
		echo "-------------------------------"
		echo "Updating extension ${EXTENSION}"
		echo "-------------------------------"

		echo 'ALTER EXTENSION foobar UPDATE' | psql -t --csv "${DATABASE}"

		echo "----------------------------------------"
		echo "Finished updating extension ${EXTENSION}"
		echo "----------------------------------------"
	done

	echo "-----------------------------------------"
	echo "Finished extension update for ${DATABASE}"
	echo "-----------------------------------------"
done

echo "--------------------------------"
echo "Finished updating the extensions"
echo "--------------------------------"

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
