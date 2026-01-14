# Linux Binary Distribution Strategy for libsql-swift

## Goal

- Avoid rebuilding `libsql-c` on every Linux build
- Ship pre-built artifactbundles with headers and module map
- Focus on Ubuntu 24.04 (x86_64 + aarch64)

## Current State

- macOS/iOS: `Turso/CLibsql/CLibsql.xcframework`
- Linux: `Turso/CLibsqlLinux-<triple>.artifactbundle.zip` (per arch)
- Build script: `Turso/scripts/build-linux-artifactbundle.sh`

## Target Matrix (Planned)

| Triple | Arch | Libc | Use case |
| --- | --- | --- | --- |
| x86_64-unknown-linux-gnu | x86_64 | glibc | Ubuntu 24.04 x86_64 |
| aarch64-unknown-linux-gnu | aarch64 | glibc | Ubuntu 24.04 arm64 |

## Distribution Model

- One artifactbundle zip per triple
- Users download only the needed archive
- SwiftPM selects the archive via `Package.swift`

## Artifact Bundle Layout

```text
CLibsqlLinux-<triple>.artifactbundle/
├── info.json
├── include/
│   └── libsql.h
├── module.modulemap
└── CLibsql-<arch>/
    └── liblibsql.a
```

## Build Script

Build a single archive:

```bash
./Turso/scripts/build-linux-artifactbundle.sh \
  1.0.0 "" "" x86_64-unknown-linux-gnu CLibsqlLinux-x86_64-unknown-linux-gnu
```

Notes:

- `TRIPLE` controls `supportedTriples` in `info.json`.
- The script can build from source if `liblibsql.a` is missing.
- Planned: wrapper script to build both variants.

## Package Selection

Planned selection logic:

- If `LIBSQL_LINUX_TRIPLE` is set, use that triple.
- Otherwise, default to `*-unknown-linux-gnu` for the host arch.

## Fallback

`BuildLibsqlPlugin` stays as an optional fallback for unsupported setups.
