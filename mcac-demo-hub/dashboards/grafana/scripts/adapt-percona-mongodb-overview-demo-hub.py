#!/usr/bin/env python3
"""Adapt Grafana dashboard JSON from Percona MongoDB Overview (e.g. gnetId 20192) for mcac-demo-hub Prometheus labels.

Reads dashboard JSON from stdin or first positional argument; writes adapted JSON to stdout
or to the path given with ``-o`` / ``--output``.

Prometheus static_config labels (see deploy/k8s generated scrape):
  job=mongodb, mongo_topology=sharded, mongo_cluster=tictactoe

Usage:
  curl -sSf https://grafana.com/api/dashboards/20192/revisions/1/download | \\
    python3 adapt-percona-mongodb-overview-demo-hub.py -o ../generated-dashboards/mongodb-overview-percona-demo-hub.json

Then append mongos/sharding panels (same directory):
  python3 extend-percona-mongodb-overview-mongos-panels.py
"""
from __future__ import annotations

import argparse
import json
import sys
from typing import Any

# Use regex matcher so template "All" (allValue .*) matches every mongo_cluster; equality would
# produce mongo_cluster="All" and return no data.
LABELS = 'job="mongodb",mongo_topology="sharded",mongo_cluster=~"$mdb_cluster",instance="$mdb_instance"'


def fix_expr(s: str) -> str:
    if not isinstance(s, str):
        return s
    return s.replace('instance="$host"', LABELS)


def walk_panels(panels: list[dict[str, Any]] | None) -> None:
    for p in panels or []:
        if "panels" in p:
            walk_panels(p["panels"])
        for t in p.get("targets") or []:
            if t.get("expr"):
                t["expr"] = fix_expr(t["expr"])


def retemplate_grafana_vars(panels: list[dict[str, Any]] | None) -> None:
    """Percona uses $cluster/$host; template names become mdb_cluster/mdb_instance."""
    for p in panels or []:
        if "panels" in p:
            retemplate_grafana_vars(p["panels"])
        for t in p.get("targets") or []:
            ex = t.get("expr")
            if isinstance(ex, str):
                t["expr"] = ex.replace("$cluster", "$mdb_cluster").replace("$host", "$mdb_instance")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "input_file",
        nargs="?",
        help="Dashboard JSON path (default: read stdin)",
    )
    ap.add_argument(
        "-o",
        "--output",
        help="Write JSON to this file instead of stdout",
    )
    args = ap.parse_args()
    if args.input_file:
        d = json.loads(open(args.input_file, encoding="utf-8").read())
    else:
        d = json.loads(sys.stdin.read())

    walk_panels(d.get("panels"))
    retemplate_grafana_vars(d.get("panels"))

    for v in d.get("templating", {}).get("list", []):
        if v.get("name") == "cluster":
            v["name"] = "mdb_cluster"
            v["query"] = (
                'label_values(mongodb_up{job="mongodb",mongo_topology="sharded"}, mongo_cluster)'
            )
            v["label"] = "Mongo cluster"
            v["allValue"] = ".*"
            v["current"] = {
                "selected": True,
                "text": "tictactoe",
                "value": "tictactoe",
            }
        elif v.get("name") == "host":
            v["name"] = "mdb_instance"
            v["query"] = (
                'label_values(mongodb_up{job="mongodb",mongo_topology="sharded",'
                'mongo_cluster=~"$mdb_cluster"}, instance)'
            )
            v["label"] = "Exporter instance"
            v["regex"] = "9216"
            v["definition"] = v["query"]

    for v in d.get("templating", {}).get("list", []):
        if v.get("name") == "datasource" and v.get("type") == "datasource":
            v["current"] = {
                "selected": True,
                "text": "prometheus",
                "value": "prometheus",
            }

    for k in ("__inputs", "__elements", "__requires"):
        d.pop(k, None)
    d["id"] = None
    d["gnetId"] = None
    d["uid"] = "mongodb-overview-demo-hub"
    d["title"] = "MongoDB Overview (Percona, demo-hub labels)"
    d["description"] = (
        "Percona MongoDB Overview adapted for mcac-demo-hub Prometheus scrape labels: "
        "job=mongodb, mongo_topology=sharded, mongo_cluster=tictactoe. "
        "Regenerate from grafana.com/api/dashboards/20192/revisions/<n>/download as needed. "
        "See dashboards/grafana/scripts/adapt-percona-mongodb-overview-demo-hub.py."
    )
    d["links"] = []
    d["tags"] = list(
        dict.fromkeys((d.get("tags") or []) + ["MongoDB", "demo-hub", "Percona"])
    )

    out = args.output
    if out:
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(d, fh, indent=2)
            fh.write("\n")
    else:
        json.dump(d, sys.stdout, indent=2)
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
