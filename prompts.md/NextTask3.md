# Binary Artifact Distribution for Linux

## Goal

Implement pre-built binary distribution for Linux using SPM's `.artifactbundle` approach to speed up CI builds, matching the pattern used for macOS/iOS xcframework.

## Context

Currently, Linux builds compile `libsql-c` from source via `BuildLibsqlPlugin` on every CI run, which is slow (~5 minutes). macOS/iOS already uses pre-built binaries via `CLibsql.xcframework`. We want to bring the same speed benefits to Linux.

**Target Platform:** Ubuntu 24.04 LTS x86_64 (our only Linux target)

**Critical Insight:** The plugin approach in LINUX_BINARY_DISTRIBUTION.md doesn't properly handle the header file (`libsql.h`) and `module.modulemap` - it only addresses the binary library. The artifactbundle approach is the proper SPM-native solution that packages everything together:

- Static library (`liblibsql.a`)
- Header file (`libsql.h`)
- Module map (`module.modulemap`)

## Approach: ArtifactBundle with Local Testing

Use SPM's `.binaryTarget` with artifactbundle, which is the official way to distribute pre-built binaries with their headers and module maps.

**Testing Philosophy: "Build locally, use locally, test locally"**

- Build artifactbundle on this machine (Ubuntu 24.04)
- Use it in this project first (local path)
- Create external test project to verify consumption
- Only move to remote URLs after local testing proves it works

### Platform Detection Strategy

We control the deployment target. The artifactbundle's `supportedTriples: ["x86_64-unknown-linux-gnu"]` will match Ubuntu 24.04 builds. In Package.swift:

1. Keep existing `CLibsql` binary target for macOS (xcframework)
2. Add new `CLibsqlLinux` binary target for Linux (artifactbundle)
3. SwiftPM automatically selects the correct target by platform
4. Document clearly: "Linux support is for Ubuntu 24.04 x86_64 only"
5. Users on other distros can fork and build from source (cargo build still available)

## Implementation Tasks

### Phase 1: Build ArtifactBundle Locally

Create script `Turso/scripts/build-linux-artifactbundle.sh` that builds the complete artifactbundle:

**Step 1: Build the binary**

```bash
cd Turso/CLibsql/libsql-c
cargo build --release --features encryption --target x86_64-unknown-linux-gnu
```

**Step 2: Create artifactbundle directory structure**

```
libsql-linux.artifactbundle/
├── info.json
└── libsql-linux-x86_64/
    ├── lib/
    │   └── liblibsql.a
    ├── include/
    │   └── libsql.h
    └── module.modulemap
```

**Step 3: Generate `info.json`**

```json
{
  "schemaVersion": "1.0",
  "artifacts": {
    "libsql-linux-x86_64": {
      "version": "0.1.0",
      "type": "library",
      "variants": [
        {
          "path": "libsql-linux-x86_64",
          "supportedTriples": ["x86_64-unknown-linux-gnu"]
        }
      ]
    }
  }
}
```

**Step 4: Create `module.modulemap`**

```
module CLibsqlLinux {
    header "include/libsql.h"
    link "libsql"
    export *
}
```

**Step 5: Copy files**

- Copy `target/x86_64-unknown-linux-gnu/release/liblibsql.a` → `lib/liblibsql.a`
- Copy `libsql.h` from `Turso/CLibsql/libsql-c/` → `include/libsql.h`

**Step 6: Create zip**

```bash
zip -r libsql-linux.artifactbundle.zip libsql-linux.artifactbundle
```

**Step 7: Calculate checksum**

```bash
swift package compute-checksum libsql-linux.artifactbundle.zip
```

**Script outputs:**

- `libsql-linux.artifactbundle/` (directory)
- `libsql-linux.artifactbundle.zip` (for remote use)
- Checksum printed to stdout

### Phase 2: Update Package.swift for Local ArtifactBundle

Modify Package.swift to use the artifactbundle locally:

**Add new binary target:**

```swift
.binaryTarget(
    name: "CLibsqlLinux",
    path: "Turso/libsql-linux.artifactbundle"
)
```

**Keep existing macOS target:**

```swift
.binaryTarget(
    name: "CLibsql",
    path: "Turso/CLibsql/CLibsql.xcframework"
)
```

**Update Libsql target dependencies:**

```swift
.target(
    name: "Libsql",
    dependencies: [
        .target(name: "CLibsql", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
        .target(name: "CLibsqlLinux", condition: .when(platforms: [.linux]))
    ],
    // ... rest of configuration
)
```

**Important:** Investigate if we can use the same name "CLibsql" for both targets, or if separate names are required. SPM should choose the right one by platform.

**Deprecation:** Consider keeping `BuildLibsqlPlugin` for reference but not using it on Linux anymore. The artifactbundle replaces it.

### Phase 3: Local Testing - This Repo

Validate the artifactbundle works in this repository:

1. **Build the project:**

   ```bash
   swift build
   ```

   - Should be fast (<30 seconds for plugin phase)
   - Should NOT see cargo build output
   - Check `.build/artifacts/` for extracted artifactbundle

2. **Run tests:**

   ```bash
   swift test
   ```

   - All tests should pass
   - No compilation errors
   - No linking errors

3. **Run examples:**

   ```bash
   swift run Memory
   swift run Local
   ```

   - Should execute successfully
   - Verify database operations work

4. **Check build logs:**
   - Look for "Downloading" or "Copying" artifact messages
   - Confirm no Rust/cargo output appears

### Phase 4: External Test Project

Create a minimal test project to validate consumption:

**Step 1: Create test project**

```bash
mkdir ../libsql-swift-test
cd ../libsql-swift-test
swift package init --type executable
```

**Step 2: Add dependency to Package.swift**

```swift
dependencies: [
    .package(path: "../libsql-swift")
],
targets: [
    .executableTarget(
        name: "libsql-swift-test",
        dependencies: [
            .product(name: "Libsql", package: "libsql-swift")
        ]
    )
]
```

**Step 3: Write test code in main.swift**

```swift
import Libsql

// Create in-memory database
let db = try Database(path: ":memory:")
let conn = try db.connect()

// Create table and insert data
try conn.execute("""
    CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT);
    INSERT INTO test (name) VALUES ('Hello from artifactbundle!');
""")

// Query data
let rows = try conn.query("SELECT * FROM test")
for row in rows {
    print("ID: \(try row.get(0) as Int), Name: \(try row.get(1) as String)")
}

print("✅ Artifactbundle test successful!")
```

**Step 4: Build and run**

```bash
swift build
swift run
```

**Expected results:**

- Build completes quickly
- No cargo output
- Program runs and prints test data
- Success message appears

### Phase 5: Verify Platform Specificity

Ensure both targets work correctly:

**On Linux (this machine):**

- Should use `CLibsqlLinux` artifactbundle
- Check with: `swift build --verbose` (look for CLibsqlLinux references)

**On macOS (if available):**

- Should use `CLibsql` xcframework
- Should NOT use Linux artifactbundle
- No conflicts between targets

### Phase 6: Remote URL Preparation (Optional)

Once local testing succeeds, prepare for remote hosting:

1. **Upload to test GitHub Release:**

   ```bash
   gh release create test-v0.1.0 libsql-linux.artifactbundle.zip --notes "Test Linux artifactbundle"
   ```

2. **Update Package.swift to use remote URL:**

   ```swift
   .binaryTarget(
       name: "CLibsqlLinux",
       url: "https://github.com/YOUR_ORG/libsql-swift/releases/download/test-v0.1.0/libsql-linux.artifactbundle.zip",
       checksum: "abc123..." // from compute-checksum
   )
   ```

3. **Test clean build with remote URL:**

   ```bash
   rm -rf .build
   swift build
   ```

   - Should download from GitHub
   - Should cache locally
   - Second build should use cache (fast)

4. **Test external project with remote URL:**
   - Update test project to use remote libsql-swift
   - Verify download and build work

## Testing Strategy - Local First

### Test 1: Build Artifactbundle

- ✓ Run script on Ubuntu 24.04 (this machine)
- ✓ Verify directory structure is correct
- ✓ Check binary size (~20-30MB expected)
- ✓ Check symbols: `nm liblibsql.a | grep libsql_`
- ✓ Verify header file exists and has correct content
- ✓ Verify modulemap syntax is correct
- ✓ Verify info.json is valid JSON
- ✓ Verify zip is created successfully
- ✓ Calculate and record checksum

### Test 2: Local Dependency - This Repo

- ✓ Update Package.swift with local path
- ✓ Run `swift build` - should be fast
- ✓ No cargo output should appear
- ✓ Run `swift test` - all tests pass
- ✓ Run `swift run Memory` - executes successfully
- ✓ Check `.build/artifacts/` contains extracted artifactbundle

### Test 3: Local Dependency - External Test Project

- ✓ Create test project in `../libsql-swift-test`
- ✓ Add `.package(path: "../libsql-swift")` dependency
- ✓ Write simple database test code
- ✓ Build and run successfully
- ✓ Verify artifactbundle is being used (check build output)

### Test 4: Checksum and Packaging

- ✓ Generate checksum with `swift package compute-checksum`
- ✓ Verify checksum is deterministic (rebuild and recalculate)
- ✓ Document checksum for Package.swift

### Test 5: Platform Specificity

- ✓ Verify Linux uses CLibsqlLinux artifactbundle
- ✓ If macOS available, verify it uses CLibsql xcframework
- ✓ No conflicts between targets
- ✓ Correct automatic platform selection

### Test 6: Remote URL (Optional)

- ✓ Upload to test release
- ✓ Update Package.swift with URL
- ✓ Clean build downloads successfully
- ✓ Caching works (no re-download)
- ✓ External project works with remote URL

## Success Criteria

- [ ] Build script creates valid artifactbundle structure
- [ ] Artifactbundle includes: binary, header, modulemap in correct locations
- [ ] `info.json` is properly formatted with correct supportedTriples
- [ ] Zipped artifactbundle has valid checksum
- [ ] Package.swift references local artifactbundle path
- [ ] `swift build` in this repo is fast (<30sec plugin phase, no cargo)
- [ ] Full test suite passes with artifactbundle
- [ ] Examples run successfully
- [ ] External test project builds and runs with artifactbundle
- [ ] macOS builds still work with xcframework (no regression)
- [ ] Build time improved from ~5min to <30sec

## Open Questions & Research Needed

### 1. ArtifactBundle Structure

**Question:** What's the exact required structure for artifactbundles with headers?

- Are header files officially supported in artifactbundles?
- Does the modulemap go inside the artifact or in Package.swift target?
- What's the correct directory layout?

**Action:** Research SwiftPM documentation and existing examples. Test iteratively with small changes.

### 2. Module Naming

**Question:** Can we use the same name "CLibsql" for both macOS and Linux targets?

- Option A: Separate names (CLibsql for macOS, CLibsqlLinux for Linux)
- Option B: Same name, SPM chooses by platform

**Action:** Test both approaches. If same name works, prefer it for consistency.

### 3. supportedTriples String

**Question:** Is `x86_64-unknown-linux-gnu` the correct triple?

- Ubuntu 24.04 uses this target triple for cargo
- Does SPM match this exactly?
- What about musl vs gnu?

**Action:** Test with current triple. Check SPM documentation for platform matching rules.

### 4. Linker Settings

**Question:** Does artifactbundle need explicit linker settings in Package.swift?

- xcframework doesn't need extra linker flags
- Does artifactbundle handle this automatically?
- Do we need `linkerSettings: [.linkedLibrary("libsql")]`?

**Action:** Test minimal Package.swift first, add settings only if needed.

### 5. Version Coordination

**Question:** How to version the artifactbundle?

- Match libsql-c submodule commit hash?
- Independent versioning?
- Match Package.swift version?

**Decision:** Start with simple version (0.1.0), refine strategy based on experience.

## Dependencies

**Available on this machine:**

- ✓ Ubuntu 24.04 LTS system
- ✓ Rust toolchain (rustc, cargo)
- ✓ Swift toolchain
- ✓ zip/unzip utilities
- ✓ Basic shell scripting

**Not needed initially:**

- GitHub CLI (only for remote phase)
- CI configuration (only after local testing)
- GitHub repository access (only for remote phase)

## References

- [LINUX_BINARY_DISTRIBUTION.md](../context.md/LINUX_BINARY_DISTRIBUTION.md) - Previous analysis (needs update)
- [LINUX_BUILD_STRATEGY.md](../context.md/LINUX_BUILD_STRATEGY.md) - Current plugin implementation
- [SwiftPM Binary Targets](https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageDescription.md#binary-target)
- [SwiftPM Artifact Bundles](https://github.com/apple/swift-evolution/blob/main/proposals/0305-swiftpm-binary-target-improvements.md)
- Existing `BuildLibsqlPlugin` at `Plugins/BuildLibsqlPlugin/plugin.swift`
- Current `CLibsqlLinux` at `Turso/CLibsqlLinux/` (plugin-based)
- libsql-c submodule at `Turso/CLibsql/libsql-c`

## Key Insights

**Why artifactbundle is better than plugin download:**

1. ✅ **Complete packaging:** Includes binary, headers, and modulemap together
2. ✅ **SPM-native:** Proper package manager integration with caching
3. ✅ **Platform selection:** Automatic platform-based target selection
4. ✅ **Checksum verification:** Built-in integrity checking
5. ✅ **Consistent pattern:** Matches macOS xcframework approach
6. ✅ **No custom logic:** No environment variables or plugin modifications needed

**Addressing the "poor platform detection" concern from LINUX_BINARY_DISTRIBUTION.md:**

- We explicitly control our deployment target: Ubuntu 24.04 x86_64 only
- We document this requirement clearly
- The `x86_64-unknown-linux-gnu` triple matches our build target exactly
- Users on other distros can fork and use cargo build (source builds still work)
- This is not a general-purpose library for all Linux distros - it's for our specific use case

**Critical fix from original analysis:**

The plugin download approach in LINUX_BINARY_DISTRIBUTION.md is incomplete:

- ❌ Only addresses the `.a` binary file
- ❌ Doesn't handle `libsql.h` header
- ❌ Doesn't handle `module.modulemap`
- ❌ Requires custom plugin modifications and env vars

The artifactbundle approach solves all of these:

- ✅ Packages everything together
- ✅ SPM understands the complete structure
- ✅ Official Swift package manager solution

## Implementation Notes

**Incremental validation:**

1. First make the artifactbundle structure
2. Test it locally with path
3. Test external project consumption
4. Only then consider remote URLs
5. Document actual results, not assumptions

**If it doesn't work:**

- We'll know quickly during local testing
- Can adjust structure or approach
- Can fall back to plugin if necessary
- No CI or remote changes to undo

**Expected outcome:**

- Local testing proves artifactbundle works
- Much simpler than plugin approach
- Proper SPM integration
- Fast builds without cargo compilation

## Summary (2026-01-13)

**What changed:**

- Linux now uses a local artifactbundle zip, but the module/target name is unified as `CLibsql` on both Linux and macOS via a single `binaryDependencyPath`.
- Artifactbundle layout updated for SwiftPM: `type: staticLibrary` and `staticLibraryMetadata` with `headerPaths` + `moduleMapPath`.
- Linux module map renamed to `module CLibsql` so Swift imports are consistent.
- `BuildLibsqlPlugin` removed from `Package.swift` (no longer needed with artifactbundle).

**Script updates:**

- `Turso/scripts/build-linux-artifactbundle.sh` builds the artifactbundle with:
  - Root `include/` + `module.modulemap`
  - Artifact name `CLibsql`
  - Optional `SWIFTPM_BIN` override for checksum computation

**Local verification (Linux):**

- `swift build --disable-index-store`
- `swift test --disable-index-store`

**Checksum (local bundle):**

- `Turso/CLibsqlLinux.artifactbundle.zip`: `401645f15bbbdfb27c9248d96a65301cb81ef85502d020b0d1b1335f8de013de`

**Open issue to investigate:**

- Clang warning about unused `-F .../.build/.../debug` flags on Linux. This likely comes from SwiftPM framework flags (from binary targets), but we should find the clean way to avoid the warning.
