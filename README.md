# pgautoupgrade

This is a PostgreSQL Docker image to automatically upgrade
your database.

Its whole purpose in life is to automatically detect the
version of PostgreSQL used in the existing PostgreSQL data
directory, then automatically upgrade it (if needed) to the
required version of PostgreSQL using `pg_upgrade` with the `--link` option.

After this, the PostgreSQL server starts and runs as per
normal. The old cluster data will be removed.

The reason this Docker image is needed, is because the
official Docker PostgreSQL image has no ability to handle
version upgrades, which leaves people to figure it out
manually (not great): <https://github.com/docker-library/postgres/issues/37>

> [!WARNING]
> Backup your data!
> This Docker image does an in-place upgrade of the database
> data, so if something goes wrong you are expected to already
> have backups you can restore from.

> [!IMPORTANT]
> Also, remove any healthchecks.
> Due to how we perform the update process, we had to implement our own healthcheck.
> So no extra healthcheck is needed.

## How to use this image

This image is on Docker Hub:

<https://hub.docker.com/r/pgautoupgrade/pgautoupgrade>

To always use the latest version of PostgreSQL, use the tag
`latest`:

    pgautoupgrade/pgautoupgrade:latest

Please note that our `latest` tag is based on Alpine Linux,
whereas the `latest` tag used by the official Docker
Postgres container is based on Debian (see also the section on [Debian vs Alpine based images](#debian-vs-alpine-based-images)).

If you instead want to run a specific version of PostgreSQL
then pick a matching tag on our Docker Hub. For example, to
use PostgreSQL 18 you can use the `18-alpine` tag:

    pgautoupgrade/pgautoupgrade:18-alpine

> [!NOTE]
> The images available in Github Container Registry are for debugging
> purposes only. They are built from specific code branches for easier
> distribution and testing of fixes.

### Debian vs Alpine based images

The default official Docker PostgreSQL image is Debian Linux
based, and upgrading from that to one of our Alpine Linux
based images doesn't always work out well.

To solve that problem, we have Debian based images available as well.

To use either of those, choose the version of PostgreSQL you'd
like to upgrade to, then change your docker image to match:

    pgautoupgrade/pgautoupgrade:18-trixie

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

### Reindexing

By default, all databases are reindexed after the migration, which can take some time if they are large.
To skip reindexing, set the environment variable `PGAUTO_REINDEX` to `no`, for example:

```
$ docker run --name pgauto -it \
	--mount type=bind,source=/path/to/your/database/directory,target=/var/lib/postgresql/data \
	-e POSTGRES_PASSWORD=password \
	-e PGAUTO_REINDEX=no \
	<NAME_OF_THE_PGAUTOUPGRADE_IMAGE>
```

> [!WARNING]
> PG v15 and below do not support reindexing system tables in a database concurrently. This means, when we start the indexing operation, database locks are placed which do not allow for any modifications as long as the task is running. We recommend using PG v16 or later where this is not an issue.

### Upgrading from a Bitnami container

If you used the Postgres image by Bitnami, we have made a couple of adjustments to make this upgrade work as well.

The Bitnami containers do not persist the `postgresql.conf` and `pg_hba.conf` file in the Postgres data directory. If we detect that these files are missing, we will copy a default version of these files into the data directory. If you request the "one shot" mode, these files will be removed again at the end of the upgrade process.

The official Postgres image, and therefore ours as well, use `999` as ID for the postgres user inside the container. Bitnami uses 1001. During the upgrade process, we make a copy of the data, which will be assigned to ID `999`. If you request the "one shot" mode, the original file permissions will be restored once the upgrade is completed.

We use the official Postgres variables, but can map certain things:

- Bitnami's `POSTGRESQL_PASSWORD` becomes `POSTGRES_PASSWORD`.
- Bitnami's `POSTGRESQL_DATA_DIR` becomes `PGDATA`.
- `PGDATA` is set automatically to `/bitnami/postgresql/data` if it is not empty.

The container has to run as `root` if using `one shot` mode, otherwise we are unable to restore the existing file permissions of your Postgres data directory. You can run the container as user `999`, but then you will have to manually apply the file permissions to your Postgres data directory.

> [!WARNING]
> As of writing this paragraph (5th of October, 2025), we tested upgrading from Bitnami Postgres v9.5, v9.6, v10, v11, v12, v13, v14, v15, v16, v17 to v17 and v18. For these versions, we used the latest available container version from [Bitnami Legacy](https://hub.docker.com/r/bitnamilegacy/postgresql/). Bitnami's script and directory structure could change over time. If you note any issues upgrading from other versions, please provide the exact SHA of the image so we can try to replicate the issue. Also note we do not have any access to Bitnami Secure Images.

### One-shot mode in Kubernetes

You can run `pgautoupgrade` as an `initContainer` in Kubernetes to enable one-shot mode. Below you can find an example for an upgrade for a Bitnami Postgres container.

```yaml
initContainers:
- env:
  - name: PGAUTO_ONESHOT
    value: "yes"
  - name: POSTGRES_DB
    value: XXX
  - name: PGDATA
    value: /bitnami/postgresql/data
  - name: POSTGRES_PASSWORD
    value: password
image: pgautoupgrade/pgautoupgrade:18-trixie
name: upgrade-postgres
securityContext:
  runAsUser: 0
volumeMounts:
  - mountPath: /bitnami/postgresql
    name: YYY
```

The value for `POSTGRES_PASSWORD` does not really matter, as it's never used in one-shot mode.

## Error message when mounting data to /var/lib/postgresql/data on Postgres v18+

If you want to upgrade to Postgres v18+ and don't adjust your volume mounts, you can get an error message like:

```
docker: Error response from daemon: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: error mounting "/var/lib/docker/volumes/foo/_data" to rootfs at "/var/lib/postgresql/data": change mount propagation through procfd: open o_path procfd: open /var/lib/docker/overlay2/bd954e9c05618d52115b5345f7465cf17cc426560b0979d7f796ebfbf62ea950/merged/var/lib/postgresql/data: no such file or directory: unknown.
```

on Docker or

```
error mounting ".../db-pv" to rootfs at "/var/lib/postgresql/data": change mount propagation through procfd: open o_path procfd: open /run/k3s/containerd/io.containerd.runtime.v2.task/k8s.io/postgresql/rootfs/var/lib/postgresql/data: no such file or directory
```

in Kubernetes.

Then you have to adjust your volume mount from `/var/lib/postgresql/data` to `/var/lib/postgresql`.
`pgautoupgrade` will look there for an old Postgres installation, and move the data into the new expected structure.

Root cause is [a change by the Docker team for Postgres](https://github.com/docker-library/postgres/pull/1259) that enforces a new data directory structure with Postgres v18+.
Previously, your Postgres data and the corresponding `PGDATA` pointed to `/var/lib/postgresql/data`.
With Postgres v18+, it is `/var/lib/postgresql/MAJOR/docker`.
The Docker team also placed a symlink from `/var/lib/postgresql/data` to `/var/lib/postgresql` causing the error messages above.

[We discussed the behaviour](https://github.com/pgautoupgrade/docker-pgautoupgrade/issues/164) and decided not to remove the symlink in our image in order to allow again mounting data to `/var/lib/postgresql/data`.
The main reason is that `PGDATA` on Postgres v18+ points to the mentioned new path `/var/lib/postgresql/MAJOR/docker`.
Means if you would upgrade to Postgres v18+ without any changes to `PGDATA`, you simply get an empty Postgres instance, instead of an upgraded one.
But we also want to follow what the upstream Postgres image does; it should always be an option to ditch `pgautoupgrade` for the plain Postgres image.

## For Developers

### Building the image

To build the development docker image, use:

```
$ make dev
```

This will take a few minutes to create the "pgautoupgrade:local"
docker image, that you can use in your docker-compose.yml
files.

### Customising the image

[Our wiki](https://github.com/pgautoupgrade/docker-pgautoupgrade/wiki)
now includes instructions for customising the image to include
your own extensions:

&nbsp; &nbsp; https://github.com/pgautoupgrade/docker-pgautoupgrade/wiki/Including-Extensions-(PostGIS)

### Breakpoints in the image

There are (at present) two predefined er... "breakpoints"
in the image.  When you run the image with either
of them, then the image will start up and keep running,
but the docker-entrypoint script will pause at the chosen
location.

This way, you can `docker exec` into the running container to
try things out, do development, testing, debugging, etc.

#### Before breakpoint

The `before` breakpoint stops just before the `pg_upgrade`
part of the script runs, so you can try alternative things
instead.

```
$ make before
```

#### Server breakpoint

The `server` breakpoint stops after the existing `pg_upgrade`
script has run, but before the PostgreSQL server starts.  Useful
if you want to investigate the results of the upgrade prior to
PostgreSQL acting on them.

```
$ make server
```

### Testing the image

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
PostgreSQL versions 9.5, 9.6, 10.x, 11.x, 12.x, 13.x, 14.x, 15.x., 16.x and 17.x.
