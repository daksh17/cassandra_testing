# Docker / Compose (demo-hub)

**Same application on Kubernetes:** see [`../../docs/README.md`](../../docs/README.md) (common index), [`../../docs/hub-and-data-flow.md`](../../docs/hub-and-data-flow.md), [`../../docs/compose-vs-kubernetes.md`](../../docs/compose-vs-kubernetes.md).

The **Docker Compose** stack is defined in the **parent directory**:

- **[`../../docker-compose.yml`](../../docker-compose.yml)** — all services (Cassandra, Kafka, Postgres, Mongo, Redis, OpenSearch, Prometheus, Grafana, hub UI, …).
- **[`../../start-full-stack.sh`](../../start-full-stack.sh)** — recommended first run (sets `PROJECT_VERSION`, builds local images, `docker compose up`).
- **[`../../.env`](../../.env)** (if present) — optional Compose env overrides.

## Layout

`docker-compose.yml` stays at **`dashboards/demo/`** so **`../prometheus`**, **`../grafana`**, **`../../config`**, and **`build: ../../`** (MCAC) keep working. **Compose assets** (Postgres/Mongo SQL & scripts, hub UI, Kafka Connect build context, per-service READMEs) live in **this directory** and are referenced as **`./deploy/docker/...`** from that compose file.

**Kubernetes** manifests live under **`../k8s/`** (sibling of this folder).

See also: **[`../../README.md`](../../README.md)** (full demo index) and **[`../k8s/README.md`](../k8s/README.md)** (cluster runbook).
