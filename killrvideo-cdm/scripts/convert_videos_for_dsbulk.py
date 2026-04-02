#!/usr/bin/env python3
"""
Convert killrvideo-cdm data/videos.csv so the 'tags' column is JSON array format
for DSBulk (e.g. ["a", "b"] instead of {'a', 'b'}).
Reads data/videos.csv, writes data/videos_dsbulk.csv.
"""
import csv
import re
import sys

def normalize_field(v):
    """Replace tabs and newlines so tab-delimited output has one line per record."""
    if v is None or not isinstance(v, str):
        return "" if v is None else str(v)
    return v.replace("\r\n", " ").replace("\n", " ").replace("\r", " ").replace("\t", " ").strip()

def set_literal_to_json(tags_str):
    if not tags_str or not tags_str.strip():
        return "[]"
    # Parse {'tag1', 'tag2', ...} -> ["tag1", "tag2", ...]
    s = tags_str.strip()
    if s.startswith("{") and s.endswith("}"):
        s = s[1:-1]
    if not s:
        return "[]"
    # Split by ', ' but respect quoted content (e.g. "love of one's life")
    parts = []
    current = []
    i = 0
    in_quote = False
    while i < len(s):
        c = s[i]
        if c == "'" and (i == 0 or s[i-1] != '\\'):
            in_quote = not in_quote
            if not in_quote and current:
                parts.append(''.join(current).strip().replace("''", "'"))
                current = []
            i += 1
            continue
        if in_quote:
            current.append(c)
            i += 1
            continue
        if c == ',' and not in_quote:
            if current:
                parts.append(''.join(current).strip().replace("''", "'"))
                current = []
            i += 1
            # skip space after comma
            while i < len(s) and s[i] == ' ':
                i += 1
            continue
        current.append(c)
        i += 1
    if current:
        parts.append(''.join(current).strip().replace("''", "'"))
    # Output as JSON array
    escaped = [f'"{p.replace(chr(34), chr(92)+chr(34))}"' for p in parts if p]
    return "[" + ",".join(escaped) + "]"

def main():
    input_path = "data/videos.csv"
    output_path = "data/videos_dsbulk.csv"
    if "--no-tags" in sys.argv:
        output_path = "data/videos_dsbulk_no_tags.csv"
    if len(sys.argv) >= 2 and sys.argv[1] != "--no-tags":
        input_path = sys.argv[1]
    if len(sys.argv) >= 3:
        output_path = sys.argv[2]

    with open(input_path, "r", encoding="utf-8", newline="") as fin:
        reader = csv.DictReader(fin)
        if not reader.fieldnames:
            print("No header in CSV", file=sys.stderr)
            sys.exit(1)
        fieldnames = [f for f in reader.fieldnames if f]
        # Optionally skip 'tags' to avoid set<text>/JSON parsing issues with DSBulk
        if "--no-tags" in sys.argv:
            fieldnames = [f for f in fieldnames if f != "tags"]
        rows = []
        for row in reader:
            rows.append({k: normalize_field(row.get(k, "")) for k in fieldnames})

    with open(output_path, "w", encoding="utf-8", newline="") as fout:
        writer = csv.DictWriter(fout, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            if "tags" in row and row["tags"] and "tags" in fieldnames:
                row["tags"] = set_literal_to_json(row["tags"])
            writer.writerow({k: row.get(k, "") for k in fieldnames})

    print(f"Wrote {output_path} with {len(rows)} rows (tags as JSON, tab-delimited).")
    if "tags" not in fieldnames:
        print("(tags column omitted; use for DSBulk if set<text> causes issues)")
    print("Load with config file: dsbulk load -f conf/dsbulk-load-videos.conf -url", output_path, "-k killrvideo -t videos -h 127.0.0.1 -port 9042")
    print("(If dsbulk not on PATH, use full path e.g. ~/Downloads/dsbulk-1.11.0/bin/dsbulk load ...)")

if __name__ == "__main__":
    main()
