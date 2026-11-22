#!/usr/bin/env bash

# Define the path to the upgrade lock file using PGDATA if set, otherwise default
UPGRADE_LOCK_FILE="${PGDATA:-/var/lib/postgresql/data}/upgrade_in_progress.lock"
# Upgrades into /var/lib/postgresql/19/docker initialise PGDATA from scratch, so the lock lives next to it
if [ "${PGDATA:-}" = "/var/lib/postgresql/19/docker" ]; then
	UPGRADE_LOCK_FILE="/var/lib/postgresql/19/upgrade_in_progress.lock"
fi

# Check if an upgrade is in progress and keep the container alive
if [ -f "$UPGRADE_LOCK_FILE" ]; then
    exit 0
fi

source /usr/local/bin/postgres-docker-entrypoint.sh

file_env 'POSTGRES_USER' 'postgres'
file_env 'POSTGRES_DB' "$POSTGRES_USER"

pg_isready -d "${POSTGRES_DB}" -U "${POSTGRES_USER}"

# Capture the exit status of pg_isready
PG_ISREADY_STATUS=$?

if [ $PG_ISREADY_STATUS -eq 0 ]; then
    exit 0
else
    # Exit with the status of pg_isready
    exit $PG_ISREADY_STATUS
fi
