#!/usr/bin/env bash
# Push a user and a YouTube video into KillrVideo via gRPC (backend :50101).
# Requires: grpcurl (https://github.com/fullstorydev/grpcurl)
# Usage:
#   ./scripts/grpc_push_video.sh
#   GRPC_HOST=localhost GRPC_PORT=50101 ./scripts/grpc_push_video.sh
#
# By default: tries to get an existing user ID via GetLatestVideoPreviews (gRPC),
# then submits a new video with that user; if no videos exist, creates a new user and submits.
# Optional env: GRPC_HOST, GRPC_PORT, USER_ID, VIDEO_ID, YOUTUBE_ID (default: one known-good ID so the video always shows),
#               RANDOM_YOUTUBE=1, USE_EXISTING_USER=1, SKIP_GET_USER=1, SKIP_LATEST_VIDEOS_INSERT=1,
#               DEBUG_GRPC=1 (print request JSON and use grpcurl -v so you see request/response; see README for protobuf binary and Java objects).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTOS_DIR="$REPO_ROOT/protos"
GRPC_HOST="${GRPC_HOST:-localhost}"
GRPC_PORT="${GRPC_PORT:-50101}"
GRPC_ADDR="$GRPC_HOST:$GRPC_PORT"

# Unique suffix so re-running the script can create a new user when needed (email must be unique)
UNIQUE_SUFFIX="${UNIQUE_SUFFIX:-$(date +%s)-$RANDOM}"
# VIDEO_ID: new per run. YOUTUBE_ID: default is a known-good ID so the video always shows; set YOUTUBE_ID=... or RANDOM_YOUTUBE=1 for a random one
if [[ -n "${YOUTUBE_ID:-}" ]]; then
  : # use env
elif [[ "${RANDOM_YOUTUBE:-0}" == "1" ]]; then
  DEFAULT_YOUTUBE_IDS=( "dQw4w9WgXcQ" "jNQXAC9IVRw" "9bZkp7q19f0" "kJQP7kiw5Fk" "RgKAFK5djSk" "OPf0YbXqDm0" "CevxZvSJLk8" )
  RAND_IDX=$(( RANDOM % ${#DEFAULT_YOUTUBE_IDS[@]} ))
  YOUTUBE_ID="${DEFAULT_YOUTUBE_IDS[$RAND_IDX]}"
else
  YOUTUBE_ID="dQw4w9WgXcQ"
fi
VIDEO_ID="${VIDEO_ID:-$(uuidgen 2>/dev/null || echo 'b2c3d4e5-f6a7-4890-b123-456789012345')}"
USE_EXISTING_USER="${USE_EXISTING_USER:-0}"
SKIP_GET_USER="${SKIP_GET_USER:-0}"
SKIP_LATEST_VIDEOS_INSERT="${SKIP_LATEST_VIDEOS_INSERT:-0}"
DEBUG_GRPC="${DEBUG_GRPC:-0}"
VIDEO_NAME="My gRPC test video"
# When DEBUG_GRPC=1, grpcurl runs with -v (verbose) so you see request/response; we also echo the JSON payload before each call
GRPCURL_VERBOSE=""
[[ "$DEBUG_GRPC" == "1" ]] && GRPCURL_VERBOSE="-v"
PREVIEW_URL="https://img.youtube.com/vi/${YOUTUBE_ID}/default.jpg"

if ! command -v grpcurl &>/dev/null; then
  echo "grpcurl is required. Install: https://github.com/fullstorydev/grpcurl"
  echo "  macOS: brew install grpcurl"
  exit 1
fi

if [[ ! -d "$PROTOS_DIR" ]] || [[ ! -f "$PROTOS_DIR/common/common_types.proto" ]]; then
  echo "Protos not found at $PROTOS_DIR. Run from killrvideo-all-in-one repo."
  exit 1
fi

# Resolve USER_ID: from env, or from gRPC GetLatestVideoPreviews (existing user in DB), or we'll create one
USER_FROM_GRPC=0
if [[ -n "${USER_ID:-}" ]]; then
  echo "Using USER_ID from env: $USER_ID"
  USER_FROM_GRPC=1
else
  USER_ID=""
  if [[ "$SKIP_GET_USER" != "1" ]]; then
    echo "Fetching existing user ID via GetLatestVideoPreviews (gRPC)..."
    [[ "$DEBUG_GRPC" == "1" ]] && echo "--- Request (JSON) ---" && echo '{"page_size": 5}' && echo "--- (grpcurl encodes this to protobuf binary and sends it; response below if -v) ---"
    if [[ "$DEBUG_GRPC" == "1" ]]; then
      RESP=$(grpcurl $GRPCURL_VERBOSE -plaintext -import-path "$PROTOS_DIR" \
        -proto video-catalog/video_catalog_service.proto \
        -d '{"page_size": 5}' \
        "$GRPC_ADDR" \
        killrvideo.video_catalog.VideoCatalogService/GetLatestVideoPreviews || true)
    else
      RESP=$(grpcurl $GRPCURL_VERBOSE -plaintext -import-path "$PROTOS_DIR" \
        -proto video-catalog/video_catalog_service.proto \
        -d '{"page_size": 5}' \
        "$GRPC_ADDR" \
        killrvideo.video_catalog.VideoCatalogService/GetLatestVideoPreviews 2>/dev/null || true)
    fi
    # Parse JSON: grpcurl may use camelCase (videoPreviews, userId) or snake_case (video_previews, user_id)
    USER_ID=$(echo "$RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    previews = d.get('videoPreviews') or d.get('video_previews') or []
    if previews:
        u = previews[0].get('userId') or previews[0].get('user_id') or {}
        v = u.get('value', '')
        if v: print(v)
except Exception: pass
" 2>/dev/null || true)
    if [[ -n "$USER_ID" ]]; then
      USER_FROM_GRPC=1
      echo "Using existing user ID from DB (gRPC): $USER_ID"
    fi
  fi
  if [[ -z "$USER_ID" ]]; then
    USER_ID=$(uuidgen 2>/dev/null || echo "a1b2c3d4-e5f6-4789-a012-345678901234")
    echo "No existing user from gRPC; will create user with ID: $USER_ID"
  fi
fi

echo "Using gRPC address: $GRPC_ADDR"
echo "User ID: $USER_ID"
echo "Video ID: $VIDEO_ID"
echo "YouTube ID: $YOUTUBE_ID"
echo ""

# 1) Create a user only if we didn't get one from gRPC (GetLatestVideoPreviews) or env (USE_EXISTING_USER)
if [[ "$USER_FROM_GRPC" == "1" ]]; then
  echo "Skipping CreateUser (using existing user from DB via gRPC)."
else
  echo "Creating user (email grpc-tester-$UNIQUE_SUFFIX@example.com)..."
  CREATEUSER_JSON="{
  \"user_id\": { \"value\": \"$USER_ID\" },
  \"first_name\": \"Grpc\",
  \"last_name\": \"Tester\",
  \"email\": \"grpc-tester-$UNIQUE_SUFFIX@example.com\",
  \"password\": \"grpc-test-password\"
}"
  [[ "$DEBUG_GRPC" == "1" ]] && echo "--- Request (JSON) ---" && echo "$CREATEUSER_JSON" && echo "--- (grpcurl encodes this to protobuf binary; response below if -v) ---"
  grpcurl $GRPCURL_VERBOSE -plaintext \
    -import-path "$PROTOS_DIR" \
    -proto user-management/user_management_service.proto \
    -d "$CREATEUSER_JSON" \
    "$GRPC_ADDR" \
    killrvideo.user_management.UserManagementService/CreateUser
  echo "User created."
fi
echo ""

# 2) Submit a YouTube video (backend writes to C* videos; may also write latest_videos)
echo "Submitting YouTube video..."
SUBMIT_JSON="{
  \"video_id\": { \"value\": \"$VIDEO_ID\" },
  \"user_id\": { \"value\": \"$USER_ID\" },
  \"name\": \"$VIDEO_NAME\",
  \"description\": \"Added via grpcurl to KillrVideo backend\",
  \"tags\": [\"grpc\", \"demo\"],
  \"you_tube_video_id\": \"$YOUTUBE_ID\"
}"
[[ "$DEBUG_GRPC" == "1" ]] && echo "--- Request (JSON) ---" && echo "$SUBMIT_JSON" && echo "--- (grpcurl encodes this to protobuf binary; response below if -v) ---"
grpcurl $GRPCURL_VERBOSE -plaintext \
  -import-path "$PROTOS_DIR" \
  -proto video-catalog/video_catalog_service.proto \
  -d "$SUBMIT_JSON" \
  "$GRPC_ADDR" \
  killrvideo.video_catalog.VideoCatalogService/SubmitYouTubeVideo
echo "Video submitted."
echo ""

# 3) Ensure the video appears on the UI "Latest" list: insert into latest_videos via CQL.
#    The backend may use a different date/timezone or the insert can fail; this step guarantees the row exists.
if [[ "$SKIP_LATEST_VIDEOS_INSERT" != "1" ]]; then
  YYYYMMDD=$(date -u +%Y%m%d)
  # Escape single quotes in video name for CQL
  VIDEO_NAME_ESC="${VIDEO_NAME//\'/\'\'}"
  if command -v docker &>/dev/null; then
    if (cd "$REPO_ROOT" && docker compose ps -q dse 2>/dev/null | head -1 | grep -q .); then
      echo "Inserting into latest_videos (yyyymmdd=$YYYYMMDD) so the video shows on the UI..."
      CQL="USE killrvideo; INSERT INTO latest_videos (yyyymmdd, added_date, videoid, userid, name, preview_image_location) VALUES ('$YYYYMMDD', toTimestamp(now()), $VIDEO_ID, $USER_ID, '$VIDEO_NAME_ESC', '$PREVIEW_URL');"
      if (cd "$REPO_ROOT" && docker compose exec -T dse cqlsh -e "$CQL" 2>/dev/null); then
        echo "Inserted into latest_videos. Refresh http://localhost:3000 to see the video (Latest)."
      else
        echo "cqlsh insert failed. Run in DataStax Studio (http://localhost:9091): USE killrvideo; INSERT INTO latest_videos (yyyymmdd, added_date, videoid, userid, name, preview_image_location) VALUES ('$YYYYMMDD', toTimestamp(now()), $VIDEO_ID, $USER_ID, '$VIDEO_NAME_ESC', '$PREVIEW_URL');"
      fi
    else
      echo "DSE container not running from $REPO_ROOT. If the video does not appear at http://localhost:3000, run in Studio: USE killrvideo; INSERT INTO latest_videos (yyyymmdd, added_date, videoid, userid, name, preview_image_location) VALUES ('$YYYYMMDD', toTimestamp(now()), $VIDEO_ID, $USER_ID, '$VIDEO_NAME_ESC', '$PREVIEW_URL');"
    fi
  else
    echo "Docker not found. If the video does not appear at http://localhost:3000, run in DataStax Studio (http://localhost:9091): USE killrvideo; INSERT INTO latest_videos (yyyymmdd, added_date, videoid, userid, name, preview_image_location) VALUES ('$YYYYMMDD', toTimestamp(now()), $VIDEO_ID, $USER_ID, '$VIDEO_NAME_ESC', '$PREVIEW_URL');"
  fi
else
  echo "Skipping latest_videos insert (SKIP_LATEST_VIDEOS_INSERT=1)."
fi
echo ""
echo "Done. Refresh http://localhost:3000 to see the new video (Latest)."
