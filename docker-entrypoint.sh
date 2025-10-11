#!/usr/bin/env bash
set -Eeo pipefail

EXISTING_PG_HBA_CONF=0
EXISTING_POSTGRESQL_CONF=0
POSTGRESQL_DATA_DIRECTORY_HAS_DATA=0

if [ -d "/bitnami/postgresql" ]; then
    # we deal with the standard Bitnami environment
    # overwrite PGDATA to point to the data directory
    export PGDATA="/bitnami/postgresql/data"
elif [ -n "$POSTGRESQL_DATA_DIR" ]; then
    # this is the Bitnami environment to customize the Postgres data directory
    export PGDATA=$POSTGRESQL_DATA_DIR
elif [ -n "$POSTGRESQL_VOLUME_DIR" ]; then
    # this is the Bitnami environment to customize the Postgres persistence directory
    # data is a subfolder of that
    export PGDATA="${POSTGRESQL_VOLUME_DIR}/data"
fi

if [ -n $POSTGRESQL_PASSWORD ] && [ -z $POSTGRES_PASSWORD ]; then
    export POSTGRES_PASSWORD=$POSTGRESQL_PASSWORD
fi

# if a valid PGDATA exists, the database directory is likely already initialized
# if coming from a Bitnami image, we need to inject a postgresql.conf and pg_hba.conf file
# and if they requested "one shot" mode, we will remove it again so they can continue to use the Bitnami image
if [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ]; then
    POSTGRESQL_DATA_DIRECTORY_HAS_DATA=1

    EXISTING_PGDATA_PERMISSIONS=$(stat -c %a "$PGDATA")
    EXISTING_PGDATA_OWNER_GROUP=$(stat -c "%u:%g" "$PGDATA")

    if [ -f "${PGDATA}/postgresql.conf" ]; then
        EXISTING_POSTGRESQL_CONF=1
    else
        echo "-------------------------------------------------------------------------------"
        echo "The Postgres data directory at ${PGDATA} is missing a postgresql.conf file. Copying a standard version of ours."
        echo "-------------------------------------------------------------------------------"
        cp -f /opt/pgautoupgrade/postgresql.conf "${PGDATA}/postgresql.conf"
    fi

    if [ -f "${PGDATA}/pg_hba.conf" ]; then
        EXISTING_PG_HBA_CONF=1
    else
        echo "-------------------------------------------------------------------------------"
        echo "The Postgres data directory at ${PGDATA} is missing a pg_hba.conf file. Copying a standard version of ours."
        echo "-------------------------------------------------------------------------------"
        cp -f "/opt/pgautoupgrade/pg_hba.conf" "${PGDATA}/pg_hba.conf"
    fi
fi

/usr/local/bin/postgres-docker-entrypoint.sh "$@" &
pid="$!"

# forward signals
forward_signal() {
  kill -s "$1" "$pid"
}
trap 'forward_signal TERM' TERM
trap 'forward_signal INT' INT
trap 'forward_signal HUP' HUP
trap 'forward_signal QUIT' QUIT

# unset "-e" as some exit codes from the Postgres container will be considered a failure
# and lead to a fast exit where the server process does not properly shutdown
set +e

# wait for the child process to exit
wait "$pid"
exit_code=$?

if [[ "x${PGAUTO_ONESHOT}" = "xyes" && $POSTGRESQL_DATA_DIRECTORY_HAS_DATA = 1 ]]; then
    if [ "$EXISTING_POSTGRESQL_CONF" = "0" ]; then
        echo "-------------------------------------------------------------------------------"
        echo "Removing postgresql.conf from ${PGDATA}, as it was not provided by the data directory before the upgrade."
        echo "-------------------------------------------------------------------------------"
        rm -rf "${PGDATA}/postgresql.conf"
    fi

    if [ "$EXISTING_PG_HBA_CONF" = "0" ]; then
        echo "-------------------------------------------------------------------------------"
        echo "Removing pg_hba.conf from ${PGDATA}, as it was not provided by the data directory before the upgrade."
        echo "-------------------------------------------------------------------------------"
        rm -rf "${PGDATA}/pg_hba.conf"
    fi

    echo "-------------------------------------------------------------------------------"
    echo "Restoring original data permissions to ${PGDATA}"
    echo "-------------------------------------------------------------------------------"
    chmod -R $EXISTING_PGDATA_PERMISSIONS "$PGDATA"
    chown -R $EXISTING_PGDATA_OWNER_GROUP "$PGDATA"
fi

# Run a sync before exiting, just to ensure everything is flushed to disk before docker terminates the process
sync

exit "$exit_code"
