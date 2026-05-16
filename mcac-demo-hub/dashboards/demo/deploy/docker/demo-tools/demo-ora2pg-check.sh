#!/usr/bin/env bash
# Connectivity checks from demo-tools to Postgres and Oracle (demo-hub).
set -euo pipefail

. /etc/profile.d/demo-hub-tools.sh

echo "=== Postgres (postgresql-primary:5432 / db demo) ==="
if psql "$DEMO_HUB_PG" -v ON_ERROR_STOP=1 -c "SELECT current_database(), current_user, version();" 2>&1; then
  echo "Postgres: OK"
else
  echo "Postgres: FAILED" >&2
fi

echo ""
echo "=== Oracle listener (oracle:1521) ==="
if nc -z -w 3 oracle 1521 2>/dev/null; then
  echo "Oracle TCP: OK (port open)"
else
  echo "Oracle TCP: FAILED (cannot reach oracle:1521)" >&2
fi

echo ""
echo "=== Oracle (TNS DEMO_ORACLE / FREEPDB1) via ora2pg ==="
export TNS_ADMIN="${TNS_ADMIN:-/etc/oracle/network/admin}"
if [[ ! -f "${TNS_ADMIN}/tnsnames.ora" ]]; then
  echo "Missing ${TNS_ADMIN}/tnsnames.ora" >&2
  exit 1
fi
echo "TNS_ADMIN=${TNS_ADMIN}"
grep -E '^[A-Z0-9_]+ *=' "${TNS_ADMIN}/tnsnames.ora" | sed 's/ *=.*//' | sed 's/^/  alias: /'

if [[ -z "${ORACLE_HOME:-}" || ! -d "${ORACLE_HOME}" ]]; then
  echo "Oracle Instant Client missing (ORACLE_HOME=${ORACLE_HOME:-unset}). Rebuild demo-tools image." >&2
  exit 1
fi

export ORA2PG_CONFIG="${ORA2PG_CONFIG:-/etc/ora2pg/ora2pg.conf}"
if ! perl -e 'use DBD::Oracle; print "DBD::Oracle OK\n"' 2>/dev/null; then
  echo "DBD::Oracle not loaded; rebuild demo-tools image." >&2
  exit 1
fi
if ora2pg -t SHOW_VERSION -c "$ORA2PG_CONFIG"; then
  echo "ora2pg Oracle (SHOW_VERSION): OK"
else
  echo "ora2pg Oracle (SHOW_VERSION): FAILED" >&2
  exit 1
fi
