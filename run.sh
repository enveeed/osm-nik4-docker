#!/bin/bash

set -x

function createPostgresConfig() {
  cp /etc/postgresql/12/main/postgresql.custom.conf.tmpl /etc/postgresql/12/main/conf.d/postgresql.custom.conf
  sudo -u postgres echo "autovacuum = $AUTOVACUUM" >> /etc/postgresql/12/main/conf.d/postgresql.custom.conf
  cat /etc/postgresql/12/main/conf.d/postgresql.custom.conf
}

function setPostgresPassword() {
    sudo -u postgres psql -c "ALTER USER renderer PASSWORD '${PGPASSWORD:-renderer}'"
}

# Create shared directory if not exists
mkdir -p /shared/

# Paths: input is /shared/in, output is /shared/out

if [ "$#" -lt 1 ]; then
    echo "usage: <import|render [nik4 args]>"
    echo "commands:"
    echo "    import: Set up the database and import /shared/in"
    echo "    render: Runs nik4 to render the database contents to an image file."
    echo "environment variables:"
    echo "    THREADS: defines number of threads used for importing."
    exit 1
fi

if [ "$1" = "import" ]; then
    # Ensure that database directory is in right state
    chown postgres:postgres -R /var/lib/postgresql
    if [ ! -f /var/lib/postgresql/12/main/PG_VERSION ]; then
        sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl -D /var/lib/postgresql/12/main/ initdb -o "--locale C.UTF-8"
    fi

    # Initialize PostgreSQL
    createPostgresConfig
    service postgresql start
    sudo -u postgres createuser renderer
    sudo -u postgres createdb -E UTF8 -O renderer gis
    sudo -u postgres psql -d gis -c "CREATE EXTENSION postgis;"
    sudo -u postgres psql -d gis -c "CREATE EXTENSION hstore;"
    sudo -u postgres psql -d gis -c "ALTER TABLE geometry_columns OWNER TO renderer;"
    sudo -u postgres psql -d gis -c "ALTER TABLE spatial_ref_sys OWNER TO renderer;"
    setPostgresPassword

    # Import data
    sudo -u renderer osm2pgsql -r xml -d gis --create --slim -G --hstore --tag-transform-script /home/renderer/src/openstreetmap-carto/openstreetmap-carto.lua --number-processes ${THREADS:-4} -S /home/renderer/src/openstreetmap-carto/openstreetmap-carto.style /shared/in ${OSM2PGSQL_EXTRA_ARGS}

    # Create indexes
    sudo -u postgres psql -d gis -f indexes.sql

    service postgresql stop

    exit 0
fi

if [ "$1" = "render" ]; then
    # Clean /tmp
    rm -rf /tmp/*

    # Fix postgres data privileges
    chown postgres:postgres /var/lib/postgresql -R

    # Initialize PostgreSQL
    createPostgresConfig
    service postgresql start
    setPostgresPassword


    # Run while handling docker stop's SIGTERM
    stop_handler() {
        kill -TERM "$child"
    }
    trap stop_handler SIGTERM

    sudo -u postgres nik4 /home/renderer/src/openstreetmap-carto/mapnik.xml /tmp/output.png ${@:2} &
    child=$!
    wait "$child"

    # fallback on user ID 0 (root) if UID for output not provided
    UID=${UID:0}

    [[ -e /tmp/output.png ]] && cp /tmp/output.png /shared/out && chown $UID:$UID /shared/out
    service postgresql stop

    exit 0
fi

echo "invalid command"
exit 1
