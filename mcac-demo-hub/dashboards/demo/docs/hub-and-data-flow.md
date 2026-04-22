# Hub UI & data flow (Compose and Kubernetes)

This page describes **application behavior** that is the same in Docker Compose and in the **demo-hub** namespace on Kubernetes (after you reach services via published ports or port-forward).

## Hub UI

| URL | Purpose |
|-----|---------|
| **http://localhost:8888** | Home: single-order demo, links to stores |
| **http://localhost:8888/workload** | Tunable batch load across Postgres, Mongo, Redis, Cassandra, OpenSearch |
| **http://localhost:8888/scenario** | Multi-DB scenario (Faker, pipelines, Kafka topics from Python — independent of Kafka Connect unless you also register connectors) |

**Implementation:** [`deploy/docker/realtime-orders-search-hub/demo-ui/`](../deploy/docker/realtime-orders-search-hub/demo-ui/) (FastAPI). **Narrative + diagrams:** [`deploy/docker/realtime-orders-search-hub/README.md`](../deploy/docker/realtime-orders-search-hub/README.md), [`scenario-flow/README.md`](../deploy/docker/realtime-orders-search-hub/scenario-flow/README.md).

## Kafka Connect & CDC (four connectors)

The stack can run **Debezium Postgres source + JDBC sink** and **Debezium Mongo source + Mongo sink**. The hub’s “Single order” / “Workload” paths write **source** rows only:

- Postgres: **`public.demo_items`**
- Mongo: **`demo.demo_items`**

**Sink** tables/collections (**`demo_items_from_kafka`**, **`demo.demo_items_from_kafka`**) fill only when **all four connectors** are **RUNNING** (Kafka Connect → topics → sinks).

| Action | Command / note |
|--------|------------------|
| **Compose (automatic one-shot)** | Service **`kafka-connect-register`** runs [`deploy/docker/kafka-connect-register/register-all.sh`](../deploy/docker/kafka-connect-register/register-all.sh) |
| **Compose (manual from repo root `dashboards/demo`)** | `./deploy/docker/kafka-connect-register/register-all.sh` |
| **Kubernetes** | Port-forward Connect REST (see [`deploy/k8s/README.md`](../deploy/k8s/README.md)), then `DEMO_HUB_K8S=1 ./deploy/docker/kafka-connect-register/register-all.sh http://127.0.0.1:8083` (schema history uses in-cluster **`kafka:9092`**) |
| **Diagnose** | `./diagnose-kafka-connect.sh` (from `dashboards/demo`) |
| **Reset sinks / connectors** | `./reset-kafka-connect-demo.sh`, `./clean-kafka-connect-sinks.sh` |

## Typical service ports (host)

Published the same way in Compose; on K8s use **`port-forward-demo-hub.sh`** defaults unless you override **`LOCAL_*`** (see K8s README).

| Service | Default host port |
|---------|-------------------|
| Grafana | 3000 |
| Prometheus | 9090 |
| Hub UI | 8888 |
| Kafka (external) | 9092 |
| Kafka Connect REST | 8083 |
| Postgres primary | 15432 |
| Mongo mongos (first) | 27025 |
| Redis | 6379 |
| OpenSearch | 9200 |
| OpenSearch Dashboards | 5601 |

Cassandra CQL on the host uses mapped ports (**19442** / **19443** / **19444** in Compose); on K8s prefer port-forward to **`cassandra-0:9042`** or the optional NodePort recipe in the K8s README.

## Multi-DB scenario indexes (reference)

The long **per-store index tables** (Postgres BRIN/GIN/…, Mongo ESR, Cassandra secondary index) live in the main demo README so they stay next to the rest of the walkthrough:

→ **[Hub scenario indexes](../README.md#hub-scenario-indexes-multi-db-reference)**  
