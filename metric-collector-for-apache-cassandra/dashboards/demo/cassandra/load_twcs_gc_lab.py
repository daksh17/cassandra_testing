#!/usr/bin/env python3
"""
Time-ordered insert load for TWCS + gc_grace lab tables (demo_hub.lab_twcs_w2m_gc*).

Requires: pip install cassandra-driver

Examples (host → published port 19442):
  python3 cassandra/load_twcs_gc_lab.py --gc 60 --rows 20000
  python3 cassandra/load_twcs_gc_lab.py --table demo_hub.lab_twcs_w2m_gc90 --rows 50000 --batch-size 100

Inside Docker network:
  python3 cassandra/load_twcs_gc_lab.py --hosts cassandra --port 9042 --gc 120 --rows 10000
"""
from __future__ import annotations

import argparse
import sys
import time
from datetime import datetime, timedelta, timezone

try:
    from cassandra.cluster import Cluster, ExecutionProfile, EXEC_PROFILE_DEFAULT
    from cassandra.policies import DCAwareRoundRobinPolicy
    from cassandra.query import BatchStatement, ConsistencyLevel
except ImportError:
    print("Install: pip install cassandra-driver", file=sys.stderr)
    raise


def main() -> None:
    p = argparse.ArgumentParser(description="TWCS gc_grace lab load (monotonic event_ts per partition).")
    p.add_argument("--hosts", default="127.0.0.1", help="Comma-separated contact points (default 127.0.0.1)")
    p.add_argument("--port", type=int, default=19442, help="Native port (host default 19442 → cassandra:9042)")
    p.add_argument(
        "--local-dc",
        default="datacenter1",
        help="Driver local datacenter (stock cassandra:4.0 image uses datacenter1)",
    )
    p.add_argument(
        "--gc",
        type=int,
        choices=(30, 60, 90, 120),
        default=None,
        help="Select table lab_twcs_w2m_gc{30|60|90|120} (default: 60 if --table omitted)",
    )
    p.add_argument(
        "--table",
        default=None,
        help="Full table name e.g. demo_hub.lab_twcs_w2m_gc60 (overrides --gc)",
    )
    p.add_argument("--sensor-id", default="loadtest", help="Partition sensor_id")
    p.add_argument(
        "--day",
        default=None,
        help="Partition day bucket YYYY-MM-DD (default: UTC today)",
    )
    p.add_argument("--rows", type=int, default=10_000, help="Total rows to insert")
    p.add_argument("--batch-size", type=int, default=100, help="Rows per BatchStatement (same partition)")
    p.add_argument("--payload-bytes", type=int, default=64, help="Payload column size (bytes)")
    args = p.parse_args()

    if args.table:
        if "." not in args.table:
            print("error: --table must be keyspace.name e.g. demo_hub.lab_twcs_w2m_gc60", file=sys.stderr)
            sys.exit(2)
        fq = args.table
    else:
        gc = args.gc if args.gc is not None else 60
        fq = f"demo_hub.lab_twcs_w2m_gc{gc}"

    day = args.day or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    hosts = [h.strip() for h in args.hosts.split(",") if h.strip()]
    profile = ExecutionProfile(
        load_balancing_policy=DCAwareRoundRobinPolicy(local_dc=args.local_dc),
        request_timeout=120,
        consistency_level=ConsistencyLevel.LOCAL_ONE,
    )
    cluster = Cluster(
        hosts,
        port=args.port,
        protocol_version=4,
        execution_profiles={EXEC_PROFILE_DEFAULT: profile},
    )
    session = cluster.connect()

    ks, tbl = fq.split(".", 1)
    session.set_keyspace(ks)
    prep = session.prepare(
        f"INSERT INTO {tbl} (sensor_id, day, event_ts, val, payload) VALUES (?, ?, ?, ?, ?)"
    )

    pad = ("x" * max(1, args.payload_bytes))[:16_384]
    base = datetime.now(timezone.utc).replace(microsecond=0)

    total = args.rows
    bs = max(1, min(args.batch_size, 5000))
    t0 = time.perf_counter()
    written = 0

    for start in range(0, total, bs):
        end = min(start + bs, total)
        batch = BatchStatement(consistency_level=ConsistencyLevel.LOCAL_ONE)
        for i in range(start, end):
            ts = base + timedelta(milliseconds=i)
            batch.add(prep, (args.sensor_id, day, ts, float(i % 1_000_000), pad))
        session.execute(batch)
        written += end - start
        if written % max(bs * 20, 1) == 0 or end == total:
            elapsed = time.perf_counter() - t0
            print(f"  rows={written} elapsed_s={elapsed:.2f} rows/s={written / max(elapsed, 1e-9):.1f}")

    elapsed = time.perf_counter() - t0
    print(
        f"done table={fq} rows={written} wall_s={elapsed:.2f} avg_rows/s={written / max(elapsed, 1e-9):.1f}"
    )
    cluster.shutdown()


if __name__ == "__main__":
    main()
