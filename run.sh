#!/usr/bin/env bash

# Start the docker container 
docker run --name pgauto -it --rm -e POSTGRES_PASSWORD=password --mount type=bind,source=$(pwd)/pgstuff/postgres-data,target=/var/lib/postgresql/data pgautoupgrade:latest
