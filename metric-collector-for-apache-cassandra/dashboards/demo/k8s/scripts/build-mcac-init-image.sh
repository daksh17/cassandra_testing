#!/usr/bin/env bash
# Build the MCAC agent image used by the Cassandra StatefulSet initContainer (not published to Docker Hub).
#
# From repo root this is: docker build -t mcac-demo/mcac-init:local .
# Run this script from anywhere; it finds the metric-collector repo root (four levels above k8s/scripts).
#
# After building:
#   - OrbStack / Docker Desktop Kubernetes: same image store as Docker — usually no extra step.
#   - kind: kind load docker-image mcac-demo/mcac-init:local
#   - minikube: minikube image load mcac-demo/mcac-init:local
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [[ ! -f "$REPO_ROOT/pom.xml" ]] || [[ ! -f "$REPO_ROOT/Dockerfile" ]]; then
  echo "error: expected metric-collector repo at $REPO_ROOT (need pom.xml + Dockerfile)." >&2
  exit 1
fi
echo "Building mcac-demo/mcac-init:local from $REPO_ROOT ..."
docker build -t mcac-demo/mcac-init:local "$REPO_ROOT"
echo "Done. Apply Cassandra manifests, then: kubectl rollout restart statefulset/cassandra -n demo-hub"
