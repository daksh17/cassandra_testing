#!/usr/bin/env bash
# Deprecated name — forwards DBs + Grafana + Prometheus + hub-demo-ui. Prefer port-forward-demo-hub.sh.
exec "$(dirname "$0")/port-forward-demo-hub.sh" "$@"
