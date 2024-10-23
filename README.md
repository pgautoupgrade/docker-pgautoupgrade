This is a PostgreSQL Docker image to automatically upgrade
your database.

Its whole purpose in life is to automatically detect the
version of PostgreSQL used in the existing PostgreSQL data
directory, then automatically upgrade it (if needed) to the
required version of PostgreSQL.

After this, the PostgreSQL server starts and runs as per
normal.

The reason this Docker image is needed, is because the
official Docker PostgreSQL image has no ability to handle
version upgrades, which leaves people to figure it out
manually (not great): https://github.com/docker-library/postgres/issues/37

## WARNING! Backup your data!

This Docker image does an in-place upgrade of the database
data, so if something goes wrong you are expected to already
have backups you can restore from.

## How to use this image

This image is on Docker Hub:

https://hub.docker.com/r/pgautoupgrade/pgautoupgrade

To always use the latest version of PostgreSQL, use the tag
`latest`:

    pgautoupgrade/pgautoupgrade:latest

Please note that our `latest` tag is based on Alpine Linux,
whereas the `latest` tag used by the official Docker
Postgres container is based on Debian.

If you instead want to run a specific version of PostgreSQL
then pick a matching tag on our Docker Hub. For example, to
use PostgreSQL 17 you can use:

    pgautoupgrade/pgautoupgrade:17-alpine

### Debian vs Alpine based images

The default official Docker PostgreSQL image is Debian Linux
based, and upgrading from that to one of our Alpine Linux
based images doesn't always work out well.

To solve that problem, we have Debian based images
(`17-bookworm` and `16-bookworm`) available now as well.

To use either of those, choose the version of PostgreSQL you'd
like to upgrade to, then change your docker image to match:

    pgautoupgrade/pgautoupgrade:17-bookworm

### "One shot" mode

If you just want to perform the upgrade without running PostgreSQL
afterwards, then you can use "[One Shot](https://github.com/pgautoupgrade/docker-pgautoupgrade/issues/13)" mode.

To do that, add an environment variable called `PGAUTO_ONESHOT`
(equal to `yes`) when you run the container.  Like this:

```
$ docker run --name pgauto -it \
	--mount type=bind,source=/path/to/your/database/directory,target=/var/lib/postgresql/data \
	-e POSTGRES_PASSWORD=password \
	-e PGAUTO_ONESHOT=yes \
	<NAME_OF_THE_PGAUTOUPGRADE_IMAGE>
```

### Skip reindexing

By default, all databases are reindexed after the migration, which can take some time if they are large.
To skip reindexing, set the environment variable `PGAUTO_REINDEX` to `no`, for example:

```
$ docker run --name pgauto -it \
	--mount type=bind,source=/path/to/your/database/directory,target=/var/lib/postgresql/data \
	-e POSTGRES_PASSWORD=password \
	-e PGAUTO_REINDEX=no \
	<NAME_OF_THE_PGAUTOUPGRADE_IMAGE>
```

# For Developers

## Building the image

To build the development docker image, use:

```
$ make dev
```

This will take a few minutes to create the "pgautoupgrade:local"
docker image, that you can use in your docker-compose.yml
files.

## Customising the image

[Our wiki](https://github.com/pgautoupgrade/docker-pgautoupgrade/wiki)
now includes instructions for customising the image to include
your own extensions:

&nbsp; &nbsp; https://github.com/pgautoupgrade/docker-pgautoupgrade/wiki/Including-Extensions-(PostGIS)

## Breakpoints in the image

There are (at present) two predefined er... "breakpoints"
in the image.  When you run the image with either
of them, then the image will start up and keep running,
but the docker-entrypoint script will pause at the chosen
location.

This way, you can `docker exec` into the running container to
try things out, do development, testing, debugging, etc.

### Before breakpoint

The `before` breakpoint stops just before the `pg_upgrade`
part of the script runs, so you can try alternative things
instead.

```
$ make before
```

### Server breakpoint

The `server` breakpoint stops after the existing `pg_upgrade`
script has run, but before the PostgreSQL server starts.  Useful
if you want to investigate the results of the upgrade prior to
PostgreSQL acting on them.

```
$ make server
```

## Testing the image

To run the tests, use:

```
$ make test
```

The test script imports the AdventureWorks database (ported from Microsoft
land) into an older PG version, then starts the pgautoupgrade container to
update the database to the latest PostgreSQL version.

It then checks that the database files were indeed updated
to the newest PostgreSQL release, and outputs an obvious
SUCCESS/FAILURE message for that loop.

The test runs in a loop, testing (in sequence) upgrades from
PostgreSQL versions 9.5, 9.6, 10.x, 11.x, 12.x, 13.x, 14.x, 15.x., 16.x and
17.x.
