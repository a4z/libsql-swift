#!/usr/bin/env bash
set -euo pipefail


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PIDS=()

DOCKER_PLATFORM=linux/amd64 "$SCRIPT_DIR/build-container.sh" rustswift-amd64 &
PIDS+=($!)

DOCKER_PLATFORM=linux/arm64 "$SCRIPT_DIR/build-container.sh" rustswift-arm64 &
PIDS+=($!)

for PID in "${PIDS[@]}"; do
  wait "$PID"
done
