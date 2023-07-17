This is a PostgreSQL Docker container that automatically
upgrades your database.

It's whole purpose in life is to automatically detect the
version of PostgreSQL used in the existing PostgreSQL data
directory, and automatically upgrade it (if needed) to the
required version of PostgreSQL.

After this, the PostgreSQL server starts and runs as per
normal.

The reason this Docker container is needed, is because
the official Docker PostgreSQL container has no ability
to handle version upgrades, which leaves people to figure
it out manually (not great): https://github.com/docker-library/postgres/issues/37

## WARNING! Backup your data!

This Docker container does an in-place upgrade of the database
data, so if something goes wrong you are expected to already
have backups you can restore from.

## Building the container

To build the docker image, use:

```
$ ./build.sh
```

This will take a few minutes to create the "pgautoupgrade:latest"
docker container, that you can use in your docker-compose.yml
files.

## Testing the container image

To run the tests, use:

```
$ ./test.sh
```

The test script creates an initial PostgreSQL database for
Redash using an older PG version, then starts Redash using
the above "automatic updating" PostgreSQL container to
update the database to the latest PostgreSQL version.

It then checks that the database files were indeed updated
to the newest PostgreSQL release, and outputs an obvious
SUCCESS/FAILURE message for that loop.

The test runs in a loop, testing (in sequence) PostgreSQL
versions 9.5, 9.6, 10.x, 11.x, 12.x, 13.x, and 14.x.
