#!/usr/bin/env bash

FAILURE=0

# Stop any existing containers from previous test runs
test_down() {
    docker-compose -f test/docker-compose-pgauto.yml down
}

test_run() {
    VERSION=$1
    TARGET=$2

    # Delete any existing test PostgreSQL data
    if [ -d postgres-data ]; then
        echo "Removing old PostgreSQL data from test directory"
        sudo rm -rf postgres-data
    fi

    # Create the PostgreSQL database using a specific version of PostgreSQL
    docker-compose -f "docker-compose-pg${VERSION}.yml" run --rm server create_db

    # Start Redash normally, using an "autoupdate" version of PostgreSQL
    if [ "${TARGET}" = "16" ]; then
      docker-compose -f docker-compose-pgauto.yml up -d
    elif [ "${TARGET}" = "15" ]; then
      TARGET_TAG=15-dev docker-compose -f docker-compose-pgauto.yml up -d
    elif [ "${TARGET}" = "14" ]; then
      TARGET_TAG=14-dev docker-compose -f docker-compose-pgauto.yml up -d
    elif [ "${TARGET}" = "13" ]; then
      TARGET_TAG=13-dev docker-compose -f docker-compose-pgauto.yml up -d
    fi

    # Verify the PostgreSQL data files are now the target version
    PGVER=$(sudo cat postgres-data/PG_VERSION)
    if [ "$PGVER" != "${TARGET}" ]; then
        echo
        echo "****************************************************************************"
        echo "Automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} FAILED!"
        echo "****************************************************************************"
        echo
        FAILURE=1
    else
        echo
        echo "*******************************************************************************"
        echo "Automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} SUCCEEDED!"
        echo "*******************************************************************************"
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
cd test || exit 1

# Testing upgrading from each major PG version directly to PG 13
test_run 9.5 13
test_run 9.6 13
test_run 10 13
test_run 11 13
test_run 12 13

# Testing upgrading from each major PG version directly to PG 14
test_run 9.5 14
test_run 9.6 14
test_run 10 14
test_run 11 14
test_run 12 14
test_run 13 14

# Testing upgrading from each major PG version directly to PG 15
test_run 9.5 15
test_run 9.6 15
test_run 10 15
test_run 11 15
test_run 12 15
test_run 13 15
test_run 14 15

# Testing upgrading from each major PG version directly to PG 16
test_run 9.5 16
test_run 9.6 16
test_run 10 16
test_run 11 16
test_run 12 16
test_run 13 16
test_run 14 16
test_run 15 16

if [ "${FAILURE}" -ne 0 ]; then
	echo
	echo "FAILURE: Automatic upgrade of PostgreSQL failed in one of the tests.  Please investigate."
	echo
	exit 1
else
	echo
	echo "SUCCESS: Automatic upgrade testing of PostgreSQL to PG 13, 14, 15, and 16 passed without issue."
	echo
fi
