#!/usr/bin/env bash
# Apply ESR-style / partial / text indexes in DB demo (mongosh script).
# Same as mongo-kafka-prepare tail; use when Mongo is up but you skipped prepare or changed indexes.
# Usage: from dashboards/demo — ./deploy/docker/mongo-kafka/apply-demo-indexes.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
JS="${SCRIPT_DIR}/demo-indexes.js"
cd "${DEMO_ROOT}"
# mongosh does not treat stdin as a script reliably; copy into the mongos container, then --file.
docker compose cp "${JS}" mongo-mongos1:/tmp/demo-indexes.js
docker compose exec -T mongo-mongos1 \
  mongosh "mongodb://127.0.0.1:27017" --quiet --file /tmp/demo-indexes.js
echo "Mongo demo indexes applied (scenario_products, demo_items*, etc.)"
