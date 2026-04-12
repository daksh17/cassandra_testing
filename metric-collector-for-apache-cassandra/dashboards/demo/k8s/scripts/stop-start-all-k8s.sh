#!/usr/bin/env bash
# Backward-compatible alias: full teardown + apply + bootstrap.
# Prefer: ./k8s/scripts/demo-hub.sh restart
#
# Optional: REGEN=1  SKIP_BOOTSTRAP=1  (same as demo-hub.sh)
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/demo-hub.sh" restart
