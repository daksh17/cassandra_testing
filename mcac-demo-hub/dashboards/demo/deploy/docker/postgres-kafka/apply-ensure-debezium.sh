#!/usr/bin/env bash
# Patch primary for CDC when the volume predates replicator grants / publication (run from dashboards/demo).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$DEMO_ROOT"
docker compose exec -T postgresql-primary \
  env PGPASSWORD=postgres psql -U postgres -d demo -v ON_ERROR_STOP=1 -f - \
  < "$(dirname "$0")/ensure-debezium-cdc.sql"
echo "OK. Next: ./deploy/docker/postgres-kafka/register-connectors.sh"
