FROM debian:stretch

ENV DEBIAN_FRONTEND noninteractive
ENV LANG=C.UTF-8

#Countries list in geofabrik format: "europe/monaco europe/malta", one or multiple countires
ENV NOMINATIM_COUNTRIES="europe/monaco europe/malta"
ENV NOMINATIM_INIT_THREADS=8

#Install packages
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install -y sudo apt-utils curl gnupg2 ca-certificates lsb-release apt-transport-https software-properties-common git&& \
    add-apt-repository "deb http://nginx.org/packages/debian `lsb_release -cs` nginx" && \
    add-apt-repository "deb https://packages.sury.org/php/ `lsb_release -cs` main" && \
    add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add - && \
    curl -fsSL https://packages.sury.org/php/apt.gpg | sudo apt-key add - && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && \
    apt-get update && apt-get install -y nginx php7.2-fpm php7.2 php7.2-pgsql php7.2-intl \
    postgresql-11 postgresql-server-dev-11 postgresql-11-postgis-2.5 postgresql-contrib-11 \
    build-essential cmake g++ libboost-dev libboost-system-dev libboost-filesystem-dev \
    libexpat1-dev zlib1g-dev libxml2-dev libbz2-dev libpq-dev libproj-dev \
    python3-pip libboost-python-dev osmosis osmium-tool && \
    apt-get clean && \
    pip3 install osmium && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* /var/tmp/*

#Configure nginx & php-fpm
RUN sed -i 's|worker_processes  1|worker_processes  auto|g' /etc/nginx/nginx.conf && \
    sed -i 's|^listen.owner =.*|listen.owner = nginx |g' /etc/php/7.2/fpm/pool.d/www.conf && \
    sed -i 's|^listen.group =.*|listen.group = nginx |g' /etc/php/7.2/fpm/pool.d/www.conf

#postgres default settings
ARG PG_CONF=/etc/postgresql/11/main/postgresql.conf
ARG PG_SHARED_BUFFERS=16GB
ARG PG_EFFECTIVE_CACHE_SIZE=48GB
ARG PG_MAINTENANCE_WORK_MEM=4GB
ARG PG_WORK_MEM=50MB
ARG PG_RANDOM_PAGE_COST=1.1
ARG PG_EFFECTIVE_IO_CONCURENCY=200
ARG PG_MIN_WAL_SIZE=1GB
ARG PG_MAX_WAL_SIZE=2GB
ARG PG_WORKER_PROCESSES=8
ARG PG_PARALLEL_WORKERS_PER_GATHER=4
ARG PG_PARALLEL_WORKERS=8

#update postgresql.conf and remove PGDATA directory
RUN echo "shared_buffers = $PG_SHARED_BUFFERS" >> $PG_CONF && \
    echo "effective_cache_size = $PG_EFFECTIVE_CACHE_SIZE" >> $PG_CONF && \
    echo "maintenance_work_mem = $PG_MAINTENANCE_WORK_MEM" >> $PG_CONF && \
    echo "work_mem = $PG_WORK_MEM" >> $PG_CONF && \
    echo "random_page_cost = $PG_RANDOM_PAGE_COST" >> $PG_CONF && \
    echo "effective_io_concurrency = $PG_EFFECTIVE_IO_CONCURENCY" >> $PG_CONF && \
    echo "min_wal_size = $PG_MIN_WAL_SIZE" >> $PG_CONF && \
    echo "max_wal_size = $PG_MAX_WAL_SIZE" >> $PG_CONF && \
    echo "max_worker_processes = $PG_WORKER_PROCESSES" >> $PG_CONF && \
    echo "max_parallel_workers_per_gather = $PG_PARALLEL_WORKERS_PER_GATHER" >> $PG_CONF && \
    echo "max_parallel_workers = $PG_PARALLEL_WORKERS" >> $PG_CONF && \
    rm -rf /var/lib/postgresql/11/main

#nominatim build args
ARG NOMINATIM_GIT_TAG=v3.3.0
ARG BUILD_JOBS=6

#Build nominatim
WORKDIR /app
RUN git clone --recursive https://github.com/openstreetmap/Nominatim ./src && \
    cd ./src && git checkout tags/$NOMINATIM_GIT_TAG && git submodule update --recursive --init && \
    mkdir build && cd build && cmake .. && make -j $BUILD_JOBS

#Load initial data
RUN curl http://www.nominatim.org/data/country_grid.sql.gz -o /app/src/data/country_osm_grid.sql.gz

EXPOSE 80

COPY default.conf /etc/nginx/conf.d/default.conf
COPY fastcgi_params /etc/nginx/fastcgi_params

COPY init.sh /app/init.sh
COPY start.sh /app/start.sh
COPY update.sh /app/update.sh
