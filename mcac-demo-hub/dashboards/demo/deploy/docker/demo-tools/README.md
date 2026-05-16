# demo-tools (client toolbox pod)

Ubuntu image with **psql**, **mongosh**, **cqlsh**, **redis-cli**, **curl**, **jq**, **opensearch-cli**, and **ora2pg**.

## Build

```bash
docker build -t demo-hub/demo-tools:latest -f deploy/docker/demo-tools/Dockerfile deploy/docker/demo-tools
```

Or: `./deploy/k8s/scripts/build-demo-tools-image.sh`

## K8s

Deployment **`demo-tools`** in namespace `demo-hub` — long-running pod for `kubectl exec`:

```bash
kubectl exec -it -n demo-hub deploy/demo-tools -- bash -l
# demo-psql, demo-mongosh, demo-ora2pg-check, demo-ora2pg-version, …
```

Connection hints: `/etc/profile.d/demo-hub-tools.sh`

## ora2pg + tnsnames.ora

| Target | Mechanism | Config |
|--------|-----------|--------|
| **Postgres** (`postgresql-primary`) | `psql` or ora2pg **`PG_DSN`** | Not in tnsnames — see `/etc/ora2pg/ora2pg.conf` |
| **Oracle** (`oracle` / `FREEPDB1`) | TNS alias **`DEMO_ORACLE`** | `/etc/oracle/network/admin/tnsnames.ora` |

```bash
export TNS_ADMIN=/etc/oracle/network/admin   # set in profile
cat "$TNS_ADMIN/tnsnames.ora"
demo-ora2pg-check                            # psql + TCP + ora2pg (if client present)
ora2pg -t SHOW_VERSION -c /etc/ora2pg/ora2pg.conf
ora2pg -t SHOW_TABLE -c /etc/ora2pg/ora2pg.conf
```

**`ora2pg.conf`** (image path `/etc/ora2pg/ora2pg.conf`):

- `ORACLE_DSN dbi:Oracle:DEMO_ORACLE` — uses tnsnames alias
- `PG_DSN dbi:Pg:dbname=demo;host=postgresql-primary;port=5432`

Port-forward from laptop: use alias **`DEMO_ORACLE_LOCAL`** (host `127.0.0.1`, port `16330`) in a copy of tnsnames or override `HOST` in a local file.

### Oracle Instant Client + DBD::Oracle

The image bundles **Oracle client libraries** (from `gvenzl/oracle-free:23-full-faststart` `dbhomeFree/lib` + `sdk`) at `/opt/oracle/instantclient` and **DBD::Oracle** for ora2pg. Image is larger (~500MB client libs) but works on **arm64** and **amd64** without Oracle yum repos.

```bash
demo-ora2pg-version    # ora2pg -t SHOW_VERSION
demo-ora2pg-tables
```

**Note:** No `sqlplus` in this image — use the **oracle** workload pod or host client for SQL*Plus.

Rebuild after Dockerfile changes: `./deploy/k8s/scripts/build-demo-tools-image.sh` then `kubectl rollout restart deployment/demo-tools -n demo-hub`.
