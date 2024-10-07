.PHONY: local attach before clean down server test up pushdev

local:
	docker build -f Dockerfile.alpine -t pgautoupgrade/pgautoupgrade:local .

attach:
	docker exec -it pgauto /bin/bash

before:
	if [ ! -d "test/postgres-data" ]; then \
		mkdir test/postgres-data; \
	fi
	docker run --name pgauto -it --rm \
		--mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data \
		-e POSTGRES_PASSWORD=password \
		-e PGAUTO_DEVEL=before \
		pgautoupgrade/pgautoupgrade:local

clean:
	docker image rm --force \
		pgautoupgrade/pgautoupgrade:dev \
		pgautoupgrade/pgautoupgrade:local
	docker image prune -f
	docker volume prune -f

down:
	docker container stop pgauto

server:
	if [ ! -d "test/postgres-data" ]; then \
		mkdir test/postgres-data; \
	fi
	docker run --name pgauto -it --rm --mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data \
		-e POSTGRES_PASSWORD=password \
		-e PGAUTO_DEVEL=server \
		pgautoupgrade/pgautoupgrade:local

test:
	./test.sh

up:
	if [ ! -d "test/postgres-data" ]; then \
		mkdir test/postgres-data; \
	fi
	docker run --name pgauto -it --rm \
		--mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data \
		-e POSTGRES_PASSWORD=password \
		pgautoupgrade/pgautoupgrade:local

pushdev:
	docker tag pgautoupgrade/pgautoupgrade:local pgautoupgrade/pgautoupgrade:dev
	docker push pgautoupgrade/pgautoupgrade:dev
	docker image rm pgautoupgrade/pgautoupgrade:dev
