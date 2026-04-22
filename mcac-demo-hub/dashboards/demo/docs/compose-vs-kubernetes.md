# Compose vs Kubernetes (demo-hub)

The **same** workloads and wiring are modeled in **`docker-compose.yml`** and in generated manifests under **`deploy/k8s/generated/`**. This page lists **operational differences** only.

| Topic | Docker Compose | Kubernetes (demo-hub) |
|--------|----------------|------------------------|
| **Credentials** | Environment variables / `.env` | **Secret** `demo-hub-credentials` |
| **Cassandra data** | Named volumes | **PVCs** on the StatefulSet |
| **Postgres / Mongo init** | Init containers / entrypoints / compose one-shots | **Jobs** (`postgres-demo-bootstrap`, `cassandra-demo-schema`, `mongo-demo-bootstrap`) via **`apply-data-bootstrap.sh`** |
| **Kafka Connect registration** | One-shot **`kafka-connect-register`** service | **Manual** after port-forward: `DEMO_HUB_K8S=1 ./deploy/docker/kafka-connect-register/register-all.sh http://127.0.0.1:8083` |
| **Debezium schema history broker** | **`kafka:29092`** (Compose network) | **`kafka:9092`** (in-cluster PLAINTEXT) — `DEMO_HUB_K8S=1` sets this in the register script |
| **Reach services from laptop** | Published ports on localhost | **`kubectl port-forward`** — [`deploy/k8s/scripts/port-forward-demo-hub.sh`](../deploy/k8s/scripts/port-forward-demo-hub.sh) |
| **Hub → Cassandra** | Service name **`cassandra`** | **Headless pod DNS** `cassandra-0..2.cassandra-headless...` (avoids driver flake during ring bring-up) |
| **Extras** | — | Optional **Ingress**, **PDB**, **HPA**, **NetworkPolicy**, **CronJob** in generated YAML |

**How to run**

- Compose: [`../deploy/docker/README.md`](../deploy/docker/README.md) · **`./start-full-stack.sh`**
- Kubernetes: [`../deploy/k8s/README.md`](../deploy/k8s/README.md) · **`./deploy/k8s/scripts/demo-hub.sh start`**

**Shared application docs:** [`README.md`](README.md) · [`hub-and-data-flow.md`](hub-and-data-flow.md)
