#!/usr/bin/env bash

read_env_or_file() {
    local var_name="$1"
    local file_var_name="${var_name}_FILE"

    # Check if the *_FILE environment variable is set and points to a valid file
    if [[ -n "${!file_var_name}" && -f "${!file_var_name}" && -s "${!file_var_name}" ]]; then
        # Read the content of the file and assign it to the variable
        echo "$(cat "${!file_var_name}")"
    else
        # Fallback to the normal environment variable
        echo "${!var_name}"
    fi
}

# Define the path to the upgrade lock file using PGDATA if set, otherwise default
UPGRADE_LOCK_FILE="${PGDATA:-/var/lib/postgresql/data}/upgrade_in_progress.lock"

# Check if an upgrade is in progress and keep the container alive
if [ -f "$UPGRADE_LOCK_FILE" ]; then
    exit 0
fi

POSTGRES_DB_VALUE=$(read_env_or_file "POSTGRES_DB")
POSTGRES_USER_VALUE=$(read_env_or_file "POSTGRES_USER")

pg_isready -d "${POSTGRES_DB_VALUE}" -U "${POSTGRES_USER_VALUE}"

# Capture the exit status of pg_isready
PG_ISREADY_STATUS=$?

if [ $PG_ISREADY_STATUS -eq 0 ]; then
    exit 0
else
    # Exit with the status of pg_isready
    exit $PG_ISREADY_STATUS
fi
