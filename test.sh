#!/usr/bin/env bash

# Stop any existing containers from previous test runs
test_down() {
    docker-compose -f test/docker-compose-pgauto.yml down
}

test_run() {
    V=$1

    # Delete any existing test PostgreSQL data
    if [ -d postgres-data ]; then
        echo "Removing old PostgreSQL data from test directory"
        sudo rm -rf postgres-data
    fi

    # Create the PostgreSQL database using PG 9.5
    docker-compose -f docker-compose-pg${V}.yml run --rm server create_db

    # Start Redash normally, using the "autoupdate" version of PostgreSQL
    docker-compose -f docker-compose-pgauto.yml up -d

    # Verify the PostgreSQL data files are now version 15
    PGVER=$(sudo cat postgres-data/PG_VERSION)
    if [ "$PGVER" != "15" ]; then
        echo
        echo "***************************************************************"
        echo "Automatic upgrade of PostgreSQL from version ${V} to 15 FAILED!"
        echo "***************************************************************"
        echo
    else
        echo
        echo "******************************************************************"
        echo "Automatic upgrade of PostgreSQL from version ${V} to 15 SUCCEEDED!"
        echo "******************************************************************"
        echo
    fi

    # Shut down containers from previous test runs
    docker-compose -f docker-compose-pgauto.yml down
}

# Shut down containers from previous test runs
test_down

# If the user gives a first argument of "down", then we exit
# after shutting down any running containers from previous test runs
if [ "$1" = "down" ]; then
    exit 0
fi

# Change into the test directory
cd test

# Testing upgrading from each major PG version directly to PG 15
test_run 9.5
test_run 9.6
test_run 10
test_run 11
test_run 12
test_run 13
test_run 14
