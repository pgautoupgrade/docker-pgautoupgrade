#!/usr/bin/env bash

# Define the path to the upgrade lock file using PGDATA if set, otherwise default
UPGRADE_LOCK_FILE="${PGDATA:-/var/lib/postgresql}/upgrade_in_progress.lock"

# Check if an upgrade is in progress and keep the container alive
if [ -f "$UPGRADE_LOCK_FILE" ]; then
    exit 0
fi

pg_isready -d "${POSTGRES_DB}" -U "${POSTGRES_USER}"

# Capture the exit status of pg_isready
PG_ISREADY_STATUS=$?

if [ $PG_ISREADY_STATUS -eq 0 ]; then
    exit 0
else
    # Exit with the status of pg_isready
    exit $PG_ISREADY_STATUS
fi
