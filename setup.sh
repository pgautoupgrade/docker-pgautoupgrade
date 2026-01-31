#!/usr/bin/env bash


docker swarm init

docker volume create pgdata16

docker run --rm \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=testdb \
  -v pgdata16:/var/lib/postgresql/data \
  postgres:16 \
  bash -c '
    docker-entrypoint.sh postgres & 
    pid=$!
    # wait for server
    until pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
    psql -U postgres -d testdb -c "CREATE TABLE t(x int); INSERT INTO t VALUES (1);"
    kill $pid
    wait $pid || true
  '

docker build -f Dockerfile.test -t pgautoupgrade:17-test .

docker build -f Dockerfile.fix -t pgautoupgrade:17-fix .

