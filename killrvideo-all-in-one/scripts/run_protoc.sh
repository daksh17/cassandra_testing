#!/usr/bin/env bash
# Run protoc in this repo to generate code from protos/. Does NOT call killrvideo-java.
# To also build killrvideo-java (which runs protoc internally), use: ./scripts/build_killrvideo_java.sh
#
# Usage: ./scripts/run_protoc.sh [java|python]
#   java:   generate Java into build/gen/java (requires protoc + grpc_java_plugin, or Docker)
#   python: generate Python into build/gen/python (uses Docker with grpcio-tools if available)
# Env: USE_LOCAL_PROTOC=1 to use local protoc/grpcio-tools instead of Docker.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTOS_DIR="$REPO_ROOT/protos"
OUT_DIR="$REPO_ROOT/build/gen"
LANG="${1:-java}"
USE_LOCAL_PROTOC="${USE_LOCAL_PROTOC:-0}"

cd "$REPO_ROOT"
mkdir -p "$OUT_DIR"

# With -I protos, pass paths relative to protos/ so imports resolve
PROTO_LIST_FULL="common/common_types.proto google/protobuf/timestamp.proto video-catalog/video_catalog_service.proto user-management/user_management_service.proto"
PROTO_LIST_NO_GOOGLE="common/common_types.proto video-catalog/video_catalog_service.proto user-management/user_management_service.proto"
PROTOS_INC="$REPO_ROOT/protos"

echo "Generating $LANG code from protos/ into $OUT_DIR/$LANG ..."

if [[ "$LANG" == "python" ]]; then
  mkdir -p "$OUT_DIR/python"
  # Python grpc_tools bundles google/protobuf/timestamp.proto; our protos/google causes "already defined".
  # Use a temp include dir with only common, video-catalog, user-management so google/ is resolved by grpc_tools.
  run_python_protoc() {
    local inc_dir
    inc_dir=$(mktemp -d 2>/dev/null || echo "$REPO_ROOT/build/proto_inc")
    mkdir -p "$inc_dir"
    ln -sf "$REPO_ROOT/protos/common" "$inc_dir/common" 2>/dev/null || true
    ln -sf "$REPO_ROOT/protos/video-catalog" "$inc_dir/video-catalog" 2>/dev/null || true
    ln -sf "$REPO_ROOT/protos/user-management" "$inc_dir/user-management" 2>/dev/null || true
    python3 -m grpc_tools.protoc -I"$inc_dir" --python_out="$OUT_DIR/python" --grpc_python_out="$OUT_DIR/python" \
      "$inc_dir/common/common_types.proto" "$inc_dir/video-catalog/video_catalog_service.proto" "$inc_dir/user-management/user_management_service.proto"
    [[ "$inc_dir" != "$REPO_ROOT/build/proto_inc" ]] && rm -rf "$inc_dir" 2>/dev/null || true
  }
  if [[ "$USE_LOCAL_PROTOC" == "1" ]]; then
    run_python_protoc
  elif command -v docker &>/dev/null; then
    docker run --rm -v "$REPO_ROOT:/workspace" -w /workspace python:3.11-slim bash -c '
      pip install -q grpcio-tools
      inc_dir=$(mktemp -d)
      ln -sf /workspace/protos/common "$inc_dir/common"
      ln -sf /workspace/protos/video-catalog "$inc_dir/video-catalog"
      ln -sf /workspace/protos/user-management "$inc_dir/user-management"
      python -m grpc_tools.protoc -I"$inc_dir" --python_out=build/gen/python --grpc_python_out=build/gen/python \
        common/common_types.proto video-catalog/video_catalog_service.proto user-management/user_management_service.proto
      rm -rf "$inc_dir"
    '
  else
    echo "Need Docker or: pip install grpcio-tools && USE_LOCAL_PROTOC=1 ./scripts/run_protoc.sh python"
    exit 1
  fi
  echo "Done. Generated Python in $OUT_DIR/python"
  ls -la "$OUT_DIR/python" 2>/dev/null || true
  exit 0
fi

# Java: use -I protos so imports resolve; we can pass our timestamp.proto (no grpc_tools conflict)
mkdir -p "$OUT_DIR/java"
if [[ "$USE_LOCAL_PROTOC" == "1" ]]; then
  PROTOC="${PROTOC:-protoc}"
  if ! command -v "$PROTOC" &>/dev/null; then
    echo "protoc not found. Install Protocol Buffers compiler, or run ./scripts/build_killrvideo_java.sh to build killrvideo-java (which runs protoc)."
    exit 1
  fi
  "$PROTOC" -I"$PROTOS_INC" --java_out="$OUT_DIR/java" \
    "$PROTOS_INC/common/common_types.proto" "$PROTOS_INC/google/protobuf/timestamp.proto" \
    "$PROTOS_INC/video-catalog/video_catalog_service.proto" "$PROTOS_INC/user-management/user_management_service.proto"
  if command -v protoc-gen-grpc-java &>/dev/null; then
    "$PROTOC" -I"$PROTOS_INC" --grpc_out="$OUT_DIR/java" --plugin=protoc-gen-grpc=protoc-gen-grpc-java \
      "$PROTOS_INC/video-catalog/video_catalog_service.proto" "$PROTOS_INC/user-management/user_management_service.proto" 2>/dev/null || true
  fi
  echo "Done. Generated Java in $OUT_DIR/java"
else
  echo "For Java, use one of:"
  echo "  1) Install protoc and (optional) protoc-gen-grpc-java, then: USE_LOCAL_PROTOC=1 ./scripts/run_protoc.sh java"
  echo "  2) Build killrvideo-java (runs protoc as part of Maven build): ./scripts/build_killrvideo_java.sh"
  exit 1
fi
