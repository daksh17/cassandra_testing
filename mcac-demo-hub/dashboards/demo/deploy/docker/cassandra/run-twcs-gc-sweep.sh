#!/usr/bin/env bash
# Run the same row load against all four lab tables (gc_grace 30/60/90/120 s), TWCS windows = 2 min.
# Usage from dashboards/demo:
#   pip install cassandra-driver   # once on the host
#   ./deploy/docker/cassandra/apply-twcs-gc-lab.sh
#   ROWS=50000 ./deploy/docker/cassandra/run-twcs-gc-sweep.sh
#
# Uses host 127.0.0.1:19442 by default (override: HOSTS=... PORT=...).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "${DEMO_ROOT}"
ROWS="${ROWS:-20000}"
HOSTS="${HOSTS:-127.0.0.1}"
PORT="${PORT:-19442}"
export PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH:-}"

for gc in 30 60 90 120; do
  echo ""
  echo "========== lab_twcs_w2m_gc${gc} (TWCS 2 min, gc_grace ${gc}s) =========="
  python3 "${SCRIPT_DIR}/load_twcs_gc_lab.py" \
    --hosts "${HOSTS}" \
    --port "${PORT}" \
    --gc "${gc}" \
    --rows "${ROWS}"
done
echo ""
echo "Sweep done. Compare: nodetool tablestats demo_hub lab_twcs_w2m_gc30 (etc.) and compactionstats."
