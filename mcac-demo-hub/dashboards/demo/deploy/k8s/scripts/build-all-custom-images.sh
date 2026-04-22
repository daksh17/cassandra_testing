#!/usr/bin/env bash
# Build every image the generated K8s manifests expect that are NOT pulled from public Docker Hub.
# Run from anywhere; uses paths under dashboards/demo (Compose-equivalent builds).
#
# After building (OrbStack / Docker Desktop: same engine as Kubernetes — usually no import step):
#   kubectl rollout restart deploy/kafka-connect deploy/hub-demo-ui deploy/nodetool-exporter -n demo-hub
#   kubectl rollout restart sts/cassandra -n demo-hub
# kind: load each image — see build-load-nodetool-exporter.sh pattern.
set -euo pipefail
DEMO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$DEMO_ROOT"

echo "=== 1/4 MCAC init (Cassandra initContainer) ==="
"$DEMO_ROOT/deploy/k8s/scripts/build-mcac-init-image.sh"

echo "=== 2/4 Hub demo UI ==="
docker build -t mcac-demo/hub-demo-ui:latest -f deploy/docker/realtime-orders-search-hub/demo-ui/Dockerfile deploy/docker/realtime-orders-search-hub/demo-ui

echo "=== 3/4 Kafka Connect (Debezium + Mongo sink) ==="
docker build -t mcac-demo/kafka-connect:2.7.3-mongo-sink -f deploy/docker/mongo-kafka/Dockerfile.connect deploy/docker/mongo-kafka

echo "=== 4/4 Nodetool exporter ==="
docker build -t demo-hub/nodetool-exporter:latest -f deploy/docker/nodetool-exporter/Dockerfile deploy/docker/nodetool-exporter

echo ""
echo "All custom images built. If kind/minikube, load them (example for kind):"
echo "  kind load docker-image mcac-demo/mcac-init:local"
echo "  kind load docker-image mcac-demo/hub-demo-ui:latest"
echo "  kind load docker-image mcac-demo/kafka-connect:2.7.3-mongo-sink"
echo "  kind load docker-image demo-hub/nodetool-exporter:latest"
echo "Then: kubectl rollout restart deployment/kafka-connect deployment/hub-demo-ui deployment/nodetool-exporter statefulset/cassandra -n demo-hub"
