#!/usr/bin/env bash
# Create demo_hub.lab_twcs_w2m_gc{30,60,90,120} — TWCS 2 min windows, varying gc_grace_seconds.
# Usage from dashboards/demo: ./deploy/docker/cassandra/apply-twcs-gc-lab.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CQL="${SCRIPT_DIR}/ensure-twcs-gc-lab.cql"
cd "${DEMO_ROOT}"
docker compose exec -i -T cassandra cqlsh localhost 9042 < "${CQL}"
echo "TWCS gc_grace lab tables applied (2 min windows; gc_grace 30/60/90/120 s)."
