# Linux Binary Distribution Strategy for libsql-swift

## Goal

- Avoid rebuilding `libsql-c` on every Linux build
- Ship pre-built artifactbundles with headers and module map
- Keep downloads minimal with one artifact per target triple

## Current State

- macOS/iOS: `Turso/CLibsql/CLibsql.xcframework`
- Linux: `Turso/CLibsqlLinux.artifactbundle.zip` (x86_64 gnu)
- Build script: `Turso/scripts/build-linux-artifactbundle.sh`

## Target Matrix (Planned)

| Triple | Arch | Libc | Use case |
| --- | --- | --- | --- |
| x86_64-unknown-linux-gnu | x86_64 | glibc | Ubuntu 24.04 x86_64 |
| aarch64-unknown-linux-gnu | aarch64 | glibc | Linux dev containers on ARM |
| x86_64-unknown-linux-musl | x86_64 | musl | Static Linux SDK (x86_64) |
| aarch64-unknown-linux-musl | aarch64 | musl | Static Linux SDK (arm64) |

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
- Planned: wrapper script to build all four variants.

## Package Selection

Planned selection logic:

- If `LIBSQL_LINUX_TRIPLE` is set, use that triple.
- Otherwise, default to `*-unknown-linux-gnu` for the host arch.

This keeps the default simple and allows musl users to opt in.

## musl Notes

The musl variants are intended for the Swift Static Linux SDK:

- Build libsql-c with `*-unknown-linux-musl`.
- Build Swift with `--swift-sdk x86_64-swift-linux-musl` or
  `--swift-sdk aarch64-swift-linux-musl`.
- The artifact must match the Swift SDK triple.

## Fallback

`BuildLibsqlPlugin` stays as an optional fallback for unsupported setups.
