.PHONY: all dev 13dev 14dev 15dev latest attach before clean down server test up

all: 13dev 14dev 15dev latest

dev: 15dev

13dev:
	docker build --build-arg PGTARGET=13 -t pgautoupgrade/pgautoupgrade:13-dev .

14dev:
	docker build --build-arg PGTARGET=14 -t pgautoupgrade/pgautoupgrade:14-dev .

15dev:
	docker build -t pgautoupgrade/pgautoupgrade:dev .

latest:
	docker build -t pgautoupgrade/pgautoupgrade:15-alpine3.8 -t pgautoupgrade/pgautoupgrade:latest .

attach:
	docker exec -it pgauto /bin/bash

before:
	if [ ! -d "test/postgres-data" ]; then mkdir test/postgres-data; fi && docker run --name pgauto -it --rm -e POSTGRES_PASSWORD=password --mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data -e PGAUTO_DEVEL=before pgautoupgrade/pgautoupgrade:dev

clean:
	docker image rm --force pgautoupgrade/pgautoupgrade:dev pgautoupgrade/pgautoupgrade:13-dev pgautoupgrade/pgautoupgrade:14-dev pgautoupgrade/pgautoupgrade:15-alpine3.8 pgautoupgrade/pgautoupgrade:latest && \
	docker image prune -f && \
	docker volume prune -f

down:
	./test.sh down

server:
	if [ ! -d "test/postgres-data" ]; then mkdir test/postgres-data; fi && docker run --name pgauto -it --rm -e POSTGRES_PASSWORD=password --mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data -e PGAUTO_DEVEL=server pgautoupgrade/pgautoupgrade:dev

test:
	./test.sh

up:
	if [ ! -d "test/postgres-data" ]; then mkdir test/postgres-data; fi && docker run --name pgauto -it --rm -e POSTGRES_PASSWORD=password --mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data pgautoupgrade/pgautoupgrade:dev
