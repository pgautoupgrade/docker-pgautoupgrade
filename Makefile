.PHONY: all dev 13dev 14dev 15dev prod attach before clean down server test up pushdev pushprod

all: 12dev 13dev 14dev 15dev 16dev prod

dev: 16dev

12dev:
	docker build -f Dockerfile.alpine --build-arg PGTARGET=12 -t pgautoupgrade/pgautoupgrade:12-dev . && \
	docker build -f Dockerfile.bookworm --build-arg PGTARGET=12 -t pgautoupgrade/pgautoupgrade:12-dev-bookworm .

13dev:
	docker build -f Dockerfile.alpine --build-arg PGTARGET=13 -t pgautoupgrade/pgautoupgrade:13-dev . && \
	docker build -f Dockerfile.bookworm --build-arg PGTARGET=13 -t pgautoupgrade/pgautoupgrade:13-dev-bookworm .

14dev:
	docker build -f Dockerfile.alpine --build-arg PGTARGET=14 -t pgautoupgrade/pgautoupgrade:14-dev . && \
	docker build -f Dockerfile.bookworm --build-arg PGTARGET=14 -t pgautoupgrade/pgautoupgrade:14-dev-bookworm .

15dev:
	docker build -f Dockerfile.alpine --build-arg PGTARGET=15 -t pgautoupgrade/pgautoupgrade:15-dev . && \
	docker build -f Dockerfile.bookworm --build-arg PGTARGET=15 -t pgautoupgrade/pgautoupgrade:15-dev-bookworm .

16dev:
	docker build -f Dockerfile.alpine -t pgautoupgrade/pgautoupgrade:16-dev -t pgautoupgrade/pgautoupgrade:dev . && \
	docker build -f Dockerfile.bookworm -t pgautoupgrade/pgautoupgrade:16-dev-bookworm -t pgautoupgrade/pgautoupgrade:dev-bookworm .

prod:
	docker build -f Dockerfile.alpine --build-arg PGTARGET=15 -t pgautoupgrade/pgautoupgrade:15-alpine3.20 -t pgautoupgrade/pgautoupgrade:15-alpine . && \
	docker build -f Dockerfile.alpine -t pgautoupgrade/pgautoupgrade:16-alpine3.20 -t pgautoupgrade/pgautoupgrade:16-alpine -t pgautoupgrade/pgautoupgrade:latest .

attach:
	docker exec -it pgauto /bin/bash

before:
	if [ ! -d "test/postgres-data" ]; then \
		mkdir test/postgres-data; \
	fi && \
	docker run --name pgauto -it --rm \
		--mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data \
		-e POSTGRES_PASSWORD=password \
		-e PGAUTO_DEVEL=before \
		pgautoupgrade/pgautoupgrade:dev

clean:
	docker image rm --force pgautoupgrade/pgautoupgrade:dev \
		pgautoupgrade/pgautoupgrade:dev-bookworm \
		pgautoupgrade/pgautoupgrade:12-dev \
		pgautoupgrade/pgautoupgrade:12-dev-bookworm \
		pgautoupgrade/pgautoupgrade:13-dev \
		pgautoupgrade/pgautoupgrade:13-dev-bookworm \
		pgautoupgrade/pgautoupgrade:14-dev \
		pgautoupgrade/pgautoupgrade:14-dev-bookworm \
		pgautoupgrade/pgautoupgrade:15-dev \
		pgautoupgrade/pgautoupgrade:15-dev-bookworm \
		pgautoupgrade/pgautoupgrade:16-dev \
		pgautoupgrade/pgautoupgrade:16-dev-bookworm \
		pgautoupgrade/pgautoupgrade:15-alpine \
		pgautoupgrade/pgautoupgrade:15-bookworm \
		pgautoupgrade/pgautoupgrade:16-alpine \
		pgautoupgrade/pgautoupgrade:16-bookworm \
		pgautoupgrade/pgautoupgrade:15-alpine3.20 \
		pgautoupgrade/pgautoupgrade:16-alpine3.20 \
		pgautoupgrade/pgautoupgrade:latest && \
	docker image prune -f && \
	docker volume prune -f

down:
	./test.sh down

server:
	if [ ! -d "test/postgres-data" ]; then \
		mkdir test/postgres-data; \
	fi && \
	docker run --name pgauto -it --rm --mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data \
		-e POSTGRES_PASSWORD=password \
		-e PGAUTO_DEVEL=server \
		pgautoupgrade/pgautoupgrade:dev

test:
	./test.sh

up:
	if [ ! -d "test/postgres-data" ]; then \
		mkdir test/postgres-data; \
	fi && \
	docker run --name pgauto -it --rm \
		--mount type=bind,source=$(abspath $(CURDIR))/test/postgres-data,target=/var/lib/postgresql/data \
		-e POSTGRES_PASSWORD=password \
		pgautoupgrade/pgautoupgrade:dev

pushdev:
	docker push pgautoupgrade/pgautoupgrade:12-dev && \
	docker push pgautoupgrade/pgautoupgrade:12-dev-bookworm && \
	docker push pgautoupgrade/pgautoupgrade:13-dev && \
	docker push pgautoupgrade/pgautoupgrade:13-dev-bookworm && \
	docker push pgautoupgrade/pgautoupgrade:14-dev && \
	docker push pgautoupgrade/pgautoupgrade:14-dev-bookworm && \
	docker push pgautoupgrade/pgautoupgrade:15-dev && \
	docker push pgautoupgrade/pgautoupgrade:15-dev-bookworm && \
	docker push pgautoupgrade/pgautoupgrade:16-dev && \
	docker push pgautoupgrade/pgautoupgrade:16-dev-bookworm && \
	docker push pgautoupgrade/pgautoupgrade:dev && \
	docker push pgautoupgrade/pgautoupgrade:dev-bookworm

pushprod:
	docker push pgautoupgrade/pgautoupgrade:15-alpine3.20 && \
	docker push pgautoupgrade/pgautoupgrade:15-alpine && \
	docker push pgautoupgrade/pgautoupgrade:16-alpine3.20 && \
	docker push pgautoupgrade/pgautoupgrade:16-alpine && \
	docker push pgautoupgrade/pgautoupgrade:latest