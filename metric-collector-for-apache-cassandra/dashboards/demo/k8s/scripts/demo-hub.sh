#!/usr/bin/env bash
# Single entry point for the demo-hub Kubernetes stack: ordered start / stop / restart / status.
#
# Usage (from dashboards/demo):
#   ./k8s/scripts/demo-hub.sh start          # apply manifests + data bootstrap
#   ./k8s/scripts/demo-hub.sh stop           # delete namespace (full teardown)
#   ./k8s/scripts/demo-hub.sh restart        # stop then start (clean slate + bootstrap)
#   ./k8s/scripts/demo-hub.sh status         # quick pod overview
#
# Environment (optional):
#   NS=demo-hub              — namespace (default: demo-hub)
#   REGEN=1                  — run gen_demo_hub_k8s.py before apply (start/restart)
#   SKIP_BOOTSTRAP=1         — apply workloads only, skip Jobs (start/restart)
#   DELETE_NS_WAIT_SEC=240   — max seconds to wait for namespace removal on stop/restart (default 240)
#
set -euo pipefail

NS="${NS:-demo-hub}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GEN="$ROOT/generated"
ALL_YAML="$GEN/all.yaml"
DELETE_NS_WAIT_SEC="${DELETE_NS_WAIT_SEC:-240}"

usage() {
  cat <<'EOF'
demo-hub.sh — single entry point for the demo-hub Kubernetes stack

Usage (from dashboards/demo):
  ./k8s/scripts/demo-hub.sh start          apply generated/all.yaml + data bootstrap Jobs
  ./k8s/scripts/demo-hub.sh stop           delete namespace demo-hub (full teardown)
  ./k8s/scripts/demo-hub.sh restart        stop then start (clean slate + bootstrap)
  ./k8s/scripts/demo-hub.sh status         pods / deploy / sts / jobs snapshot

Environment:
  NS=demo-hub              namespace (default: demo-hub)
  REGEN=1                  run gen_demo_hub_k8s.py before apply (start/restart)
  SKIP_BOOTSTRAP=1         apply only, skip bootstrap Jobs (start/restart)
  DELETE_NS_WAIT_SEC=240   max wait for namespace removal on stop/restart
EOF
  exit "${1:-0}"
}

regen_manifests() {
  echo "=== Regenerate manifests (gen_demo_hub_k8s.py) ==="
  python3 "$ROOT/scripts/gen_demo_hub_k8s.py"
}

wait_namespace_gone() {
  local max_iter=$((DELETE_NS_WAIT_SEC / 2))
  echo "Waiting for namespace $NS to terminate (up to ${DELETE_NS_WAIT_SEC}s)..."
  for _ in $(seq 1 "$max_iter"); do
    if ! kubectl get ns "$NS" &>/dev/null; then
      echo "Namespace $NS is gone."
      return 0
    fi
    sleep 2
  done
  echo "Namespace $NS still exists after ${DELETE_NS_WAIT_SEC}s." >&2
  echo "Check: kubectl get ns $NS -o yaml | tail -40" >&2
  return 1
}

cmd_stop() {
  echo "=== STOP: delete namespace $NS ==="
  if ! kubectl get ns "$NS" &>/dev/null; then
    echo "Namespace $NS does not exist — nothing to delete."
    return 0
  fi
  kubectl delete namespace "$NS" --wait=false
  wait_namespace_gone
}

cmd_start() {
  if [[ ! -f "$ALL_YAML" ]]; then
    echo "Missing $ALL_YAML — run: python3 k8s/scripts/gen_demo_hub_k8s.py" >&2
    exit 1
  fi
  if [[ "${REGEN:-}" == "1" ]]; then
    regen_manifests
  fi

  echo "=== START: kubectl apply (single bundle) ==="
  kubectl apply -f "$ALL_YAML"

  if [[ "${SKIP_BOOTSTRAP:-}" == "1" ]]; then
    echo "SKIP_BOOTSTRAP=1 — skipping apply-data-bootstrap.sh"
    echo "Run later: $ROOT/scripts/apply-data-bootstrap.sh"
    return 0
  fi

  echo "=== Data bootstrap (Postgres / Cassandra / Mongo Jobs) ==="
  exec "$ROOT/scripts/apply-data-bootstrap.sh"
}

cmd_restart() {
  cmd_stop || exit 1
  cmd_start
}

cmd_status() {
  if ! kubectl get ns "$NS" &>/dev/null; then
    echo "Namespace $NS does not exist. Run: $0 start"
    exit 0
  fi
  echo "=== Namespace $NS ==="
  kubectl get pods -n "$NS" -o wide 2>/dev/null || true
  echo ""
  kubectl get deploy,sts,job -n "$NS" 2>/dev/null || true
}

main() {
  case "${1:-}" in
    start)    shift || true; cmd_start ;;
    stop)     shift || true; cmd_stop ;;
    restart)  shift || true; cmd_restart ;;
    status)   shift || true; cmd_status ;;
    -h|--help|help) usage 0 ;;
    "")
      echo "Missing command. Try: $0 start | stop | restart | status" >&2
      usage 1
      ;;
    *)
      echo "Unknown command: $1" >&2
      usage 1
      ;;
  esac
}

main "$@"
