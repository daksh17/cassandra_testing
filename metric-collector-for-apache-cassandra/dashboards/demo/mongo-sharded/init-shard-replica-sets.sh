#!/usr/bin/env bash
# Init shard replica sets tic / tac / toe (single node each). Runs after shard containers are up.
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

for h in mongo-shard-tic mongo-shard-tac mongo-shard-toe; do
  echo "waiting for ${h}..."
  wait_mongo "$h"
done

for spec in "tic:mongo-shard-tic" "tac:mongo-shard-tac" "toe:mongo-shard-toe"; do
  IFS=: read -r rsname host <<<"$spec"
  echo "init replica set ${rsname} on ${host}..."
  mongosh "mongodb://${host}:27017" --quiet --eval '
const rsName = "'"${rsname}"'";
const h = "'"${host}:27017"'";
const ok = (() => {
  try {
    return rs.status().ok === 1;
  } catch (e) {
    return false;
  }
})();
if (!ok) {
  rs.initiate({ _id: rsName, members: [{ _id: 0, host: h }] });
}
'
  echo "waiting for PRIMARY on ${rsname}..."
  uri="mongodb://${host}:27017"
  n=0
  until mongosh "$uri" --quiet --eval \
    'const h = db.hello(); h.isWritablePrimary === true || h.ismaster === true' | grep -q '^true$'; do
    n=$((n + 1))
    if [ "$n" -gt 90 ]; then
      echo "timeout waiting for PRIMARY on ${rsname}. hello / rs.status:" >&2
      mongosh "$uri" --quiet --eval 'try { printjson(rs.status()); } catch (e) { print(e.message); } printjson(db.hello());' >&2 || true
      exit 1
    fi
    sleep 2
  done
done

echo "shard replica sets ready."
