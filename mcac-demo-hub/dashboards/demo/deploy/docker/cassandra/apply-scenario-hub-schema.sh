#!/usr/bin/env bash
# Apply demo_hub.scenario_timeline + event_type index on a running Cassandra node (existing cluster).
# Usage: from dashboards/demo — ./deploy/docker/cassandra/apply-scenario-hub-schema.sh
# Uses the first Cassandra service; schema propagates to the ring.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CQL="${SCRIPT_DIR}/ensure-scenario-hub.cql"
cd "${DEMO_ROOT}"
docker compose exec -i -T cassandra cqlsh localhost 9042 < "${CQL}"
echo "Cassandra demo_hub scenario_timeline + index applied"
