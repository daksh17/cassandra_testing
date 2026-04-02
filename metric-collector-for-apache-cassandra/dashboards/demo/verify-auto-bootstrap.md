# Verifying auto_bootstrap on cassandra5

## 5th node not showing in nodetool status?

With **auto_bootstrap=true** the node must **stream data** from the cluster (bootstrap) before it shows as **UN** (Up, Normal). That can take several minutes. Until then it may show as **UJ** (Up, Joining) or not appear yet.

**Checks:**
1. **Is the container running?**  
   `docker ps | grep cassandra5`
2. **Logs (errors / bootstrap progress):**  
   `docker logs demo-cassandra5-1 2>&1`  
   Look for "Bootstrap", "Joining", "Unable to contact seed", or Java errors.
3. **Run nodetool again** after a few minutes; look for a 5th line (may be UJ then UN).

If the container keeps exiting, fix the error in the logs then recreate:  
`docker compose up -d --force-recreate cassandra5`

---

## "This node was decommissioned" (cassandra5 won't start)

If you see:
```text
This node was decommissioned and will not rejoin the ring unless cassandra.override_decommission=true has been set, or all existing data is removed and the node is bootstrapped again
```
the node’s local data still has the decommissioned flag (e.g. after `nodetool removenode`).

**Fix (either):**
1. **Override in compose** – `docker-compose.yml` for cassandra5 already has `-Dcassandra.override_decommission=true` in `JVM_EXTRA_OPTS`. Recreate the container: `docker compose up -d --force-recreate cassandra5`.
2. **Clean data and rejoin** – Remove the container and its volumes so the node starts with empty data and bootstraps: `docker compose stop cassandra5 && docker rm -f -v demo-cassandra5-1 && docker compose up -d cassandra5`.

**Note:** With `override_decommission=true` the node **rejoins with its old token and does not run bootstrap**, so **no data is streamed** to it. To get data onto the 5th node, use the clean-data approach (option 2) and optionally remove the override so the node does a full bootstrap (see “Data distribution not happening” below).

---

## Data distribution not happening on the 5th node

If cassandra5 is **UN** in `nodetool status` but has little or no data, it’s usually because:

- **Rejoin with `override_decommission=true`** – The node rejoined using its **previous token** and **did not bootstrap**. Cassandra does not stream data in that case; it only restores the node to the ring with the same token.

To get data onto the 5th node (full bootstrap and streaming):

1. **Remove cassandra5 from the ring** (from another node):
   ```bash
   docker exec demo-cassandra2-1 nodetool status   # get Host ID for 192.168.97.11
   docker exec demo-cassandra2-1 nodetool removenode <host_id>
   ```
2. **Remove the container and its volumes** (so the node has no local state):
   ```bash
   docker compose stop cassandra5
   docker rm -f -v demo-cassandra5-1
   ```
3. **Optional:** In `docker-compose.yml` remove `-Dcassandra.override_decommission=true` from cassandra5’s `JVM_EXTRA_OPTS` so it never tries to rejoin as “decommissioned”.
4. **Start cassandra5 again:**
   ```bash
   docker compose up -d cassandra5
   ```
   The node will start with empty data, get a new token, and **bootstrap** (stream its share of the ring from the other nodes). Wait until it shows **UN** and bootstrap has finished; then data will be distributed to it.

---

## "A node with address ... already exists" (cassandra5 won't start)

If you see:
```text
A node with address /192.168.97.11:7000 already exists, cancelling join. Use cassandra.replace_address if you want to replace this node.
```
the **cluster** still has that IP in the ring from a previous cassandra5. The new container gets the same IP and Cassandra refuses to join.

**Fix: remove the stale node from the cluster, then start cassandra5 again.**

1. **Get the host_id** for the old node (192.168.97.11):
   ```bash
   docker exec demo-cassandra2-1 nodetool status
   ```
   Find the line with `192.168.97.11` and note the **Host ID** (UUID). If it doesn’t appear, try:
   ```bash
   docker exec demo-cassandra2-1 nodetool describecluster
   ```

2. **Remove the dead node** (from any live node, use the Host ID from step 1):
   ```bash
   docker exec demo-cassandra2-1 nodetool removenode <host_id>
   ```
   Example: `nodetool removenode 92762826-c3af-4996-b079-7e8b583560f4`  
   If the node is still considered "Up", you may need to **assassinate** it first so the cluster marks it down:
   ```bash
   docker exec demo-cassandra2-1 nodetool assassinate 192.168.97.11
   ```
   Then run `nodetool removenode <host_id>`.

3. **Start cassandra5 again:**
   ```bash
   docker compose up -d cassandra5
   ```
   It should join and, with `auto_bootstrap=true`, bootstrap (stream data).

---

## Clean cassandra5 data and start the node fresh

If the 5th node has **old system keyspace / data on disk** (e.g. from a previous run or wrong cluster state), remove that data and start clean so it can bootstrap again.

**1. Stop and remove the container and its volumes**

From the demo directory (`dashboards/demo`):

```bash
docker compose stop cassandra5
docker rm -f -v demo-cassandra5-1
```

`-v` removes any anonymous volumes used by the container (e.g. `/var/lib/cassandra` in the official image), so the next start has no old keyspace data.

**2. Start cassandra5 again**

```bash
docker compose up -d cassandra5
```

The node will start with empty disk, contact the seeds, and bootstrap (stream data) if `auto_bootstrap=true`. Wait a few minutes, then check:

```bash
docker exec demo-cassandra2-1 nodetool status
```

You should see the 5th node as **UJ** (Joining) then **UN** (Normal) when bootstrap finishes.

**If you use a named volume for cassandra5 data** (e.g. you added `cassandra5_data:/var/lib/cassandra` in compose), clean it instead:

```bash
docker compose stop cassandra5
docker volume rm demo_cassandra5_data   # use the actual volume name from: docker volume ls | grep cassandra5
docker compose up -d cassandra5
```

---

## Setting token for a node (initial_token)

Token is not set in cassandra.yaml in this demo; you can set it via JVM for a specific node (e.g. cassandra5):

- **JVM override:** `-Dcassandra.initial_token=<token_value>` in that node’s `JVM_EXTRA_OPTS` in `docker-compose.yml`.
- **Same as:** `initial_token` in cassandra.yaml (single token); for multiple tokens use comma-separated values.

**Choosing a value:** Run `docker exec demo-cassandra2-1 nodetool ring` to see existing tokens. Pick a value that fits in the ring (e.g. between two existing tokens, or use an agreed split for a 5-node cluster). Example for one node: `-Dcassandra.initial_token=0` (change if 0 is already used).

---

Node **cassandra5** is started with `auto_bootstrap: false` (via JVM override `-Dcassandra.auto_bootstrap=false`).  
The setting is not written into `cassandra.yaml` when using the JVM override, so the **file** may still show the default. Use the checks below to verify the **effective** value.

## 1. Check the process (effective config)

The JVM flag is visible in the process command line:

```bash
docker exec demo-cassandra5-1 ps aux | grep -o '\-Dcassandra\.auto_bootstrap=[^ ]*'
```

Expected: `-Dcassandra.auto_bootstrap=false`

Or on Linux:

```bash
docker exec demo-cassandra5-1 cat /proc/1/cmdline | tr '\0' '\n' | grep auto_bootstrap
```

## 2. Check cassandra.yaml (file content)

What is actually in the config file:

```bash
docker exec demo-cassandra5-1 grep -E '^\s*auto_bootstrap|^\s*#\s*auto_bootstrap' /etc/cassandra/cassandra.yaml
```

- If you see `auto_bootstrap: true` or the key commented: the **file** says true; the **effective** value is still false because of the JVM override.
- If you want the **file** to show `auto_bootstrap: false`, you need to mount a custom `cassandra.yaml` or patch the file at startup (e.g. via an entrypoint script).

## 3. Check startup logs (behavior)

With `auto_bootstrap: false`, the node joins without streaming. Logs should **not** show a long bootstrap/streaming phase:

```bash
docker logs demo-cassandra5-1 2>&1 | grep -i bootstrap
```

You may see a line indicating that bootstrap is skipped or that the node joined without streaming.

## Summary

| Check              | What it shows                          |
|--------------------|----------------------------------------|
| `ps aux` / cmdline | Effective config (JVM override in use) |
| `cassandra.yaml`   | File content (may still say true)      |
| Startup logs       | No bootstrap/streaming on this node    |
