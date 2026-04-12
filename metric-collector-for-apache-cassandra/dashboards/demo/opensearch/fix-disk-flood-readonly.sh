#!/usr/bin/env bash
# Clear OpenSearch "flood stage" read-only blocks (local demo only).
# When the data volume's backing disk crosses the flood watermark, indices get
# read_only_allow_delete; Dashboards then fails on .kibana_* with HTTP 500.
# Free host / Docker VM disk first, then run this from dashboards/demo:
#   ./opensearch/fix-disk-flood-readonly.sh
set -euo pipefail
BASE_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "OpenSearch URL: ${BASE_URL}"
echo "1) Relax disk allocator checks for this single-node demo (persistent)..."
curl -sS -X PUT "${BASE_URL}/_cluster/settings" \
  -H 'Content-Type: application/json' \
  -d '{
    "persistent": {
      "cluster.routing.allocation.disk.threshold_enabled": false
    }
  }'
echo
echo "2) Remove read_only_allow_delete from all indices..."
curl -sS -X PUT "${BASE_URL}/*/_settings" \
  -H 'Content-Type: application/json' \
  -d '{
    "index.blocks.read_only_allow_delete": null
  }'
echo
echo "Done. If the UI still errors, restart Dashboards:"
echo "  docker compose restart opensearch-dashboards"
