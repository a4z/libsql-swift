#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOCKER_PLATFORM=linux/amd64 "$SCRIPT_DIR/build-container.sh" rustswift-amd64
