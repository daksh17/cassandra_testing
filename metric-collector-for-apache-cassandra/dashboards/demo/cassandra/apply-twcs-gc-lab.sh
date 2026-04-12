#!/usr/bin/env bash
# Create demo_hub.lab_twcs_w2m_gc{30,60,90,120} — TWCS 2 min windows, varying gc_grace_seconds.
# Usage from dashboards/demo: ./cassandra/apply-twcs-gc-lab.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CQL="${ROOT}/cassandra/ensure-twcs-gc-lab.cql"
cd "${ROOT}"
docker compose exec -i -T cassandra cqlsh localhost 9042 < "${CQL}"
echo "TWCS gc_grace lab tables applied (2 min windows; gc_grace 30/60/90/120 s)."
