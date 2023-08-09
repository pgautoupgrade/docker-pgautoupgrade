#!/usr/bin/env bash

docker build --build-arg PGTARGET=13 -t pgautoupgrade/pgautoupgrade:13-dev .
