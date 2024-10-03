#!/usr/bin/env bash
set -eux

FAILURE=0

# Array of PostgreSQL versions for testing
PG_VERSIONS=(9.5 9.6 10 11 12 13 14 15 16 17)

# Useful output display
banner() {
    set +x
    CHAR=$1
    MSG=$2
    NUMSTARS=$((${#MSG}+1))
    echo
    for i in $(seq 2 "$NUMSTARS"); do printf "%s" "${CHAR}"; done; echo
    echo "${MSG}"
    for i in $(seq 2 "$NUMSTARS"); do printf "%s" "${CHAR}"; done; echo
    echo
    set -x
}

# Stop any existing containers from previous test runs
test_down() {
    docker compose -f test/docker-compose-pgauto.yml down
}

test_run() {
    VERSION=$1
    TARGET=$2
    FLAVOR=$3

    # Delete any existing test PostgreSQL data
    if [ -d postgres-data ]; then
        echo "Removing old PostgreSQL data from test directory"
        sudo rm -rf postgres-data
    fi

    # Create the PostgreSQL database using a specific version of PostgreSQL
    docker compose -f "docker-compose-pg${VERSION}.yml" run --rm server create_db

    # Start Redash normally, using an "autoupdate" version of PostgreSQL
    TARGET_TAG="${TARGET}-${FLAVOR}" docker compose -f docker-compose-pgauto.yml up --wait -d

    # Verify the PostgreSQL data files are now the target version
    PGVER=$(sudo cat postgres-data/PG_VERSION)
    if [ "$PGVER" != "${TARGET}" ]; then
        banner '*' "Standard automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} FAILED!"
        FAILURE=1
    else
        banner '*' "Standard automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} SUCCEEDED!"
    fi

    # Shut down any containers that are still running
    docker compose -f docker-compose-pgauto.yml down --remove-orphans

    # Delete the upgraded PostgreSQL data directory
    sudo rm -rf postgres-data

    ##
    ## Tests for one shot mode
    ##
    banner '-' "Testing 'one shot' automatic upgrade mode for PostgreSQL ${VERSION} to ${TARGET}"

    # Create the PostgreSQL database using a specific version of PostgreSQL
    docker compose -f "docker-compose-pg${VERSION}.yml" run --rm server create_db

    # Shut down all of the containers
    docker compose -f "docker-compose-pg${VERSION}.yml" down --remove-orphans

    # Run the PostgreSQL container in one shot mode
    TARGET_TAG="${TARGET}-${FLAVOR}" docker compose -f docker-compose-pgauto.yml run --rm -e PGAUTO_ONESHOT=yes postgres

    # Verify the PostgreSQL data files are now the target version
    PGVER=$(sudo cat postgres-data/PG_VERSION)
    if [ "$PGVER" != "${TARGET}" ]; then
        banner '*' "'One shot' automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} FAILED!"
        FAILURE=1
    else
        banner '*' "'One shot' automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} SUCCEEDED!"
    fi

    # Shut down any containers that are still running
    docker compose -f docker-compose-pgauto.yml down

    # If running on CI, delete the Postgres Docker image to avoid space problems
    if [ -n "$CI" ]; then
        docker rmi -f $(docker images postgres -q)
    fi
}

# Shut down containers from previous test runs
test_down

# If the user gives a first argument of "down", then we exit
# after shutting down any running containers from previous test runs
arg="${1:-}"
if [ "$arg" = "down" ]; then
    exit 0
fi

# Change into the test directory
cd test || exit 1

for version in "${PG_VERSIONS[@]}"; do
    # Only test if the version is less than the latest version
    if [[ $(echo "$version < $PGTARGET" | bc) -eq 1 ]]; then
        test_run "$version" "$PGTARGET" "$OS_FLAVOR"
    fi
done

# Check for failure
if [ "${FAILURE}" -ne 0 ]; then
    banner ' ' "FAILURE: Automatic upgrade of PostgreSQL failed in one of the tests. Please investigate."
    exit 1
else
    banner ' ' "SUCCESS: Automatic upgrade testing of PostgreSQL to all versions up to $PGTARGET passed without issue."
fi
