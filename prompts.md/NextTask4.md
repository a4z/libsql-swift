# Linux Binary Matrix (GNU + musl)

## Goal

Add Linux ARM and musl support by shipping four separate artifactbundles
and selecting them by target triple.

## Decisions

- Separate archive per triple to keep downloads minimal.
- Selection via `LIBSQL_LINUX_TRIPLE` in `Package.swift`.
- Default to `*-unknown-linux-gnu` for the host arch.
- Keep `BuildLibsqlPlugin` as optional fallback for now.

## Plan (iterative)

1. Update build tooling
   - Extend `Turso/scripts/build-linux-artifactbundle.sh` to allow a
     triple-based archive name.
   - Add a wrapper script to build all four artifacts in one run.
2. Update `Package.swift`
   - Compute `binaryDependencyPath` from `LIBSQL_LINUX_TRIPLE`, or
     from `#if arch(...)` defaults.
   - Map to the corresponding artifact zip name.
3. Update docs
   - `context.md/LINUX_BINARY_DISTRIBUTION.md`
   - `context.md/LINUX_BUILD_STRATEGY.md`
4. Validate
   - `swift build` on Linux gnu (x86_64 and arm64).
   - musl build using Swift Static Linux SDK.
   - Confirm the correct artifact is selected.

## Questions

- Final artifact naming scheme?
- Do we want any auto-detection of musl, or env-var only?
