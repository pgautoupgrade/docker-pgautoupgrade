#!/usr/bin/env bash

# If the user gives a first argument of "down", then shut down
# any running containers from previous test runs
if [ "$1" = "down" ]; then
    docker-compose -f test/docker-compose-pgauto.yml down
    exit 0
fi

# Change into the test directory
cd test

# Delete any existing PostgreSQL data
if [ -d pgstuff/postgres-data ]; then
	echo "Removing old PostgreSQL data from test directory"
	sudo rm -rf pgstuff/postgres-data
fi

# Create the PostgreSQL database using PG 9.5
docker-compose -f docker-compose-pg9.5.yml run --rm server create_db

# Start Redash normally, using the "autoupdate" version of PostgreSQL
docker-compose -f docker-compose-pgauto.yml up -d

# Verify the PostgreSQL data files are now version 15
PGVER=$(sudo cat pgstuff/postgres-data/PG_VERSION)
if [ "$PGVER" != "15" ]; then
    echo "Automatic upgrade of PostgreSQL database files FAILED!"
else
    echo "Automatic upgrade of PostgreSQL database files SUCCEEDED!"
fi

echo "Redash should now be available at http://localhost:5000"
