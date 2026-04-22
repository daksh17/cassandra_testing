# Demo-hub documentation (Docker Compose & Kubernetes)

The **demo-hub** stack is **one logical application**: the same services, in-cluster DNS names, and data paths whether you run **[`docker-compose.yml`](../docker-compose.yml)** on the host or apply **[`deploy/k8s/generated/all.yaml`](../deploy/k8s/generated/all.yaml)** on a cluster.

Use this folder for **what is common** to both runtimes. Use **`deploy/docker/`** for scripts and Docker build contexts, and **`deploy/k8s/`** for cluster operations (apply, port-forward, bootstrap Jobs).

| I want to… | Read |
|------------|------|
| **Hub UI, ports, Kafka Connect, CDC sources/sinks** | **[`hub-and-data-flow.md`](hub-and-data-flow.md)** |
| **What differs only between Compose and Kubernetes** | **[`compose-vs-kubernetes.md`](compose-vs-kubernetes.md)** |
| **Full demo index (long form, scenario index tables)** | **[`../README.md`](../README.md)** |
| **Run with Docker Compose** | **[`../deploy/docker/README.md`](../deploy/docker/README.md)** |
| **Run on Kubernetes** | **[`../deploy/k8s/README.md`](../deploy/k8s/README.md)** |

## Component guides (shared behavior)

Implementation (SQL, shell, Dockerfiles, hub UI) lives under **`deploy/docker/`**. These READMEs describe behavior that applies to **both** Compose and the generated K8s manifests unless **`compose-vs-kubernetes.md`** says otherwise.

| Area | Guide |
|------|--------|
| **Hub / reference scenario** | [`../deploy/docker/realtime-orders-search-hub/README.md`](../deploy/docker/realtime-orders-search-hub/README.md) · [scenario flow](../deploy/docker/realtime-orders-search-hub/scenario-flow/README.md) |
| **Cassandra + MCAC + nodetool exporter** | [`../deploy/docker/cassandra/README.md`](../deploy/docker/cassandra/README.md) |
| **Kafka / ZooKeeper / Connect image** | [`../deploy/docker/kafka/README.md`](../deploy/docker/kafka/README.md) |
| **PostgreSQL HA + Debezium + JDBC sink** | [`../deploy/docker/postgres-kafka/README.md`](../deploy/docker/postgres-kafka/README.md) |
| **Mongo sharded topology (init)** | [`../deploy/docker/mongo-sharded/README.md`](../deploy/docker/mongo-sharded/README.md) |
| **Mongo CDC + Kafka sink** | [`../deploy/docker/mongo-kafka/README.md`](../deploy/docker/mongo-kafka/README.md) |
| **Connector registration (all four)** | [`../deploy/docker/kafka-connect-register/register-all.sh`](../deploy/docker/kafka-connect-register/register-all.sh) |
| **Redis** | [`../deploy/docker/redis/README.md`](../deploy/docker/redis/README.md) |
| **OpenSearch** | [`../deploy/docker/opensearch/README.md`](../deploy/docker/opensearch/README.md) |
| **Prometheus / Grafana** | [`../deploy/docker/observability/README.md`](../deploy/docker/observability/README.md) |
| **Misc scripts** | [`../deploy/docker/scripts/README.md`](../deploy/docker/scripts/README.md) |

## Kubernetes-only references

| Topic | Where |
|--------|--------|
| Quick start, images, port-forward, troubleshooting | [`../deploy/k8s/README.md`](../deploy/k8s/README.md) |
| Bootstrap Jobs vs Compose init | [`../deploy/k8s/generated/README-jobs.md`](../deploy/k8s/generated/README-jobs.md) |
