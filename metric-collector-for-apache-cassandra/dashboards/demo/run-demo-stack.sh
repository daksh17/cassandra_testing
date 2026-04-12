#!/usr/bin/env bash
# Build local images and start the full MCAC demo stack (Docker Compose).
# This is the supported way to "run everything"; see k8s/README.md for Kubernetes limitations.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${SCRIPT_DIR}"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-demo-hub}"
if [[ -z "${PROJECT_VERSION:-}" ]]; then
  PROJECT_VERSION="$(grep '<revision>' "${REPO_ROOT}/pom.xml" | sed -E 's/(<\/?revision>|[[:space:]])//g')"
  export PROJECT_VERSION
fi

if ! docker info >/dev/null 2>&1; then
  echo "error: Docker is not running or not reachable." >&2
  exit 1
fi

echo "COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}"
echo "PROJECT_VERSION=${PROJECT_VERSION}"
echo "Building services that use local Dockerfile / custom tags..."
docker compose build mcac kafka-connect hub-demo-ui nodetool-exporter

echo "Starting all services..."
docker compose up -d

echo ""
docker compose ps
echo ""
echo "Stack is starting. When healthy:"
echo "  Grafana http://localhost:3000  Prometheus http://localhost:9090  Hub UI http://localhost:8888"
echo "For a clean restart (down + cleanup + up), use: ./start-full-stack.sh"
