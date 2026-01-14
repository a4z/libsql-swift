#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOCKER_PLATFORM=linux/arm64 "$SCRIPT_DIR/build-container.sh" rustswift-arm64
