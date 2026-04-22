#!/usr/bin/env bash
# Build nodetool-exporter (same Dockerfile as Compose) and load it into a local cluster.
# Requires: Docker. For kind: kind CLI. For minikube: minikube.
set -euo pipefail

DEMO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
IMAGE="demo-hub/nodetool-exporter:latest"

docker build -t "${IMAGE}" -f "${DEMO_ROOT}/deploy/docker/nodetool-exporter/Dockerfile" "${DEMO_ROOT}/deploy/docker/nodetool-exporter"
echo "Built ${IMAGE}"

if command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -q .; then
  for c in $(kind get clusters); do
    echo "Loading into kind cluster: ${c}"
    kind load docker-image "${IMAGE}" --name "${c}"
  done
elif command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
  echo "Loading into minikube"
  minikube image load "${IMAGE}"
else
  echo "No kind cluster or minikube detected. Load manually, e.g.:"
  echo "  kind load docker-image ${IMAGE}"
  echo "  minikube image load ${IMAGE}"
fi

echo "Restart the deployment if it was already failing: kubectl rollout restart deploy/nodetool-exporter -n demo-hub"
