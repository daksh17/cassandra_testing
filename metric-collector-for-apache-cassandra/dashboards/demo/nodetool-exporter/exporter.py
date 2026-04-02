#!/usr/bin/env python3
"""
Nodetool exporter: runs nodetool against each Cassandra host, parses output,
and exposes Prometheus metrics on :9104/metrics for Grafana dashboards.
"""
import os
import re
import subprocess
import sys

try:
    from prometheus_client import Gauge, generate_latest, REGISTRY, CONTENT_TYPE_LATEST
except ImportError:
    print("Install: pip install prometheus_client", file=sys.stderr)
    sys.exit(1)

from http.server import HTTPServer, BaseHTTPRequestHandler

CASSANDRA_HOSTS = [
    h.strip() for h in os.getenv("CASSANDRA_HOSTS", "cassandra,cassandra2,cassandra3").split(",")
    if h.strip()
]
LISTEN_PORT = int(os.getenv("NODETOOL_EXPORTER_PORT", "9104"))

# Metrics (all Gauges so we can set absolute values on each scrape)
nt_up = Gauge("nodetool_up", "1 if nodetool could reach the host", ["host"])
nt_status_state = Gauge("nodetool_status_state", "1=UN, 0=DN, -1=other", ["host"])
nt_status_load_bytes = Gauge("nodetool_status_load_bytes", "Load in bytes from nodetool status", ["host"])
nt_compaction_pending = Gauge("nodetool_compaction_pending_tasks", "Pending compaction tasks", ["host"])
nt_compaction_active = Gauge("nodetool_compaction_active_tasks", "Active compaction tasks", ["host"])
nt_tpstats_active = Gauge("nodetool_tpstats_active", "Thread pool active count", ["host", "pool"])
nt_tpstats_pending = Gauge("nodetool_tpstats_pending", "Thread pool pending count", ["host", "pool"])
nt_tpstats_completed = Gauge("nodetool_tpstats_completed_total", "Thread pool completed tasks", ["host", "pool"])
nt_cluster_nodes = Gauge("nodetool_cluster_nodes_total", "Total number of nodes in cluster")


def run_nodetool(host, *args):
    cmd = ["nodetool", "-h", host, "-p", "7199"] + list(args)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return r.returncode == 0, r.stdout or "", r.stderr or ""
    except Exception:
        return False, "", ""


def parse_status(host, stdout):
    for line in stdout.splitlines():
        line = line.strip()
        if not line or "Datacenter" in line or line.startswith("=="):
            continue
        parts = line.split()
        if len(parts) < 4:
            continue
        state, load_str = parts[0], parts[2]
        state_val = 1 if state == "UN" else (0 if state == "DN" else -1)
        nt_status_state.labels(host=host).set(state_val)
        load_bytes = 0
        m = re.match(r"([\d.]+)\s*(KiB|MiB|GiB)?", load_str.replace(",", ""))
        if m:
            val = float(m.group(1))
            unit = (m.group(2) or "B").lower()
            if unit == "kib":
                val *= 1024
            elif unit == "mib":
                val *= 1024 * 1024
            elif unit == "gib":
                val *= 1024 * 1024 * 1024
            load_bytes = int(val)
        nt_status_load_bytes.labels(host=host).set(load_bytes)
        break


def parse_compactionstats(host, stdout):
    pending = active = 0
    for line in stdout.splitlines():
        if "pending tasks" in line.lower():
            m = re.search(r"(\d+)", line)
            if m:
                pending = int(m.group(1))
        if "active" in line.lower() and "compaction" in line.lower():
            m = re.search(r"(\d+)", line)
            if m:
                active = int(m.group(1))
    nt_compaction_pending.labels(host=host).set(pending)
    nt_compaction_active.labels(host=host).set(active)


def parse_tpstats(host, stdout):
    lines = stdout.splitlines()
    for i, line in enumerate(lines):
        if "Active" in line and "Pending" in line and "Completed" in line:
            for j in range(i + 1, len(lines)):
                row = lines[j].split()
                if len(row) < 4:
                    break
                pool = row[0]
                try:
                    active, pending, completed = int(row[1]), int(row[2]), int(row[3])
                except (ValueError, IndexError):
                    continue
                nt_tpstats_active.labels(host=host, pool=pool).set(active)
                nt_tpstats_pending.labels(host=host, pool=pool).set(pending)
                nt_tpstats_completed.labels(host=host, pool=pool).set(completed)
            break


def scrape_host(host):
    ok = False
    ok1, out1 = run_nodetool(host, "status")
    if ok1:
        parse_status(host, out1)
        ok = True
    ok2, out2 = run_nodetool(host, "compactionstats")
    if ok2:
        parse_compactionstats(host, out2)
        ok = True
    ok3, out3 = run_nodetool(host, "tpstats")
    if ok3:
        parse_tpstats(host, out3)
        ok = True
    nt_up.labels(host=host).set(1 if ok else 0)


def scrape_all():
    for host in CASSANDRA_HOSTS:
        scrape_host(host)
    nt_cluster_nodes.set(len(CASSANDRA_HOSTS))


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/metrics", "/metrics/"):
            self.send_error(404)
            return
        scrape_all()
        output = generate_latest(REGISTRY)
        self.send_response(200)
        self.send_header("Content-Type", CONTENT_TYPE_LATEST)
        self.send_header("Content-Length", str(len(output)))
        self.end_headers()
        self.wfile.write(output)

    def log_message(self, format, *args):
        pass


def main():
    server = HTTPServer(("0.0.0.0", LISTEN_PORT), MetricsHandler)
    print(f"Serving nodetool metrics on :{LISTEN_PORT}/metrics for hosts: {CASSANDRA_HOSTS}")
    server.serve_forever()


if __name__ == "__main__":
    main()
