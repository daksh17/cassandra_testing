#!/usr/bin/env bash
# First init only (docker-entrypoint-initdb.d on primary).
# pg_cron metadata lives in cron.database_name (see POSTGRESQL_EXTRA_FLAGS: cron.database_name=postgres).
# Same auth pattern as 03-pg-stat-statements.sh — persisted clusters often require password for local connections.
set -euo pipefail
export PGPASSWORD="${POSTGRESQL_PASSWORD:?}"
PGU="${POSTGRESQL_USERNAME:?}"
psql -v ON_ERROR_STOP=1 -U "$PGU" -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
psql -v ON_ERROR_STOP=1 -U "$PGU" -d demo -c "CREATE EXTENSION IF NOT EXISTS pg_repack;"
psql -v ON_ERROR_STOP=1 -U "$PGU" -d demo -c "CREATE EXTENSION IF NOT EXISTS pg_partman;"
