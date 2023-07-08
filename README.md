This is a PostgreSQL Docker container for the Redash project.

It's whole purpose in life is to automatically detect the
version of PostgreSQL used in the existing PostgreSQL data
directory, and automatically upgrade it (if needed) to the
latest version of PostgreSQL.

After this, the PostgreSQL server starts and runs as per
normal.

The reason this Docker container is needed, is because
the official Docker PostgreSQL container has no ability
to handle version upgrades, so people need to figure it
out manually (not great):

&nbsp; &nbsp; https://github.com/docker-library/postgres/issues/37
