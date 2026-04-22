# How This Cassandra Demo Works (Simple Step-by-Step)

**Short key (read in order):**

| § | Topic | In one line |
|---|--------|-------------|
| 1 | docker-compose | What the recipe runs (containers, network, ports). |
| 2 | Cassandra image | What the box is; how it reads env and builds the `java` command. |
| 3 | JVM_EXTRA_OPTS | Extra flags we pass to the Java process (the image appends them). |
| 4 | Each option | What every part of JVM_EXTRA_OPTS does in plain words. |
| 5 | How image uses it | Env → entrypoint → full `java` command. |
| 6 | Other pieces | Volumes, env vars, ports, depends_on in one place. |
| 7 | One picture | Flow from `docker compose up` to Cassandra running. |

---

## 1. What is the docker-compose file doing?

Think of **docker-compose** as a recipe. It says: "run these containers, give them these settings, and connect them on one network."

When you run `docker compose up`, it:

1. **Starts several "services" (containers):**
   - **prometheus** – collects numbers (metrics) from the Cassandra nodes
   - **grafana** – shows dashboards and graphs from those numbers
   - **cassandra**, **cassandra2**, **cassandra3** – 3 Cassandra nodes that form one cluster
   - **nodetool-exporter** – turns `nodetool` output into metrics for Prometheus
   - **stress** – optional load (KeyValue) against the cluster for the demo
   - **mcac** – build step that prepares the MCAC agent files

2. **Puts them on the same network** (`demo_net`) so they can talk to each other by name (e.g. `cassandra`, `cassandra2`).

3. **Exposes some ports** so you can reach them from your laptop (e.g. 19442 for CQL on node 1, 3000 for Grafana).

---

## 2. What is the "Cassandra image"?

- **Image** = a snapshot of an OS + installed software (here: Linux + Cassandra).
- **`cassandra:4.0`** = the official Apache Cassandra 4.0 image from Docker Hub.

When the container starts, the image’s **entrypoint** (startup script) roughly does:

1. Read **environment variables** (e.g. `CASSANDRA_SEEDS`, `MAX_HEAP_SIZE`, **`JVM_EXTRA_OPTS`**).
2. Build the real **config** (e.g. write or adjust `cassandra.yaml` from those variables).
3. Build the **Java command** that will run Cassandra (including JVM options).
4. Run that command: **`java ... <lots of -D options> ... -jar cassandra.jar`** (conceptually).

So: **environment variables** in docker-compose are how we change how Cassandra and its JVM run, without editing files inside the image.

---

## 3. What is JVM_EXTRA_OPTS?

- **JVM** = Java Virtual Machine. Cassandra is a Java program; the JVM is the process that runs it.
- **OPTS** = options (flags) we pass to that process.
- **EXTRA** = “in addition to” the options the image already uses.

So:

- The image already passes a lot of `-D...` and other options to the JVM (heap size, paths, etc.).
- **`JVM_EXTRA_OPTS`** is an **environment variable** that the image’s startup script **appends** to that list.
- Whatever you put in `JVM_EXTRA_OPTS` is added to the `java` command when Cassandra starts.

So in one sentence: **JVM_EXTRA_OPTS = extra flags we give to the Java process that runs Cassandra.**

---

## 4. What each part of JVM_EXTRA_OPTS does (in this demo)

In the compose file you have one long string. Here it is split and explained in simple words:

| Option | Meaning in simple words |
|--------|-------------------------|
| **`-javaagent:/mcac/lib/datastax-mcac-agent-....jar`** | “Before starting Cassandra, load this extra Java library (the MCAC agent). It will collect metrics from Cassandra and expose them (e.g. for Prometheus).” |
| **`-Dcassandra.consistent.rangemovement=false`** | “Don’t do strict range movement.” (Helps in demos so the cluster comes up quickly.) |
| **`-Dcassandra.ring_delay_ms=100`** | “Wait only 100 ms between ring checks.” (Makes the demo cluster form faster.) |
| **`-Dcassandra.jmx.remote.authenticate=false`** | “JMX (what nodetool uses) should not require a password.” (So nodetool and the nodetool-exporter can connect without credentials.) |
| **`-Dcom.sun.management.jmxremote.authenticate=false`** | Same idea, but for the standard Java JMX – “no password for JMX.” |
| **`-Dcom.sun.management.jmxremote.ssl=false`** | “Don’t use SSL for JMX.” (So connections work simply in the demo.) |
| **`-Dcassandra.auto_bootstrap=...`** | In older compose versions a 5th node could set bootstrap behavior; the slimmed demo uses three nodes with default bootstrap. |

So: **JVM_EXTRA_OPTS** is how we tell the JVM (and Cassandra) to enable the MCAC agent, speed up the demo, and disable JMX auth/SSL.

---

## 5. How does the image use JVM_EXTRA_OPTS?

Flow in simple steps:

1. You set in docker-compose:
   ```yaml
   environment:
     JVM_EXTRA_OPTS: '-javaagent:... -Dcassandra....'
   ```

2. When the container starts, the image’s **entrypoint script** runs.

3. It builds the full Java command, something like:
   ```text
   java <default opts from image> <opts from other env vars> $JVM_EXTRA_OPTS -jar cassandra.jar
   ```

4. So your **extra** options are literally appended to the `java` command. No need to edit `cassandra-env.sh` or yaml for these – the image is designed to take them from the environment.

---

## 6. How do the other pieces in the compose fit?

- **`image: cassandra:4.0`**  
  Use this image to run the process.

- **`volumes:`**
  - **`mcac_data:/mcac`** – Persistent storage for MCAC (and shared data the image may use under `/mcac`).
  - **`../../config:/mcac/config:ro`** – Your MCAC config (what to collect) is mounted read-only at `/mcac/config`. The **agent** (loaded via `-javaagent` in JVM_EXTRA_OPTS) reads from here.

- **`environment:`**
  - **`CASSANDRA_SEEDS`** – Which nodes to contact first to join the cluster (e.g. `cassandra,cassandra2`).
  - **`MAX_HEAP_SIZE` / `HEAP_NEWSIZE`** – Memory for the JVM (the image turns these into `-Xmx` / `-Xmn`-style options).
  - **`LOCAL_JMX: "no"`** – “Listen for JMX on the network, not only localhost,” so nodetool and the exporter can connect.
  - **`JVM_EXTRA_OPTS`** – As above: extra flags for the Java process (MCAC agent, JMX no auth, etc.).

- **`ports:`**  
  Map container ports to your machine (e.g. `19442:9042` = CQL on node 1, `19443:9042` on node 2, etc.).

- **`depends_on`**  
  Start order: e.g. cassandra2 after cassandra is healthy, cassandra3 after cassandra2, etc.

So: **the image** runs Cassandra; **environment variables** (including **JVM_EXTRA_OPTS**) tell it how to run; **volumes** give it config and persistence; **networks and ports** let the nodes and tools talk to each other and to you.

---

## 7. One picture in words

```text
docker-compose up
    ↓
For each Cassandra service:
    ↓
Start container from image "cassandra:4.0"
    ↓
Entrypoint reads env (JVM_EXTRA_OPTS, CASSANDRA_SEEDS, ...)
    ↓
Builds:  java [default opts] [JVM_EXTRA_OPTS] -jar cassandra
    ↓
JVM starts → loads -javaagent (MCAC) → starts Cassandra
    ↓
Cassandra reads config (including from /mcac/config) and joins the cluster
```

So: **JVM_EXTRA_OPTS** is simply “the extra options we pass to the Java process that runs Cassandra,” and the image is built to take that from the environment and append it to the `java` command. The rest of the compose file (volumes, ports, env vars, depends_on) just configures that same process and the way it connects to the rest of the demo stack.
