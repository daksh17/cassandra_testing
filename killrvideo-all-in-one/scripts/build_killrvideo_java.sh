#!/usr/bin/env bash
# Clone killrvideo-java and run its Maven build. That build runs protoc internally to generate
# Java code from .proto files, then compiles the backend.
#
# Usage: ./scripts/build_killrvideo_java.sh [target-dir]
#   target-dir: where to clone (default: ../killrvideo-java relative to repo root)
# Requires: git, Maven (mvn) and Java (for Maven build).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLONE_DIR="${1:-$REPO_ROOT/../killrvideo-java}"
KILLRVIDEO_JAVA_REPO="${KILLRVIDEO_JAVA_REPO:-https://github.com/KillrVideo/killrvideo-java.git}"

if [[ ! -d "$CLONE_DIR" ]]; then
  echo "Cloning killrvideo-java into $CLONE_DIR ..."
  git clone "$KILLRVIDEO_JAVA_REPO" "$CLONE_DIR"
else
  echo "Using existing $CLONE_DIR (pull to update)."
  (cd "$CLONE_DIR" && git pull --rebase 2>/dev/null || true)
fi

echo "Running Maven build in $CLONE_DIR (this runs protoc and compiles the backend) ..."
(cd "$CLONE_DIR" && mvn -q clean compile -DskipTests 2>/dev/null || mvn clean compile -DskipTests)

echo "Done. killrvideo-java built; protoc was run as part of the Maven build."
echo "Generated proto code is typically under: $CLONE_DIR/<module>/target/generated-sources/"
