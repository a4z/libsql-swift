# Binary build on CI

libsql-c does not change very often, probably never again.

Therefore, it makes sense to provide the XCFramework and the Linux Artifact bundle builds as downloads from GitHub.

## Release Action

Create a GitHub Actions workflow that:

1. **Triggers on tags** starting with `lsqlc` (e.g., `lsqlc-0.3.2`)
2. **Checks out the `dev` branch**
3. **Builds:**
   - macOS/iOS XCFramework (using `build-xcframework.sh`)
   - Linux x86_64 artifactbundle (using `build-linux-artifactbundle.sh`)
4. **Creates a GitHub Release** named after the tag, with the artifacts attached

**Note:** Linux aarch64 is not built on CI (no GitHub runner available). It can be added manually when building locally on Mac if needed.

## Package Consumption

The Swift package should consume the released artifacts via binary targets with URLs pointing to the GitHub release.

For local development, it should be easy to switch between:

- **Downloaded binaries** (default, from GitHub releases)
- **Local builds** (for development/debugging)

This can be achieved with a toggle boolean or by commenting out the binary dependency in `Package.swift`.

## Implementation Order

1. **Create the release workflow** - build and publish artifacts to GitHub releases
2. **Update Package.swift** - consume the released binaries (after first release exists)
