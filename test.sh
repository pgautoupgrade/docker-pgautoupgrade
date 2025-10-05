#!/usr/bin/env bash
set -ex

FAILURE=0

# Array of PostgreSQL versions for testing
PG_VERSIONS=(9.5 9.6 10 11 12 13 14 15 16 17 18)

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

import_adventure_works() {
    # Create the PostgreSQL database using a specific version of PostgreSQL
    docker compose -f "docker-compose-pg${VERSION}.yml" up -d --wait

    # Create a database and import AdventureWorks
    docker compose -f "docker-compose-pg${VERSION}.yml" exec postgres createdb -U postgres AdventureWorks
    cat AdventureWorks.sql | docker compose -f "docker-compose-pg${VERSION}.yml" exec --no-TTY postgres psql -U postgres -d AdventureWorks > /dev/null 2>&1

    # Shutdown the existing version
    docker compose -f "docker-compose-pg${VERSION}.yml" down -v
}

test_run() {
    VERSION=$1
    TARGET=$2
    FLAVOR=$3

    local TARGET_MAJOR=${PGTARGET%%.*}
    if [ "$TARGET_MAJOR" -eq 18 ]; then
        PGAUTO_COMPOSE="docker-compose-pgauto18.yml"
        PGTARGET_COMPOSE="docker-compose-pgtarget18.yml"
        PGVERSION_FILE="postgres-data/18/docker/PG_VERSION"
    else
        PGAUTO_COMPOSE="docker-compose-pgauto.yml"
        PGTARGET_COMPOSE="docker-compose-pgtarget.yml"
        PGVERSION_FILE="postgres-data/PG_VERSION"
    fi

    # Delete any existing test PostgreSQL data
    if [ -d postgres-data ]; then
        echo "Removing old PostgreSQL data from test directory"
        sudo rm -rf postgres-data
    fi

    export TARGET_TAG="${TARGET}-${FLAVOR}"

    # Start an empty pgautoupgrade container to make sure this is possible as well
    docker compose -f $PGAUTO_COMPOSE up --wait -d

    # Shut down any containers that are still running
    docker compose -f $PGAUTO_COMPOSE down --remove-orphans

    # Delete the upgraded PostgreSQL data directory
    sudo rm -rf postgres-data

    import_adventure_works

    # Start pgautoupgrade container
    docker compose -f $PGAUTO_COMPOSE up --wait -d

    # Verify the PostgreSQL data files are now the target version
    PGVER=$(sudo cat $PGVERSION_FILE)
    if [ "$PGVER" != "${TARGET%%.*}" ]; then
        banner '*' "Standard automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} FAILED!"
        FAILURE=1
    else
        banner '*' "Standard automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} SUCCEEDED!"
    fi

    if ! docker compose -f $PGAUTO_COMPOSE exec postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='AdventureWorks'" | grep -q 1; then
        banner "Adventure works database does not exist in new PostgreSQL container - upgrade did not work!"
        FAILURE=1
    fi

    # Shut down any containers that are still running
    docker compose -f docker-compose-pgauto.yml down --remove-orphans

    # Delete the upgraded PostgreSQL data directory
    sudo rm -rf postgres-data

    ##
    ## Tests for one shot mode
    ##
    banner '-' "Testing 'one shot' automatic upgrade mode for PostgreSQL ${VERSION} to ${TARGET}"

    import_adventure_works

    # Shut down all of the containers
    docker compose -f "docker-compose-pg${VERSION}.yml" down --remove-orphans

    # Run the PostgreSQL container in one shot mode
    docker compose -f $PGAUTO_COMPOSE run --rm -e PGAUTO_ONESHOT=yes postgres

    # Verify the PostgreSQL data files are now the target version
    PGVER=$(sudo cat $PGVERSION_FILE)
    if [ "$PGVER" != "${TARGET%%.*}" ]; then
        banner '*' "'One shot' automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} FAILED!"
        FAILURE=1
    else
        banner '*' "'One shot' automatic upgrade of PostgreSQL from version ${VERSION} to ${TARGET} SUCCEEDED!"
    fi

    # Verify after one-shot that the official Postgres image can be used again
    docker compose -f $PGTARGET_COMPOSE up --wait -d
    if ! docker compose -f $PGTARGET_COMPOSE exec postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='AdventureWorks'" | grep -q 1; then
        banner "Adventure works database does not exist in new PostgreSQL container - upgrade did not work!"
        FAILURE=1
    fi

    # Shut down any containers that are still running
    docker compose -f $PGTARGET_COMPOSE down

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

echo "Downloading and extracting the AdventureWork database ..."
rm -rf AdventureWorks.tar.xz AdventureWorks.sql
curl -L -o AdventureWorks.tar.xz "https://github.com/pgautoupgrade/AdventureWorks-for-Postgres/raw/refs/heads/master/AdventureWorks.tar.xz"
tar -xf AdventureWorks.tar.xz

for version in "${PG_VERSIONS[@]}"; do
    # Only test if the version is less than the latest version
    if [[ $(echo "$version < ${PGTARGET%%.*}" | bc) -eq 1 ]]; then
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
