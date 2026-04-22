#!/usr/bin/env bash
# Legacy wrapper: config init then shard init (same as two compose one-shot services).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/init-config-replica-set.sh"
bash "${SCRIPT_DIR}/init-shard-replica-sets.sh"
