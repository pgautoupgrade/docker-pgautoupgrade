#!/usr/bin/env bash


docker service rm pgautoupgrade-test

sleep 10

docker volume rm pgdata16

docker image rm pgautoupgrade:17-test

docker image rm pgautoupgrade:17-fix