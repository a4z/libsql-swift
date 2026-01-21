#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE_TAG="${1:-rustswift}"
PLATFORM="${DOCKER_PLATFORM:-}"
USER_ID="${DOCKER_UID:-$(id -u)}"
GROUP_ID="${DOCKER_GID:-$(id -g)}"
USER_NAME="${DOCKER_UNAME:-user}"
DOCKERFILE_PATH="$SCRIPT_DIR/Dockerfile"
BUILD_CONTEXT="$SCRIPT_DIR"

if [ ! -f "$DOCKERFILE_PATH" ]; then
  echo "Missing Dockerfile: $DOCKERFILE_PATH" >&2
  exit 1
fi

PLATFORM_ARGS=()
if [ -n "$PLATFORM" ]; then
  PLATFORM_ARGS=(--platform "$PLATFORM")
fi

docker build "${PLATFORM_ARGS[@]}" \
  -f "$DOCKERFILE_PATH" \
  -t "$IMAGE_TAG" \
  --build-arg UID="$USER_ID" \
  --build-arg GID="$GROUP_ID" \
  --build-arg UNAME="$USER_NAME" \
  "$BUILD_CONTEXT"

echo "Built image: $IMAGE_TAG"
