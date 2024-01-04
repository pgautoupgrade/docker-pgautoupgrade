ARG PGTARGET=16

### Things we need in all build containers
FROM alpine:3.18 as base-build

# Where we'll do all our compiling and similar
ENV BUILD_ROOT /buildroot

# Make the directory for building, and set it as the default for the following Docker commands
RUN mkdir ${BUILD_ROOT}
WORKDIR ${BUILD_ROOT}

# Install things needed for development
# We might want to install "alpine-sdk" instead of "build-base", if build-base
# doesn't have everything we need
RUN apk update && \
    apk upgrade && \
    apk add --update build-base icu-data-full icu-dev linux-headers lz4-dev musl musl-locales musl-utils tzdata zlib-dev && \
    apk cache clean

### PostgreSQL 9.5
FROM base-build as build-9.5

RUN wget https://ftp.postgresql.org/pub/source/v9.5.25/postgresql-9.5.25.tar.bz2 && \
  tar -xf postgresql-9.5*.tar.bz2

RUN cd postgresql-9.5.* && \
  ./configure --prefix=/usr/local-pg9.5 --with-openssl=no --without-readline --enable-debug=no CFLAGS="-Os" && \
  make -j12 && \
  make install && \
  rm -rf /usr/local-pg9.5/include

### PostgreSQL 9.6
FROM base-build as build-9.6

RUN wget https://ftp.postgresql.org/pub/source/v9.6.24/postgresql-9.6.24.tar.bz2 && \
  tar -xf postgresql-9.6*.tar.bz2

RUN cd postgresql-9.6.* && \
    ./configure --prefix=/usr/local-pg9.6 --with-openssl=no --without-readline --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg9.6/include

### PostgreSQL 10
FROM base-build as build-10
RUN wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.bz2 && \
  tar -xf postgresql-10*.tar.bz2

RUN cd postgresql-10.* && \
    ./configure --prefix=/usr/local-pg10 --with-openssl=no --without-readline --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg10/include

### PostgreSQL 11
FROM base-build as build-11
RUN wget https://ftp.postgresql.org/pub/source/v11.22/postgresql-11.22.tar.bz2 && \
  tar -xf postgresql-11*.tar.bz2

RUN cd postgresql-11.* && \
    ./configure --prefix=/usr/local-pg11 --with-openssl=no --without-readline --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg11/include

### PostgreSQL 12
FROM base-build as build-12
RUN wget https://ftp.postgresql.org/pub/source/v12.17/postgresql-12.17.tar.bz2 && \
  tar -xf postgresql-12*.tar.bz2

RUN cd postgresql-12.* && \
    ./configure --prefix=/usr/local-pg12 --with-openssl=no --without-readline --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg12/include

### PostgreSQL 13
FROM base-build as build-13

RUN wget https://ftp.postgresql.org/pub/source/v13.13/postgresql-13.13.tar.bz2 && \
  tar -xf postgresql-13*.tar.bz2

RUN cd postgresql-13.* && \
    ./configure --prefix=/usr/local-pg13 --with-openssl=no --without-readline --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg13/include

### PostgreSQL 14
FROM base-build as build-14

RUN wget https://ftp.postgresql.org/pub/source/v14.10/postgresql-14.10.tar.bz2 && \
  tar -xf postgresql-14*.tar.bz2

RUN cd postgresql-14.* && \
    ./configure --prefix=/usr/local-pg14 --with-openssl=no --without-readline --with-icu --with-lz4 --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg14/include

### PostgreSQL 15
FROM base-build as build-15

RUN wget https://ftp.postgresql.org/pub/source/v15.5/postgresql-15.5.tar.bz2 && \
  tar -xf postgresql-15*.tar.bz2

RUN cd postgresql-15.* && \
    ./configure --prefix=/usr/local-pg15 --with-openssl=no --without-readline --with-icu --with-lz4 --enable-debug=no CFLAGS="-Os" && \
    make -j12 && \
    make install && \
    rm -rf /usr/local-pg15/include

# Use the PostgreSQL Alpine image as our output image base
FROM postgres:${PGTARGET}-alpine3.18

# We need to define this here, to make the above PGTARGET available after the FROM
ARG PGTARGET

# Copy across our compiled files
COPY --from=build-9.5 /usr/local-pg9.5 /usr/local-pg9.5
COPY --from=build-9.6 /usr/local-pg9.6 /usr/local-pg9.6
COPY --from=build-10 /usr/local-pg10 /usr/local-pg10
COPY --from=build-11 /usr/local-pg11 /usr/local-pg11
COPY --from=build-12 /usr/local-pg12 /usr/local-pg12
COPY --from=build-13 /usr/local-pg13 /usr/local-pg13
COPY --from=build-14 /usr/local-pg14 /usr/local-pg14
COPY --from=build-15 /usr/local-pg15 /usr/local-pg15

# Remove any left over PG directory stubs.  Doesn't help with image size, just with clarity on what's in the image.
RUN if [ "${PGTARGET}" -eq 13 ]; then rm -rf /usr/local-pg13 /usr/local-pg14 /usr/local-pg15; fi
RUN if [ "${PGTARGET}" -eq 14 ]; then rm -rf /usr/local-pg14 /usr/local-pg15; fi
RUN if [ "${PGTARGET}" -eq 15 ]; then rm -rf /usr/local-pg15; fi

# Install locale
RUN apk update && \
    apk add --update icu-data-full musl musl-utils musl-locales tzdata && \
    apk cache clean

## FIXME: Only useful while developing this Dockerfile
##RUN apk add man-db man-pages-posix

# Pass the PG build target through to the running image
ENV PGTARGET=${PGTARGET}

# Set up the script run by the container when it starts
WORKDIR /var/lib/postgresql
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["postgres"]
