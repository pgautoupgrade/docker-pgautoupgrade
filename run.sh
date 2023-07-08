#!/usr/bin/env bash

# Create a sub-directory to hold the PG data, due to a really silly Docker bug that they're ignoring
if [ ! -d pgstuff ]; then
    mkdir pgstuff
fi

# Start the docker container 
docker run --name pgauto -it --rm -e POSTGRES_PASSWORD=password --mount type=bind,source=$(pwd)/pgstuff/postgres-data,target=/var/lib/postgresql/data pgautoupgrade:latest
