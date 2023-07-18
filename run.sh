#!/usr/bin/env bash

if [ ! -d "test/postgres-data" ]; then
  mkdir test/postgres-data
fi

# Start the docker container 
docker run --name pgauto -it --rm -e POSTGRES_PASSWORD=password --mount type=bind,source=$(pwd)/test/postgres-data,target=/var/lib/postgresql/data $@ pgautoupgrade/pgautoupgrade:dev
