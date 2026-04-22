#!/usr/bin/env bash
# Init config server replica set only. Must finish BEFORE shard mongods start (shardsvr nodes
# with existing data contact configReplSet during startup; uninitialized config = deadlock).
set -euo pipefail

wait_mongo() {
  local host=$1
  local n=0
  until mongosh "mongodb://${host}:27017" --eval 'db.runCommand({ ping: 1 })' --quiet >/dev/null 2>&1; do
    n=$((n + 1))
    if [ "$n" -gt 120 ]; then
      echo "timeout waiting for ${host}"
      exit 1
    fi
    sleep 2
  done
}

for h in mongo-config1 mongo-config2 mongo-config3; do
  echo "waiting for ${h}..."
  wait_mongo "$h"
done

echo "init configReplSet (if needed)..."
mongosh "mongodb://mongo-config1:27017" --quiet --eval '
const ok = (() => {
  try {
    const s = rs.status();
    return s.ok === 1;
  } catch (e) {
    return false;
  }
})();
if (!ok) {
  rs.initiate({
    _id: "configReplSet",
    configsvr: true,
    members: [
      { _id: 0, host: "mongo-config1:27017" },
      { _id: 1, host: "mongo-config2:27017" },
      { _id: 2, host: "mongo-config3:27017" }
    ]
  });
}
'

echo "waiting for config PRIMARY (any member)..."
# mongo-config1 may become a secondary after election; require a PRIMARY in the set, not this host only.
n=0
until mongosh "mongodb://mongo-config1:27017" --quiet --eval \
  '(() => { try { const s = rs.status(); return s.ok === 1 && s.members.some(m => m.stateStr === "PRIMARY"); } catch (e) { return false; } })()' | grep -q '^true$'; do
  n=$((n + 1))
  if [ "$n" -gt 90 ]; then
    echo "timeout waiting for config PRIMARY (90 attempts). rs.status / hello:" >&2
    mongosh "mongodb://mongo-config1:27017" --quiet --eval \
      'try { printjson(rs.status()); } catch (e) { print("rs.status:", e.message); } try { printjson(db.hello()); } catch (e2) { print("hello:", e2.message); }' >&2 || true
    exit 1
  fi
  sleep 2
done

echo "config replica set ready."
