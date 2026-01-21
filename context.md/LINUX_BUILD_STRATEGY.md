# Linux Build Strategy for libsql-swift

## Goal

Build fast on Ubuntu 24.04 without compiling Rust each time, for both
x86_64 and aarch64.

## Short History

- No Linux build support (macOS xcframework only).
- Added `BuildLibsqlPlugin` to build from source.
- CI builds were too slow, moved to artifactbundles.

## Current State

- macOS/iOS uses `Turso/CLibsql/CLibsql.xcframework`.
- Linux uses `Turso/CLibsqlLinux-<triple>.artifactbundle.zip`.
- `BuildLibsqlPlugin` still exists but is not the default path.

## Strategy

1. Build `libsql-c` once per Linux target triple.
2. Package it as an SPM artifactbundle with:
   - `liblibsql.a`
   - `libsql.h`
   - `module.modulemap`
3. Select the correct archive in `Package.swift`.

## Target Triples (Planned)

- `x86_64-unknown-linux-gnu`
- `aarch64-unknown-linux-gnu`

## Selection

- `LIBSQL_LINUX_TRIPLE` overrides the choice.
- Default: host arch + `*-unknown-linux-gnu`.

## Build Script

`Turso/scripts/build-linux-artifactbundle.sh` builds one archive for a
single triple. A small wrapper script will build all four variants.

## Fallback

`BuildLibsqlPlugin` can remain for users on unsupported distros
or when a binary is not available.
