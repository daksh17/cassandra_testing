#!/usr/bin/env python3
"""Append mongos / sharding panels (mongodb_mongos_*, dbstats raw) to Percona MongoDB Overview demo-hub JSON.

Uses the same Prometheus label filter as adapt-percona-mongodb-overview-demo-hub.py so mdb_cluster /
mdb_instance variables work. Re-run after re-importing grafana.com 20192 through adapt-*.py if you overwrite the file.

Usage:
  python3 extend-percona-mongodb-overview-mongos-panels.py
  python3 ../../deploy/k8s/scripts/gen_demo_hub_k8s.py   # refresh ConfigMap in K8s YAML
"""
from __future__ import annotations

import copy
import json
from pathlib import Path

LABELS = 'job="mongodb",mongo_topology="sharded",mongo_cluster=~"$mdb_cluster",instance="$mdb_instance"'

GRAFANA_DIR = Path(__file__).resolve().parent.parent
OUT = GRAFANA_DIR / "generated-dashboards" / "mongodb-overview-percona-demo-hub.json"

ROW_TITLE = "Mongos / sharding / dbStats (router view)"
# Row + appended timeseries panels (ids reserved by this script); stripped before re-append.
MONGOS_PANEL_IDS = frozenset(range(200, 220))
DESC_SUFFIX = (
    " Extended with mongos/sharding/dbStats panels (extend-percona-mongodb-overview-mongos-panels.py)."
)


def _normalize_mongodb_template_vars(dashboard: dict) -> None:
    """Avoid Grafana URL collisions with generic names cluster/host (Postgres dashboards use host too).

    Renames template vars to mdb_cluster / mdb_instance and filters exporter dropdown to port 9216.
    Idempotent if names already migrated.
    """
    lst = dashboard.get("templating", {}).get("list") or []
    needs_rename = any(v.get("name") == "cluster" for v in lst) or any(v.get("name") == "host" for v in lst)
    if not needs_rename:
        for v in lst:
            if v.get("name") == "mdb_instance":
                v.setdefault("regex", "9216")
                v.setdefault("definition", v.get("query", ""))
        return

    def repl_obj(o: object) -> object:
        if isinstance(o, str):
            return o.replace("$cluster", "$mdb_cluster").replace("$host", "$mdb_instance")
        if isinstance(o, list):
            return [repl_obj(i) for i in o]
        if isinstance(o, dict):
            return {k: repl_obj(v) for k, v in o.items()}
        return o

    merged = repl_obj(dashboard)
    dashboard.clear()
    dashboard.update(merged)

    for v in dashboard.get("templating", {}).get("list") or []:
        if v.get("name") == "cluster":
            v["name"] = "mdb_cluster"
        elif v.get("name") == "host":
            v["name"] = "mdb_instance"
            v["regex"] = "9216"
            v["definition"] = v.get("query", "")


def _grid_bottom(panel: dict) -> int:
    g = panel.get("gridPos") or {}
    return int(g.get("y", 0)) + int(g.get("h", 0))


def _timeseries_template(dashboard: dict) -> dict:
    for p in dashboard.get("panels") or []:
        if p.get("type") == "timeseries":
            return copy.deepcopy(p)
    raise RuntimeError("no timeseries panel found to clone")


def _mk_targets(exprs: list[tuple[str, str]]) -> list[dict]:
    out: list[dict] = []
    for i, (expr, legend) in enumerate(exprs):
        rid = chr(ord("A") + i) if i < 26 else str(i)
        out.append(
            {
                "datasource": {"uid": "$datasource"},
                "editorMode": "code",
                "expr": expr,
                "format": "time_series",
                "hide": False,
                "interval": "$interval",
                "intervalFactor": 1,
                "legendFormat": legend,
                "range": True,
                "refId": rid,
                "step": 300,
            }
        )
    return out


def _panel(
    tmpl: dict,
    *,
    pid: int,
    title: str,
    description: str,
    y: int,
    x: int,
    w: int,
    h: int,
    exprs: list[tuple[str, str]],
    unit: str = "short",
    min_zero: bool = True,
) -> dict:
    p = copy.deepcopy(tmpl)
    p["id"] = pid
    p["title"] = title
    p["description"] = description
    p["gridPos"] = {"h": h, "w": w, "x": x, "y": y}
    p["targets"] = _mk_targets(exprs)
    defs = p.setdefault("fieldConfig", {}).setdefault("defaults", {})
    defs["unit"] = unit
    if min_zero:
        defs["min"] = 0
    else:
        defs.pop("min", None)
    return p


def main() -> None:
    dashboard = json.loads(OUT.read_text(encoding="utf-8"))
    _normalize_mongodb_template_vars(dashboard)
    panels: list[dict] = dashboard["panels"]
    panels[:] = [
        p
        for p in panels
        if not (
            p.get("id") in MONGOS_PANEL_IDS
            or (p.get("type") == "row" and p.get("title") == ROW_TITLE)
        )
    ]
    tmpl = _timeseries_template(dashboard)

    next_y = max((_grid_bottom(p) for p in panels), default=0)
    row_id = 200
    pid = 201

    rows_intro = (
        "Mongos metrics from Percona exporter (scrape mongos). "
        "Classic insert/update/delete opcounters remain mongod-only — see Percona panels above."
    )

    row_panel = {
        "collapsed": False,
        "datasource": {"type": "prometheus", "uid": "$datasource"},
        "gridPos": {"h": 1, "w": 24, "x": 0, "y": next_y},
        "id": row_id,
        "panels": [],
        "title": ROW_TITLE,
        "type": "row",
    }
    panels.append(row_panel)
    y = next_y + 1

    def sel(extra: str = "") -> str:
        return "{" + LABELS + extra + "}"

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Sharding — totals",
            description=rows_intro,
            y=y,
            x=0,
            w=12,
            h=8,
            exprs=[
                (f"mongodb_mongos_sharding_shards_total{sel()}", "shards"),
                (f"mongodb_mongos_sharding_chunks_total{sel()}", "chunks"),
                (f"mongodb_mongos_sharding_chunks_is_balanced{sel()}", "chunks_balanced"),
                (f"mongodb_mongos_sharding_shards_draining_total{sel()}", "draining"),
                (
                    "mongodb_mongos_sharding_databases_total" + sel(',type="partitioned"'),
                    "db partitioned",
                ),
                (
                    "mongodb_mongos_sharding_databases_total" + sel(',type="unpartitioned"'),
                    "db unpartitioned",
                ),
            ],
        )
    )
    pid += 1

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Sharding — chunks per shard (tic/tac/toe demo)",
            description="Shard names match mcac-demo-hub shard replica sets.",
            y=y,
            x=12,
            w=12,
            h=8,
            exprs=[
                ("mongodb_mongos_sharding_shard_chunks_total" + sel(',shard="tic"'), "tic"),
                ("mongodb_mongos_sharding_shard_chunks_total" + sel(',shard="tac"'), "tac"),
                ("mongodb_mongos_sharding_shard_chunks_total" + sel(',shard="toe"'), "toe"),
            ],
        )
    )
    pid += 1
    y += 8

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Router view — demo DB data size",
            description="dbStats via mongos.",
            y=y,
            x=0,
            w=12,
            h=7,
            exprs=[("mongodb_mongos_db_data_size_bytes" + sel(',db="demo"'), "data")],
            unit="decbytes",
        )
    )
    pid += 1

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Router view — demo DB index size",
            description="dbStats via mongos.",
            y=y,
            x=12,
            w=12,
            h=7,
            exprs=[("mongodb_mongos_db_index_size_bytes" + sel(',db="demo"'), "indexes")],
            unit="decbytes",
        )
    )
    pid += 1
    y += 7

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Router view — demo collections / indexes",
            description="Catalog counts from mongos.",
            y=y,
            x=0,
            w=12,
            h=7,
            exprs=[
                ("mongodb_mongos_db_collections_total" + sel(',db="demo"'), "collections"),
                ("mongodb_mongos_db_indexes_total" + sel(',db="demo"'), "indexes"),
            ],
        )
    )
    pid += 1

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Router view — config DB sizes",
            description="Config database footprint on mongos.",
            y=y,
            x=12,
            w=12,
            h=7,
            exprs=[
                ("mongodb_mongos_db_data_size_bytes" + sel(',db="config"'), "data"),
                ("mongodb_mongos_db_index_size_bytes" + sel(',db="config"'), "indexes"),
            ],
            unit="decbytes",
        )
    )
    pid += 1
    y += 7

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Per-shard dbStats — storageSize",
            description="Raw exporter metrics from shard discovery (demo shard names).",
            y=y,
            x=0,
            w=24,
            h=8,
            exprs=[
                (f"mongodb_dbstats_raw_tic_mongo_shard_tic_27017_storageSize{sel()}", "tic"),
                (f"mongodb_dbstats_raw_tac_mongo_shard_tac_27017_storageSize{sel()}", "tac"),
                (f"mongodb_dbstats_raw_toe_mongo_shard_toe_27017_storageSize{sel()}", "toe"),
            ],
            unit="decbytes",
        )
    )
    pid += 1
    y += 8

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Per-shard dbStats — objects",
            description="Document counts (approximation from dbStats).",
            y=y,
            x=0,
            w=12,
            h=7,
            exprs=[
                (f"mongodb_dbstats_raw_tic_mongo_shard_tic_27017_objects{sel()}", "tic"),
                (f"mongodb_dbstats_raw_tac_mongo_shard_tac_27017_objects{sel()}", "tac"),
                (f"mongodb_dbstats_raw_toe_mongo_shard_toe_27017_objects{sel()}", "toe"),
            ],
        )
    )
    pid += 1

    panels.append(
        _panel(
            tmpl,
            pid=pid,
            title="Per-shard dbStats — filesystem used / total",
            description="Host FS usage reported in dbStats where available.",
            y=y,
            x=12,
            w=12,
            h=7,
            exprs=[
                (f"mongodb_dbstats_raw_tic_mongo_shard_tic_27017_fsUsedSize{sel()}", "tic used"),
                (f"mongodb_dbstats_raw_tac_mongo_shard_tac_27017_fsUsedSize{sel()}", "tac used"),
                (f"mongodb_dbstats_raw_toe_mongo_shard_toe_27017_fsUsedSize{sel()}", "toe used"),
                (f"mongodb_dbstats_raw_tic_mongo_shard_tic_27017_fsTotalSize{sel()}", "tic total"),
                (f"mongodb_dbstats_raw_tac_mongo_shard_tac_27017_fsTotalSize{sel()}", "tac total"),
                (f"mongodb_dbstats_raw_toe_mongo_shard_toe_27017_fsTotalSize{sel()}", "toe total"),
            ],
            unit="decbytes",
        )
    )

    ddesc = dashboard.get("description", "").rstrip()
    if "extend-percona-mongodb-overview-mongos-panels.py" not in ddesc:
        dashboard["description"] = ddesc + DESC_SUFFIX
    tags = list(dashboard.get("tags") or [])
    for t in ("mongos", "sharding"):
        if t not in tags:
            tags.append(t)
    dashboard["tags"] = tags

    OUT.write_text(json.dumps(dashboard, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(dashboard['panels'])} panels)")


if __name__ == "__main__":
    main()
