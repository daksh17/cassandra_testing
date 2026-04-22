# Deploy (demo-hub)

**Common docs (Compose + K8s):** [`../docs/README.md`](../docs/README.md) · [`../docs/hub-and-data-flow.md`](../docs/hub-and-data-flow.md) · [`../docs/compose-vs-kubernetes.md`](../docs/compose-vs-kubernetes.md)

This folder groups **how you run** the multi-service demo:

| Subfolder | What |
|-----------|------|
| **[`k8s/`](k8s/README.md)** | **Kubernetes** — generated manifests, `demo-hub.sh`, port-forward, bootstrap Jobs. |
| **[`docker/`](docker/README.md)** | **Docker Compose assets** — Postgres/Mongo scripts, hub UI source, Kafka Connect image context, per-area READMEs (`docker-compose.yml` stays at **`../docker-compose.yml`**). |

Compose and the K8s generator both reference paths under **`docker/`** (as **`./deploy/docker/...`** from the demo directory).
