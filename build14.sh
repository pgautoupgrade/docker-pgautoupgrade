#!/usr/bin/env bash

docker build --build-arg PGTARGET=14 -t pgautoupgrade/pgautoupgrade:14-dev .
