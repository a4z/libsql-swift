#!/usr/bin/env bash
# Usage: build-linux-artifactbundle.sh <version> [liblibsql.a path] [output dir] [triple] [bundle name]
# Example: build-linux-artifactbundle.sh 1.0.0 "" "" aarch64-unknown-linux-gnu
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <version> [liblibsql.a path] [output dir] [triple] [bundle name]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VERSION="$1"
detect_triple() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) echo "x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) echo "aarch64-unknown-linux-gnu" ;;
    *) echo "x86_64-unknown-linux-gnu" ;;
  esac
}

TRIPLE="${4:-${LIBSQL_TRIPLE:-$(detect_triple)}}"
ARCH="${TRIPLE%%-*}"
BUNDLE_NAME="${5:-CLibsqlLinux-${TRIPLE}}"
ARTIFACT_NAME="${LIBSQL_ARTIFACT_NAME:-CLibsql}"
VARIANT_NAME="${ARTIFACT_NAME}-${ARCH}"
VARIANT_PATH="${VARIANT_NAME}/liblibsql.a"
LIBSQL_C_DIR="${ROOT_DIR}/Turso/CLibsql/libsql-c"
LIBSQL_HEADER="${LIBSQL_C_DIR}/libsql.h"
MODULEMAP="${ROOT_DIR}/Turso/CLibsqlLinux/module.modulemap"
OUT_DIR="${3:-${ROOT_DIR}/Turso}"
BUNDLE_DIR="${OUT_DIR}/${BUNDLE_NAME}.artifactbundle"
ARTIFACT_DIR="${BUNDLE_DIR}/${VARIANT_NAME}"
INFO_JSON="${BUNDLE_DIR}/info.json"
ZIP_PATH="${OUT_DIR}/${BUNDLE_NAME}.artifactbundle.zip"

LIB_PATH="${2:-}"
if [ -z "$LIB_PATH" ]; then
  LIB_PATH="${LIBSQL_C_DIR}/target/${TRIPLE}/release/liblibsql.a"
  if [ "${LIBSQL_FORCE_BUILD:-0}" -eq 1 ] || [ ! -f "$LIB_PATH" ]; then
    (
      cd "$LIBSQL_C_DIR"
      CARGO_TMPDIR="${LIBSQL_C_DIR}/target/tmp"
      mkdir -p "$CARGO_TMPDIR"
      TMPDIR="$CARGO_TMPDIR" RUSTC_TMPDIR="$CARGO_TMPDIR" \
        cargo build --release --features encryption --target "$TRIPLE"
    )
  fi
fi

if [ ! -f "$LIB_PATH" ]; then
  echo "Missing lib: $LIB_PATH" >&2
  exit 1
fi

if [ ! -f "$LIBSQL_HEADER" ]; then
  echo "Missing header: $LIBSQL_HEADER" >&2
  exit 1
fi

if [ ! -f "$MODULEMAP" ]; then
  echo "Missing modulemap: $MODULEMAP" >&2
  exit 1
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$ARTIFACT_DIR" "$BUNDLE_DIR/include" "$OUT_DIR"

cp "$LIB_PATH" "$ARTIFACT_DIR/liblibsql.a"
cp "$LIBSQL_HEADER" "$BUNDLE_DIR/include/libsql.h"
cp "$MODULEMAP" "$BUNDLE_DIR/module.modulemap"

cat > "$INFO_JSON" <<INFO
{
  "schemaVersion": "1.0",
  "artifacts": {
    "${ARTIFACT_NAME}": {
      "version": "${VERSION}",
      "type": "staticLibrary",
      "variants": [
        {
          "path": "${VARIANT_PATH}",
          "supportedTriples": ["${TRIPLE}"],
          "staticLibraryMetadata": {
            "headerPaths": ["include"],
            "moduleMapPath": "module.modulemap"
          }
        }
      ]
    }
  }
}
INFO

(
  cd "$OUT_DIR"
  zip -r "${BUNDLE_NAME}.artifactbundle.zip" "${BUNDLE_NAME}.artifactbundle" >/dev/null
)

if [ -n "${SWIFTPM_BIN:-}" ]; then
  CHECKSUM=$("$SWIFTPM_BIN" compute-checksum "$ZIP_PATH")
elif command -v swift-package >/dev/null 2>&1; then
  CHECKSUM=$(swift-package compute-checksum "$ZIP_PATH")
else
  CHECKSUM=$(swift package compute-checksum "$ZIP_PATH")
fi

echo "Created: $ZIP_PATH"
echo "Checksum: $CHECKSUM"
