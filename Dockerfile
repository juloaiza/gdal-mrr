# Python 3.7.7
FROM python:3.7.7-slim-stretch as gdal

# author of file
LABEL maintainer="Julian Loaiza <julian.loaiza1@t-mobile.com>"

#GDAL version 3.0.0-mrr
ENV GDAL_VERSION=3.0.0 \
    SOURCE_DIR="/usr/local/src/python-gdal"

#Copy MRR SDK
COPY ./MRRGDALBinaries /usr/local/lib/

# Get GDAL-MRR source
COPY ./gdal ${SOURCE_DIR}/gdal-${GDAL_VERSION}

RUN \
    # Install runtime dependencies
    apt-get update \
    && apt-get install -y --no-install-recommends \
    unzip \
    build-essential \
    wget \
    automake libtool pkg-config libsqlite3-dev sqlite3 \
    libpq-dev \
    libcurl4-gnutls-dev \
    libproj-dev \
    libxml2-dev \
    libgeos-dev \
    libnetcdf-dev \
    libpoppler-dev \
    libspatialite-dev \
    libhdf4-alt-dev \
    libhdf5-serial-dev \
    libopenjp2-7-dev \
    && rm -rf /var/lib/apt/lists/* \
    \
    # Install numpy
    && pip install numpy\
    # Build against PROJ master (which will be released as PROJ 6.0)
    && wget "http://download.osgeo.org/proj/proj-6.0.0.tar.gz" \
    && tar -xzf "proj-6.0.0.tar.gz" \
    && mv proj-6.0.0 proj \
    && echo "#!/bin/sh" > proj/autogen.sh \
    && chmod +x proj/autogen.sh \
    && cd proj \
    && ./autogen.sh \
    && CXXFLAGS='-DPROJ_RENAME_SYMBOLS' CFLAGS='-DPROJ_RENAME_SYMBOLS' ./configure --disable-static --prefix=/usr/local \
    && make -j"$(nproc)" \
    && make -j"$(nproc)" install \
    # Rename the library to libinternalproj
    && mv /usr/local/lib/libproj.so.15.0.0 /usr/local/lib/libinternalproj.so.15.0.0 \
    && rm /usr/local/lib/libproj.so* \
    && rm /usr/local/lib/libproj.la \
    && ln -s libinternalproj.so.15.0.0 /usr/local/lib/libinternalproj.so.15 \
    && ln -s libinternalproj.so.15.0.0 /usr/local/lib/libinternalproj.so \
    \
    # Compile and install GDAL
    && cd "${SOURCE_DIR}/gdal-${GDAL_VERSION}" \
    && export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
    && ./configure \
    --with-python \
    --with-curl \
    --with-openjpeg \
    --without-libtool \
    --with-proj=/usr/local \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    \
    # Install Python bindings as standalone module via pip
    && pip install GDAL==${GDAL_VERSION} \
    && cd /usr/local \
    \
    # Clean up
    && apt-get update -y \
    && apt-get remove -y --purge build-essential wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf "${SOURCE_DIR}"
FROM gdal

# Working directory
WORKDIR /usr/app

RUN pip install numexpr

#docker build -t egis/gdal-mrr .