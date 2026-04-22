#!/usr/bin/env bash
# Append bulk documents to demo.demo_items via mongos (safe to run many times).
# Usage: ./seed-demo-items.sh [count]
#
# Default URI is the host port for mongos1 (see docker-compose). Run from your laptop:
#   ./mongo-kafka/seed-demo-items.sh 30
# From another container on the Compose network, set:
#   MONGOS_URI=mongodb://mongo-mongos1:27017 ./seed-demo-items.sh 30
set -euo pipefail

COUNT="${1:-30}"
# Host default: mongos1 published as 27025:27017. "mongo-mongos1" only resolves inside Docker.
MONGOS_URI="${MONGOS_URI:-mongodb://127.0.0.1:27025}"

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ]; then
  echo "usage: $0 [count]" >&2
  exit 1
fi

mongosh "${MONGOS_URI}/demo" --quiet --eval "
const n = ${COUNT};
const bulk = [];
const base = Date.now();
for (let i = 1; i <= n; i++) {
  bulk.push({ name: 'bulk-' + i + '-' + base + '-' + i, qty: i });
}
const r = db.demo_items.insertMany(bulk);
print('inserted ' + Object.keys(r.insertedIds).length + ' documents into demo.demo_items');
"
