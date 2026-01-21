# Linux Binary Matrix (Ubuntu 24.04 GNU)

## Goal

Add Linux ARM support by shipping two separate artifactbundles for
Ubuntu 24.04 (x86_64 + aarch64) and selecting them by target triple.

## Decisions

- Separate archive per triple to keep downloads minimal.
- Selection via `LIBSQL_LINUX_TRIPLE` in `Package.swift`.
- Default to `*-unknown-linux-gnu` for the host arch.
- Keep `BuildLibsqlPlugin` as optional fallback for now.

## Plan (iterative)

1. Update build tooling
   - Extend `Turso/scripts/build-linux-artifactbundle.sh` to allow a
     triple-based archive name.
   - Add a wrapper script to build both artifacts in one run.
2. Update `Package.swift`
   - Compute `binaryDependencyPath` from `LIBSQL_LINUX_TRIPLE`, or
     from `#if arch(...)` defaults.
   - Map to the corresponding artifact zip name.
3. Update docs
   - `context.md/LINUX_BINARY_DISTRIBUTION.md`
   - `context.md/LINUX_BUILD_STRATEGY.md`
4. Validate
   - `swift build` on Linux gnu (x86_64 and arm64).
   - Confirm the correct artifact is selected.

## Notes

- Static linking (musl) is postponed and tracked for a later task.

## Questions

- Final artifact naming scheme?
