# We use Alpine as a base image to compile older
# PostgreSQL versions in, then copy the binaries
# into the PG 15 Alpine image
FROM alpine:3.18 AS build

# Where we'll do all our compiling and similar
ENV BUILD_ROOT /buildroot

# Make the directory for building
RUN mkdir ${BUILD_ROOT}

# Download the source code for previous PG releases
RUN cd ${BUILD_ROOT} && \
    wget https://ftp.postgresql.org/pub/source/v9.5.25/postgresql-9.5.25.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v9.6.24/postgresql-9.6.24.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v11.20/postgresql-11.20.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v12.15/postgresql-12.15.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v13.11/postgresql-13.11.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v14.8/postgresql-14.8.tar.bz2

# Extract the source code
RUN cd ${BUILD_ROOT} && \
    tar -xf postgresql-9.5*.tar.bz2 && \
    tar -xf postgresql-9.6*.tar.bz2 && \
    tar -xf postgresql-10*.tar.bz2 && \
    tar -xf postgresql-11*.tar.bz2 && \
    tar -xf postgresql-12*.tar.bz2 && \
    tar -xf postgresql-13*.tar.bz2 && \
    tar -xf postgresql-14*.tar.bz2

# Install things needed for development
# We might want to install "alpine-sdk" instead of "build-base", if build-base
# doesn't have everything we need
RUN apk update && \
    apk upgrade && \
    apk add --update build-base icu-data-full icu-dev linux-headers lz4-dev musl musl-locales musl-utils tzdata zlib-dev && \
    apk cache clean

# Compile PG releases with fairly minimal options
# Note that given some time, we could likely remove the pieces of the older PG installs which aren't needed by pg_upgrade
RUN cd ${BUILD_ROOT}/postgresql-9.5.* && \
    ./configure --prefix=/usr/local-pg9.5 --with-openssl=no --without-readline --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg9.5/include
RUN cd ${BUILD_ROOT}/postgresql-9.6.* && \
    ./configure --prefix=/usr/local-pg9.6 --with-openssl=no --without-readline --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg9.6/include
RUN cd ${BUILD_ROOT}/postgresql-10.* && \
    ./configure --prefix=/usr/local-pg10 --with-openssl=no --without-readline --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg10/include
RUN cd ${BUILD_ROOT}/postgresql-11.* && \
    ./configure --prefix=/usr/local-pg11 --with-openssl=no --without-readline --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg11/include
RUN cd ${BUILD_ROOT}/postgresql-12.* && \
    ./configure --prefix=/usr/local-pg12 --with-openssl=no --without-readline --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg12/include
RUN cd ${BUILD_ROOT}/postgresql-13.* && \
    ./configure --prefix=/usr/local-pg13 --with-openssl=no --without-readline --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg13/include
RUN cd ${BUILD_ROOT}/postgresql-14.* && \
    ./configure --prefix=/usr/local-pg14 --with-openssl=no --without-readline --with-icu --with-lz4 --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg14/include

# Use the PostgreSQL Alpine image as our output image base
FROM postgres:15-alpine3.18

# Copy across our compiled files
COPY --from=build /usr/local-pg9.5 /usr/local-pg9.5
COPY --from=build /usr/local-pg9.6 /usr/local-pg9.6
COPY --from=build /usr/local-pg10 /usr/local-pg10
COPY --from=build /usr/local-pg11 /usr/local-pg11
COPY --from=build /usr/local-pg12 /usr/local-pg12
COPY --from=build /usr/local-pg13 /usr/local-pg13
COPY --from=build /usr/local-pg14 /usr/local-pg14

# Install locale
RUN apk update && \
    apk add --update icu-data-full musl musl-utils musl-locales tzdata && \
    apk cache clean

## FIXME: Only useful while developing this Dockerfile
RUN apk add man-db man-pages-posix

WORKDIR /var/lib/postgresql

COPY docker-entrypoint.sh /usr/local/bin/

#ENTRYPOINT ["/bin/sh"]
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["postgres"]
