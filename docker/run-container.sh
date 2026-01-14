#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$SCRIPT_DIR/.." && pwd)")"

IMAGE_TAG="${1:-rustswift}"
PLATFORM="${DOCKER_PLATFORM:-}"

PLATFORM_ARGS=()
if [ -n "$PLATFORM" ]; then
  PLATFORM_ARGS=(--platform "$PLATFORM")
fi

docker run --rm -it \
  "${PLATFORM_ARGS[@]}" \
  -v "$REPO_ROOT:/workspace" \
  -w /workspace \
  "$IMAGE_TAG" \
  bash
