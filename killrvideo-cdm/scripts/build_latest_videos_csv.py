#!/usr/bin/env python3
"""
Build latest_videos CSV from videos CSV for DSBulk load.
Reads data/videos_dsbulk_no_tags.csv (tab-delimited), writes data/latest_videos_dsbulk.csv.
The UI "Latest" page reads from latest_videos; the backend queries the last 8 days (today through today-7).
Use --all-recent-days (default) to insert each video into all 8 day partitions so the UI finds them regardless of timezone.
Use --use-today to insert only into today's partition (smaller CSV).
Use --use-original-dates to keep each video's actual added_date as the partition (for multi-day data).
"""
import csv
import re
import sys
from datetime import datetime, timezone, timedelta

# Backend queries buckets: today, today-1, ... today-7 (MAX_DAYS_IN_PAST_FOR_LATEST_VIDEOS = 7)
NUM_RECENT_DAYS = 8

# YouTube thumbnail: https://img.youtube.com/vi/VIDEO_ID/default.jpg
YOUTUBE_THUMB = "https://img.youtube.com/vi/{id}/default.jpg"
YOUTUBE_ID_RE = re.compile(r"(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})")

def preview_from_location(location, existing_preview):
    """If existing_preview is empty and location is a YouTube URL, return thumbnail URL."""
    if (existing_preview or "").strip():
        return existing_preview.strip()
    if not location:
        return ""
    m = YOUTUBE_ID_RE.search(location)
    return YOUTUBE_THUMB.format(id=m.group(1)) if m else ""

def main():
    input_path = "data/videos_dsbulk_no_tags.csv"
    output_path = "data/latest_videos_dsbulk.csv"
    use_original = "--use-original-dates" in sys.argv
    use_today_only = "--use-today" in sys.argv and not use_original
    use_all_recent = not use_original and not use_today_only  # default
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) >= 1:
        input_path = args[0]
    if len(args) >= 2:
        output_path = args[1]

    now = datetime.now(timezone.utc)
    today_yyyymmdd = now.strftime("%Y%m%d")
    recent_dates = [(now - timedelta(days=d)).strftime("%Y%m%d") for d in range(NUM_RECENT_DAYS)]

    base_rows = []
    with open(input_path, "r", encoding="utf-8", newline="") as fin:
        reader = csv.DictReader(fin, delimiter="\t")
        for row in reader:
            added = (row.get("added_date") or "").strip()
            if not row.get("videoid"):
                continue
            yyyymmdd_one = (added.replace("-", "")[:8] if len(added) >= 10 else "") if use_original else today_yyyymmdd
            if use_original and not yyyymmdd_one:
                continue
            preview = (row.get("preview_image_location") or "").replace("\t", " ").replace("\n", " ").replace("\r", " ").strip()
            location = (row.get("location") or "").strip()
            preview = preview_from_location(location, preview) or preview
            base_rows.append({
                "yyyymmdd": yyyymmdd_one,
                "added_date": added,
                "videoid": (row.get("videoid") or "").strip(),
                "userid": (row.get("userid") or "").strip(),
                "name": (row.get("name") or "").replace("\t", " ").replace("\n", " ").replace("\r", " ").strip(),
                "preview_image_location": preview,
            })

    rows = []
    if use_all_recent:
        for r in base_rows:
            for ymd in recent_dates:
                rows.append({**r, "yyyymmdd": ymd})
    else:
        rows = base_rows

    fieldnames = ["yyyymmdd", "added_date", "videoid", "userid", "name", "preview_image_location"]
    with open(output_path, "w", encoding="utf-8", newline="") as fout:
        writer = csv.DictWriter(fout, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {output_path} with {len(rows)} rows (yyyymmdd={'all 8 recent days' if use_all_recent else 'today only' if use_today_only else 'original'}).")
    if use_all_recent:
        print(f"  Partitions: {recent_dates[0]} (today) through {recent_dates[-1]} — backend will find videos regardless of its timezone.")
    elif use_today_only:
        print(f"  Today's partition: yyyymmdd = '{today_yyyymmdd}'")
    if use_today_only or use_all_recent:
        print("  In Studio: SELECT * FROM killrvideo.latest_videos WHERE yyyymmdd = '" + (recent_dates[0] if use_all_recent else today_yyyymmdd) + "' LIMIT 20;")
    print("Load with: dsbulk load -f conf/dsbulk-load-videos.conf -url data/latest_videos_dsbulk.csv -k killrvideo -t latest_videos -h 127.0.0.1 -port 9042")
    if use_all_recent or use_today_only:
        print("Then refresh http://localhost:3000 — RECENT VIDEOS should show.")

if __name__ == "__main__":
    main()
