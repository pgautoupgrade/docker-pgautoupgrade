#!/usr/bin/env bash
set -Eeo pipefail
# TODO swap to -Eeuo pipefail above (after handling all potentially-unset variables)

EXISTING_PG_HBA_CONF=0
EXISTING_PGDATA_PERMISSIONS=$(stat -c %a "$PGDATA")
EXISTING_PGDATA_OWNER_GROUP=$(stat -c "%u:%g" "$PGDATA")
EXISTING_POSTGRESQL_CONF=0

# if a valid PGDATA exists, the database directory is likely already initialized
# if coming from a Bitnami image, we need to inject a postgresql.conf and pg_hba.conf file
# and if they requested "one shot" mode, we will remove it again so they can continue to use the Bitnami image
if [ -f "$PGDATA/PG_VERSION" ]; then
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

/usr/local/bin/postgres-docker-entrypoint.sh "$@"

if [ "x${PGAUTO_ONESHOT}" = "xyes" ]; then
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
