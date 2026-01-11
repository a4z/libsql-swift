#!/usr/bin/env bash
# Usage: build-linux-artifactbundle.sh <version> [liblibsql.a path] [output dir] [triple] [bundle name]
# Example: build-linux-artifactbundle.sh 1.0.0 "" "" aarch64-unknown-linux-gnu
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <version> [liblibsql.a path] [output dir] [triple] [bundle name]" >&2
  exit 1
fi

VERSION="$1"
TRIPLE="${4:-${LIBSQL_TRIPLE:-x86_64-unknown-linux-gnu}}"
ARCH="${TRIPLE%%-*}"
BUNDLE_NAME="${5:-libsql-linux-${ARCH}}"
LIB_PATH="${2:-Turso/CLibsql/libsql-c/target/${TRIPLE}/release/liblibsql.a}"
OUT_DIR="${3:-.build/artifacts}"
BUNDLE_DIR="${OUT_DIR}/${BUNDLE_NAME}.artifactbundle"
ARTIFACT_DIR="${BUNDLE_DIR}/${BUNDLE_NAME}"
INFO_JSON="${BUNDLE_DIR}/info.json"
ZIP_PATH="${OUT_DIR}/${BUNDLE_NAME}.artifactbundle.zip"

HEADER_DIR="Turso/CLibsqlLinux/include"
MODULEMAP="Turso/CLibsqlLinux/module.modulemap"

if [ ! -f "$LIB_PATH" ]; then
  echo "Missing lib: $LIB_PATH" >&2
  exit 1
fi

if [ ! -f "${HEADER_DIR}/libsql.h" ]; then
  echo "Missing header: ${HEADER_DIR}/libsql.h" >&2
  exit 1
fi

if [ ! -f "$MODULEMAP" ]; then
  echo "Missing modulemap: $MODULEMAP" >&2
  exit 1
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$ARTIFACT_DIR/lib" "$ARTIFACT_DIR/include" "$OUT_DIR"

cp "$LIB_PATH" "$ARTIFACT_DIR/lib/liblibsql.a"
cp "${HEADER_DIR}/libsql.h" "$ARTIFACT_DIR/include/libsql.h"
cp "$MODULEMAP" "$ARTIFACT_DIR/module.modulemap"

cat > "$INFO_JSON" <<INFO
{
  "schemaVersion": "1.0",
  "artifacts": {
    "${BUNDLE_NAME}": {
      "version": "${VERSION}",
      "type": "library",
      "variants": [
        {
          "path": "${BUNDLE_NAME}",
          "supportedTriples": ["${TRIPLE}"]
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

CHECKSUM=$(swift package compute-checksum "$ZIP_PATH")

echo "Created: $ZIP_PATH"
echo "Checksum: $CHECKSUM"
