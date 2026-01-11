# Plan: XCFramework Release Flow

Set up a tag-triggered pipeline that rebuilds the Apple xcframework on-demand, ships it as a GitHub Release asset, and refactors Package.swift so macOS and Linux consumers stay aligned without committing binaries.

### Steps

1. Add `.github/workflows/release-xcf.yml` triggered by tags matching `xcf-*`; checkout with submodules and run `Turso/scripts/build-xcframework.sh`, then upload the archive as both a build artifact and a GitHub Release asset.
2. Update `build-xcframework.sh` to emit into a temp directory and record the archive checksum so the workflow can feed it into the release metadata.
3. Refactor Package.swift: Apple uses `.binaryTarget(name: "CLibsql", url: ..., checksum: ...)` pointing to the release asset; Linux still compiles via `CLibsqlLinux` + `BuildLibsqlPlugin`.
4. Remove `Turso/CLibsql/CLibsql.xcframework` from the repo and adjust docs (README/context) to describe the `xcf-*` tagging scheme and new consumption model.

### Constraints / Decisions

1. Use GitHub-hosted macOS and Linux runners for the release workflow; they provide the required tooling for `build-xcframework.sh`.
2. `xcf-*` tags remain independent from package tags so xcframework releases can track Turso drops (or temporary builds) without affecting the main versioning scheme.
