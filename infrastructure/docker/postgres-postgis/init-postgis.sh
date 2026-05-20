#!/usr/bin/env bash
set -e

echo "--- Enabling PostGIS extensions in ${POSTGRES_DB} ---"

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
    SELECT PostGIS_Version();
EOSQL

echo "--- PostGIS extensions enabled successfully ---"
