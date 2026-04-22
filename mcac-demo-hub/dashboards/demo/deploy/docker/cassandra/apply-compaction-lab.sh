#!/usr/bin/env bash
# Create demo_hub.lab_twcs_sensor (TWCS) and demo_hub.lab_lcs_lookup (LCS).
# Usage from dashboards/demo: ./deploy/docker/cassandra/apply-compaction-lab.sh
# Optional: ./deploy/docker/cassandra/apply-compaction-lab.sh --with-samples
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CQL="${SCRIPT_DIR}/ensure-compaction-lab.cql"
SAMPLES="${SCRIPT_DIR}/insert-compaction-lab-samples.cql"
cd "${DEMO_ROOT}"
docker compose exec -i -T cassandra cqlsh localhost 9042 < "${CQL}"
echo "Compaction lab tables applied: demo_hub.lab_twcs_sensor (TWCS), demo_hub.lab_lcs_lookup (LCS)"
if [[ "${1:-}" == "--with-samples" ]]; then
  docker compose exec -i -T cassandra cqlsh localhost 9042 < "${SAMPLES}"
  echo "Sample rows inserted."
fi
