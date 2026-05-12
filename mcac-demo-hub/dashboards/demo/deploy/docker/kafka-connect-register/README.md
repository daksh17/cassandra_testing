# Kafka Connect REST (`curl` cheat sheet)

Scripts here register connectors against **Kafka Connect’s HTTP API** (default **`8083`**).

| Environment | Connect URL |
|-------------|-------------|
| Docker Compose (host) | `http://127.0.0.1:8083` |
| Kubernetes | Forward **`svc/kafka-connect`** → localhost (e.g. `./deploy/k8s/scripts/port-forward-demo-hub.sh`) |

```bash
CONNECT="${KAFKA_CONNECT_URL:-http://127.0.0.1:8083}"
CONNECT="${CONNECT%/}"
```

## Demo connector names

| Connector | Role |
|-----------|------|
| `pg-source-demo` | Debezium PostgreSQL source |
| `jdbc-sink-demo` | JDBC sink (Postgres) |
| `mongo-source-demo` | Debezium MongoDB source |
| `mongo-sink-demo` | Mongo sink |
| `mssql-source-demo` | Debezium SQL Server source |
| `mssql-jdbc-sink-demo` | JDBC sink (SQL Server subscriber) |

Registration helpers:

- **Postgres + Mongo:** `./register-all.sh "$CONNECT"`
- **All six (incl. MSSQL):** `DEMO_HUB_K8S=1 ./register-all-connectors.sh "$CONNECT"` (see script header for env vars)

---

## Cluster & plugins

```bash
# List connector names
curl -sS "${CONNECT}/connectors"

# Connector plugin classes installed on this worker
curl -sS "${CONNECT}/connector-plugins"

# Validate config for a plugin (example: Postgres — adjust keys to match your DB)
curl -sS -X PUT "${CONNECT}/connector-plugins/io.debezium.connector.postgresql.PostgresConnector/config/validate" \
  -H 'Content-Type: application/json' \
  -d '{"connector.class":"io.debezium.connector.postgresql.PostgresConnector","database.hostname":"postgresql-primary"}'
```

---

## Connector CRUD

```bash
NAME=pg-source-demo

# Create (JSON body must include "name" and "config", or POST config-only per Connect version — use POST /connectors with full body from registration scripts)
curl -sS -X POST "${CONNECT}/connectors" \
  -H 'Content-Type: application/json' \
  -d @connector.json

# Current configuration
curl -sS "${CONNECT}/connectors/${NAME}"

# Replace configuration (full config object, not wrapped in "config" — Connect merges by connector name in URL)
curl -sS -X PUT "${CONNECT}/connectors/${NAME}/config" \
  -H 'Content-Type: application/json' \
  -d @connector-config-only.json

# Remove connector
curl -sS -X DELETE "${CONNECT}/connectors/${NAME}"
```

---

## Status, pause, resume, restart

```bash
NAME=jdbc-sink-demo

curl -sS "${CONNECT}/connectors/${NAME}/status"

curl -sS -X PUT "${CONNECT}/connectors/${NAME}/pause"
curl -sS -X PUT "${CONNECT}/connectors/${NAME}/resume"

curl -sS -X POST "${CONNECT}/connectors/${NAME}/restart"
curl -sS -X POST "${CONNECT}/connectors/${NAME}/restart?includeTasks=true&onlyFailed=false"

curl -sS "${CONNECT}/connectors/${NAME}/tasks"
curl -sS "${CONNECT}/connectors/${NAME}/tasks/0/status"
curl -sS -X POST "${CONNECT}/connectors/${NAME}/tasks/0/restart"
```

---

## Topics (worker-dependent)

Some images expose active topics for a connector:

```bash
curl -sS "${CONNECT}/connectors/${NAME}/topics"
```

If this returns **404**, your Connect version or worker config does not expose that endpoint.

---

## Quick copies

```bash
curl -sS "${CONNECT}/connectors" | tr ',' '\n'
curl -sS "${CONNECT}/connectors/pg-source-demo/status"
curl -sS "${CONNECT}/connectors/jdbc-sink-demo/status"
```

---

## Runbook (general): sources, sinks, offsets, internal topics

This stack runs Connect against **one** Kafka cluster; Connect reads/writes **internal topics** on that same cluster unless you configure otherwise.

### A. Internal topics every operator should know

Worker-level settings (names vary by deployment):

| Topic role | Typical property | Purpose |
|------------|------------------|--------|
| **Configs** | `config.storage.topic` | Connector configs (compacted). |
| **Offsets** | `offset.storage.topic` | Per-connector/task **source** resume positions (LSN, binlog, resume tokens, …) and framework checkpoints. |
| **Status** | `status.storage.topic` | Task status heartbeats. |

Demo-hub uses prefixes like **`pgdemo_connect_configs`**, **`pgdemo_connect_offsets`**, **`pgdemo_connect_statuses`** — **all connectors on that worker share these topics**; records are distinguished by **key** (connector name + partition).

**Debezium** also creates **schema-history** topics (e.g. `*.schema-changes.internal`) configured per connector — separate from the three internal topics above.

Treat internal topics as **critical**: no arbitrary deletes without a runbook; compaction preserves latest record per key.

---

### B. Source connectors (Debezium-style)

**Data path:** external DB → Connect source task → **produces** to Kafka **data topics**.

**Progress:** stored in **`offset.storage.topic`** (not “consumer lag” on an input topic). Position semantics are **connector-specific** (Postgres LSN, Mongo resume token, SQL Server CDC LSN, …).

**Common operations**

| Goal | Approach |
|------|-----------|
| **Healthy resume** | Leave connector running; offsets advance automatically. |
| **Pause streaming** | `PUT …/connectors/{name}/pause` — DB CDC resources may still exist (e.g. replication slot). |
| **Stop tasks hard** | `PUT …/stop` if supported by Connect version, or **`DELETE` connector**. |
| **Replay / resnapshot (preferred)** | **`DELETE` connector** → fix DB-side CDC artifacts if required (slot, publication, etc.) → **`POST` connector** again with explicit **`snapshot.mode`** / vendor docs (e.g. `initial`). |
| **“Reset source offsets”** | Usually **not** done via `kafka-consumer-groups` on data topics. Either recreate connector + snapshot strategy, use vendor **signals** (newer Debezium), or **advanced**: edit/delete keys in **`offset.storage.topic`** / Connect offset REST (version-dependent). |

**Changing `topic.prefix`:** changes **where new rows are written** in Kafka; it does **not** by itself reset **`offset.storage.topic`** if the **connector name** is unchanged — you may continue from the same DB position while emitting under **new topic names** (forward-only changes unless snapshot/resnapshot).

---

### C. Sink connectors (JDBC / Mongo sink / …)

**Data path:** **consumes** configured **input topics** → writes to DB/document store/etc.

**Progress:** **Kafka consumer group**, convention **`connect-{connector-name}`** unless overridden (`consumer.override.group.id`, …).

**Common operations**

| Goal | Approach |
|------|-----------|
| **Pause processing** | `PUT …/pause` — may **not** remove consumer group membership (tools often still block offset edits). |
| **Allow offset reset** | **`STOP`** connector or **`DELETE`** connector → wait until consumer group has **no active members** (`Empty`). |
| **Reset consumer offsets** | `kafka-consumer-groups.sh --bootstrap-server … --group connect-{name} --topic … --reset-offsets --to-earliest|--to-latest|--to-datetime … **--execute**` or GUI (Kadeck). |
| **Resume** | `PUT …/resume` or **recreate** connector with same group/topic config. |

**Replay effect:** sink replays messages → downstream table may **UPSERT** (idempotent) or **duplicate** (append-only); plan accordingly.

---

### D. End-to-end checklist: reset sink offsets safely

1. **Identify** connector name, **input topic(s)**, consumer group **`connect-{connector-name}`**.
2. **`GET …/connectors/{name}/status`** — confirm tasks.
3. **Stop membership:** **`DELETE` connector** (or **`PUT …/stop`** if available); optional wait for group **Empty**.
4. **Reset offsets** (`kafka-consumer-groups` **--execute** or UI).
5. **Recreate** connector (same JSON as before) or **`POST`** registration script.
6. **Verify:** `GET …/status` → **RUNNING**; spot-check target store + lag.

---

### E. End-to-end checklist: “restart” source / resnapshot

1. **Document** connector JSON, DB user, **`snapshot.mode`**, replication slot / publication names (Postgres).
2. **`DELETE` connector** (and wait for tasks gone).
3. **DB hygiene:** drop or reuse replication slot per vendor guidance; fix publication/table filters if needed.
4. **`POST` connector** again (often with **`snapshot.mode=initial`** for full reload — confirm disk/topic impact).
5. **Verify:** new/expected **data topics**; **`GET …/status`**; confirm **`offset.storage.topic`** receives new commits (optional advanced inspection).

---

### F. When internal topics need surgery (last resort)

- **Symptom:** corrupt offset/config prevents start; impossible to fix via API alone.
- **Action:** with backups and change control, remove **specific compacted keys** for one connector in **`offset.storage.topic`** (and rarely **config** topic) using tooling that understands Connect’s wire format — **or** use offset-reset REST where your Connect version supports it.
- **Never** delete entire internal topics while connectors are running unless you intend to **rebuild the whole Connect cluster state**.

---

### G. Quick CLI references

```bash
CONNECT=http://127.0.0.1:8083
curl -sS "${CONNECT}/connectors"
curl -sS "${CONNECT}/connectors/jdbc-sink-demo/status"

# List consumer groups (Kafka install required on host)
kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 --list

# Describe lag for a sink
kafka-consumer-groups.sh --bootstrap-server 127.0.0.1:9092 \
  --group connect-jdbc-sink-demo --describe
```

---

## Observability: Kafka metrics & Grafana (demo hub)

Kafka **brokers** here are scraped via **danielqsj/kafka-exporter** (Prometheus job **`kafka_pgdemo`**, metric label **`kafka_cluster=pgdemo`**). Use this when CDC feels “stuck,” sinks lag, or topics stop growing.

### Dashboard (primary)

| Item | Value |
|------|--------|
| **JSON** | [`../../../../grafana/generated-dashboards/kafka-cluster-overview.json`](../../../../grafana/generated-dashboards/kafka-cluster-overview.json) |
| **UID** | **`demo-kafka-cluster`** |
| **Title** | **Kafka cluster (demo broker)** |

Open **Grafana** → browse/import that dashboard (Compose **`:3000`**, K8s via port-forward). Pick Prometheus datasource **Instance** that scrapes **`kafka-exporter-mcac:9308`** / job **`kafka_pgdemo`**.

### Panels — what to look at (symptoms → meaning)

| Panel | Metrics / idea | If it looks wrong |
|--------|----------------|-------------------|
| **Kafka brokers (exporter view)** | `kafka_brokers` | **0 or missing series** → exporter cannot reach broker (`kafka:9092` / advertised listeners / network). Fix broker/upstream before blaming Connect. |
| **Offset growth rate by topic** | `rate(kafka_topic_partition_current_offset[2m])` by topic | **Flat near zero** on **`demopg.*` / `demomongo.*`** while DB is changing → **source connector** stalled or not RUNNING. **Flat on `scenario.*`** → hub app not producing. |
| **Log end offset (sum by topic)** | end offset sum | **Not increasing** → same as above (no new writes to that topic). |
| **Consumer group lag** | `kafka_consumergroup_lag` | **High / climbing** for **`connect-<sink-name>`** → sink slow, down, or paused; DB destination bottleneck. Filter mentally by **group** (sink) vs unrelated consumers. |
| **Consumer lag sum** | `kafka_consumergroup_lag_sum` | Same story; compares **group × topic** totals. |
| **Consumer group members** | `kafka_consumergroup_members` | **0 members** for **`connect-…`** while connector says RUNNING → rebalance glitch or connector just restarted; **0 while PAUSED** → expected if consumer left group only after stop/delete. |
| **Under-replicated partitions** | `kafka_topic_partition_under_replicated_partition` | **&gt; 0** in multi-broker clusters → replication/ISR trouble (demo single broker often **0**). |
| **ISR gap** | replicas − in-sync replicas | Non-zero → replicas out of sync (cluster health). |
| **Non-preferred leader partitions** | leader vs preferred | Elevated → leadership imbalance after broker events (ops follow-up). |
| **Approx. log depth** | current offset − oldest offset | **Huge** → retention not trimming or very high volume; risk disk pressure (depends on broker retention settings). |

### Kafka Connect itself

This dashboard is **broker-oriented**, not Connect-JVM-oriented.

- **Connector health:** **`GET ${CONNECT}/connectors/<name>/status`** (tasks **FAILED**, traces).
- **Worker logs:** `kafka-connect` pod/container logs (OOM, timeouts, deserialization).
- **Sink replay / offset resets:** validate with **`kafka-consumer-groups --describe`** and **Consumer group lag** above for **`connect-<connector>`**.

### Prometheus (quick check)

**Targets:** job **`kafka_pgdemo`** should be **UP** (scrape **`kafka-exporter`**). Defined in **[`../../../../prometheus/prometheus.yaml`](../../../../prometheus/prometheus.yaml)** (`kafka-exporter-mcac:9308` in Compose; K8s uses generated scrape configs aligned with that job name).

---

## Notes

- **Restart query parameters** (`includeTasks`, `onlyFailed`) vary slightly by **Kafka Connect** version; if a call fails, check your worker image docs.
- **Kubernetes MSSQL + schema-history:** use **`DEMO_HUB_K8S=1`** so bootstrap servers and MSSQL schema apply match the cluster (see **`register-all-connectors.sh`**).
