#!/usr/bin/env bash
# Apply hub scenario tables + indexes on a running Bitnami primary (existing volume).
# Usage: from anywhere: /path/to/mcac-demo-hub/dashboards/demo/deploy/docker/postgres-kafka/apply-scenario-hub-schema-indexes.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SQL="${SCRIPT_DIR}/04-scenario-hub-schema-indexes.sql"
cd "${DEMO_ROOT}"
# psql: -p is PORT, not password — never pass `-p postgres` (breaks args / misfires host psql if exec fails).
# -i: keep stdin open so the SQL file reaches psql inside the container.
PG_PASS="${POSTGRESQL_PASSWORD:-postgres}"
docker compose exec -i -T postgresql-primary \
  env PGPASSWORD="${PG_PASS}" \
  psql -h 127.0.0.1 -p 5432 -U postgres -d demo -v ON_ERROR_STOP=1 -f - \
  < "${SQL}"
echo "scenario hub schema + indexes applied on demo"
