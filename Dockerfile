# The version of PostgreSQL this container migrates data to
ARG PGTARGET=16

# We use Alpine as a base image to compile older
# PostgreSQL versions in, then copy the binaries
# into the official PG Alpine image
FROM alpine:3.19 AS build

# We need to define this here, to make the above PGTARGET available after the FROM
ARG PGTARGET

# Where we'll do all our compiling and similar
ENV BUILD_ROOT /buildroot

# Make the directory for building, and set it as the default for the following Docker commands
RUN mkdir ${BUILD_ROOT}
WORKDIR ${BUILD_ROOT}

# Download the source code for previous PG releases
RUN wget https://ftp.postgresql.org/pub/source/v9.5.25/postgresql-9.5.25.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v9.6.24/postgresql-9.6.24.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.bz2 && \
    wget https://ftp.postgresql.org/pub/source/v11.22/postgresql-11.22.tar.bz2
RUN if [ "${PGTARGET}" -gt 12 ]; then wget https://ftp.postgresql.org/pub/source/v12.18/postgresql-12.18.tar.bz2; fi
RUN if [ "${PGTARGET}" -gt 13 ]; then wget https://ftp.postgresql.org/pub/source/v13.14/postgresql-13.14.tar.bz2; fi
RUN if [ "${PGTARGET}" -gt 14 ]; then wget https://ftp.postgresql.org/pub/source/v14.11/postgresql-14.11.tar.bz2; fi
RUN if [ "${PGTARGET}" -gt 15 ]; then wget https://ftp.postgresql.org/pub/source/v15.6/postgresql-15.6.tar.bz2; fi

# Extract the source code
RUN tar -xf postgresql-9.5*.tar.bz2 && \
    tar -xf postgresql-9.6*.tar.bz2 && \
    tar -xf postgresql-10*.tar.bz2 && \
    tar -xf postgresql-11*.tar.bz2
RUN if [ "${PGTARGET}" -gt 12 ]; then tar -xf postgresql-12*.tar.bz2; fi
RUN if [ "${PGTARGET}" -gt 13 ]; then tar -xf postgresql-13*.tar.bz2; fi
RUN if [ "${PGTARGET}" -gt 14 ]; then tar -xf postgresql-14*.tar.bz2; fi
RUN if [ "${PGTARGET}" -gt 15 ]; then tar -xf postgresql-15*.tar.bz2; fi

# Install things needed for development
# We might want to install "alpine-sdk" instead of "build-base", if build-base
# doesn't have everything we need
RUN apk update && \
    apk upgrade && \
    apk add --update build-base icu-data-full icu-dev linux-headers lz4-dev musl musl-locales musl-utils tzdata zlib-dev zstd-dev && \
    apk cache clean

# Compile PG releases with fairly minimal options
# Note that given some time, we could likely remove the pieces of the older PG installs which aren't needed by pg_upgrade
RUN cd postgresql-9.5.* && \
    ./configure --prefix=/usr/local-pg9.5 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg9.5/include
RUN cd postgresql-9.6.* && \
    ./configure --prefix=/usr/local-pg9.6 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg9.6/include
RUN cd postgresql-10.* && \
    ./configure --prefix=/usr/local-pg10 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg10/include
RUN cd postgresql-11.* && \
    ./configure --prefix=/usr/local-pg11 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg11/include
RUN if [ "${PGTARGET}" -gt 12 ]; then cd postgresql-12.* && \
    ./configure --prefix=/usr/local-pg12 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg12/include; else mkdir /usr/local-pg12; fi
RUN if [ "${PGTARGET}" -gt 13 ]; then cd postgresql-13.* && \
    ./configure --prefix=/usr/local-pg13 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg13/include; else mkdir /usr/local-pg13; fi
RUN if [ "${PGTARGET}" -gt 14 ]; then cd postgresql-14.* && \
    ./configure --prefix=/usr/local-pg14 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --with-icu --with-lz4 --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg14/include; else mkdir /usr/local-pg14; fi
RUN if [ "${PGTARGET}" -gt 15 ]; then cd postgresql-15.* && \
    ./configure --prefix=/usr/local-pg15 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --with-icu --with-lz4 --with-zstd --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg15/include; else mkdir /usr/local-pg15; fi

# Use the PostgreSQL Alpine image as our output image base
FROM postgres:${PGTARGET}-alpine3.19

# We need to define this here, to make the above PGTARGET available after the FROM
ARG PGTARGET

# Copy across our compiled files
COPY --from=build /usr/local-pg9.5 /usr/local-pg9.5
COPY --from=build /usr/local-pg9.6 /usr/local-pg9.6
COPY --from=build /usr/local-pg10 /usr/local-pg10
COPY --from=build /usr/local-pg11 /usr/local-pg11
COPY --from=build /usr/local-pg12 /usr/local-pg12
COPY --from=build /usr/local-pg13 /usr/local-pg13
COPY --from=build /usr/local-pg14 /usr/local-pg14
COPY --from=build /usr/local-pg15 /usr/local-pg15

# Remove any left over PG directory stubs.  Doesn't help with image size, just with clarity on what's in the image.
RUN if [ "${PGTARGET}" -eq 12 ]; then rmdir /usr/local-pg12 /usr/local-pg13 /usr/local-pg14 /usr/local-pg15; fi
RUN if [ "${PGTARGET}" -eq 13 ]; then rmdir /usr/local-pg13 /usr/local-pg14 /usr/local-pg15; fi
RUN if [ "${PGTARGET}" -eq 14 ]; then rmdir /usr/local-pg14 /usr/local-pg15; fi
RUN if [ "${PGTARGET}" -eq 15 ]; then rmdir /usr/local-pg15; fi

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
