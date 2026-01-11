# Linux Binary Distribution Strategy for libsql-swift

## Problem

Building the Rust-based `libsql-c` library from source on every CI run is slow compared to using pre-built binaries on macOS (xcframework). For Ubuntu 24.04 LTS (our only target), we can distribute pre-built binaries to speed up CI builds.

## Current State

- **macOS/iOS**: Uses `.binaryTarget` with pre-built `CLibsql.xcframework` (fast ✅)
- **Linux**: Builds from source via `BuildLibsqlPlugin` every time (slow ❌)

## Solutions Comparison

### Option 1: ArtifactBundle with Remote URL (Limited Support)

SPM supports `.binaryTarget` with artifactbundles on Linux (since Swift 5.6), but has limitations.

**Pros:**

- "Official" SPM way to distribute binaries
- Automatic download and caching by SPM

**Cons:**

- ⚠️ **Poor platform detection**: SPM's artifactbundle `supportedTriples` only matches exact platform strings
- Requires exact match for `x86_64-unknown-linux-gnu` - doesn't account for Ubuntu version, glibc version, etc.
- ABI compatibility issues across different Linux distributions
- Limited documentation and examples for Linux
- Still experimental feel

**Structure:**

```txt
libsql-linux-x86_64.artifactbundle/
├── info.json
└── libsql-linux-x86_64/
    └── liblibsql.a
```

**info.json:**

```json
{
  "schemaVersion": "1.0",
  "artifacts": {
    "libsql-linux-x86_64": {
      "version": "1.0.0",
      "type": "library",
      "variants": [
        {
          "path": "libsql-linux-x86_64/liblibsql.a",
          "supportedTriples": ["x86_64-unknown-linux-gnu"]
        }
      ]
    }
  }
}
```

**Package.swift:**

```swift
.binaryTarget(
    name: "CLibsqlLinuxBinary",
    url: "https://github.com/YOUR_ORG/libsql-swift/releases/download/v1.0.0/libsql-linux-x86_64.artifactbundle.zip",
    checksum: "abc123..."
),
```

**Verdict:** ❌ Not recommended - too fragile for Linux, better for Apple platforms

---

### Option 2: Plugin with Pre-built Binary Download (Recommended)

Enhance the existing `BuildLibsqlPlugin` to download a pre-built binary when available, with fallback to building from source.

**Pros:**

- ✅ Fast CI builds when binary is available
- ✅ Graceful fallback to source build for development
- ✅ Simple environment variable control
- ✅ Works with existing plugin infrastructure
- ✅ No SPM platform matching issues
- ✅ Can version-control with git tags or releases

**Cons:**

- Custom implementation (not "pure" SPM)
- Need to host the binary somewhere (GitHub Releases works great)

**How it works:**

1. **Check environment variable** `LIBSQL_PREBUILT_BINARY_URL`
2. **If set**: Download the `.a` file from URL
3. **If not set**: Build from source with cargo (current behavior)

**Modified plugin logic:**

```swift
#if os(Linux)
private func createLinuxBuildCommands(context: PluginContext) throws -> [Command] {
    let outputDir = context.pluginWorkDirectory
    let cargoTargetDir = outputDir.appending("release")

    // Option A: Download pre-built binary
    if let binaryURL = ProcessInfo.processInfo.environment["LIBSQL_PREBUILT_BINARY_URL"] {
        return [
            .prebuildCommand(
                displayName: "Downloading pre-built libsql binary",
                executable: Path("/usr/bin/env"),
                arguments: [
                    "bash", "-c",
                    """
                    mkdir -p "\(cargoTargetDir.string)"
                    curl -L -o "\(cargoTargetDir.string)/liblibsql.a" "\(binaryURL)"
                    """
                ],
                outputFilesDirectory: cargoTargetDir
            )
        ]
    }

    // Option B: Build from source (current implementation)
    return [/* current cargo build command */]
}
#endif
```

**Usage:**

**CI (fast):**

```bash
export LIBSQL_PREBUILT_BINARY_URL="https://github.com/YOUR_ORG/libsql-swift/releases/download/v1.0.0/liblibsql-ubuntu24.a"
swift build
```

**Development (build from source):**

```bash
swift build  # No env var = builds from source
```

**Verdict:** ✅ **RECOMMENDED**

---

### Option 3: Vendored Pre-built Binary in Repository

Commit the pre-built `liblibsql.a` directly to the repository and skip the plugin on Linux.

**Pros:**

- Fastest: no download, no build
- Simple: just link against checked-in file

**Cons:**

- ❌ Bloats git repository (~20-30MB binary)
- ❌ Makes git clones slower
- ❌ Harder to update (need to rebuild and commit)
- ❌ Git LFS might be needed

**Structure:**

```
Turso/CLibsqlLinux/
├── include/
│   └── libsql.h
├── lib/
│   └── liblibsql.a          # Pre-built, checked in
└── module.modulemap
```

**Package.swift:**

```swift
.target(
    name: "CLibsqlLinux",
    path: "Turso/CLibsqlLinux",
    linkerSettings: [
        .unsafeFlags(["-L", "Turso/CLibsqlLinux/lib", "-l:liblibsql.a"])
    ]
    // No plugin needed!
)
```

**Verdict:** ⚠️ Possible but not recommended - repository bloat is annoying

---

## Recommended Implementation: Option 2

### Step 1: Build and Release Binary

Create `Turso/scripts/build-linux-release.sh`:

```bash
#!/bin/bash
set -e

VERSION=${1:-"1.0.0"}
TARGET="x86_64-unknown-linux-gnu"
OUTPUT_NAME="liblibsql-ubuntu24-${VERSION}.a"

echo "Building libsql-c for Linux..."
cd Turso/CLibsql/libsql-c

cargo build --release --features encryption --target ${TARGET}

echo "Copying binary..."
cp target/${TARGET}/release/liblibsql.a ../../${OUTPUT_NAME}

echo "✅ Created: ${OUTPUT_NAME}"
echo ""
echo "Upload this to GitHub Releases:"
echo "  gh release create v${VERSION} ${OUTPUT_NAME}"
```

**Run on Ubuntu 24.04:**

```bash
./Turso/scripts/build-linux-release.sh 1.0.0
gh release create v1.0.0 liblibsql-ubuntu24-1.0.0.a
```

### Step 2: Update BuildLibsqlPlugin

Modify `Plugins/BuildLibsqlPlugin/plugin.swift`:

1. Check for `LIBSQL_PREBUILT_BINARY_URL` environment variable
2. If set: download binary with curl/wget
3. If not set: build from source (current behavior)
4. Add caching: don't re-download if file exists

### Step 3: Update CI Configuration

**GitHub Actions example:**

```yaml
- name: Build (using pre-built binary)
  env:
    LIBSQL_PREBUILT_BINARY_URL: https://github.com/${{ github.repository }}/releases/download/v1.0.0/liblibsql-ubuntu24-1.0.0.a
  run: swift build
```

### Step 4: Update Documentation

Add to README:

```markdown
## Building on Linux

### Fast builds (CI)

Use a pre-built binary:

export LIBSQL_PREBUILT_BINARY_URL="https://github.com/YOUR_ORG/libsql-swift/releases/download/v1.0.0/liblibsql-ubuntu24-1.0.0.a"
swift build

### Development builds

Build from source (requires Rust/cargo):

swift build
```

---

## Binary Compatibility Notes

**Target platform:** Ubuntu 24.04 LTS x86_64

**Dependencies:**

- Built with: `x86_64-unknown-linux-gnu` target
- Links against: glibc (system version on Ubuntu 24.04)
- Static library: includes all Rust dependencies

**Compatibility:**

- ✅ Same Ubuntu version (24.04)
- ✅ Same architecture (x86_64)
- ⚠️ Other Ubuntu versions: likely works, but test
- ❌ Different distros: may have glibc version mismatches
- ❌ Different architectures (ARM): need separate builds

**Recommendation:**

- Build on Ubuntu 24.04 for Ubuntu 24.04
- If supporting multiple distros, create separate binaries per distro
- Always provide source build fallback

---

## File Locations

**Current:**

```
Turso/
├── CLibsql/
│   ├── CLibsql.xcframework/          # macOS/iOS binaries
│   ├── libsql-c/                     # Rust source
│   └── module.modulemap
└── CLibsqlLinux/
    ├── include/libsql.h              # Header
    └── module.modulemap
```

**With pre-built binary (Option 2):**

```
# Binary hosted on GitHub Releases, not in repo
https://github.com/YOUR_ORG/libsql-swift/releases/download/v1.0.0/liblibsql-ubuntu24-1.0.0.a

# Plugin downloads to:
.build/plugins/outputs/libsql-swift/CLibsqlLinux/destination/BuildLibsqlPlugin/release/liblibsql.a
```

**With vendored binary (Option 3):**

```
Turso/CLibsqlLinux/
├── include/libsql.h
├── lib/liblibsql.a                   # ⚠️ Checked into git
└── module.modulemap
```

---

## Migration Path

1. **Phase 1: Keep current source build** (status quo)
   - Works everywhere
   - CI is slow but reliable

2. **Phase 2: Add binary download option** (recommended next step)
   - Update plugin with env var check
   - Build and release binary for Ubuntu 24.04
   - Update CI to use binary
   - Development still builds from source

3. **Phase 3: Consider ArtifactBundle** (future, optional)
   - If SPM improves Linux support
   - Switch to "official" binary distribution
   - Remove custom plugin logic

---

## Testing Strategy

Before deploying binary distribution:

1. **Build binary on clean Ubuntu 24.04:**

   ```bash
   docker run -it --rm -v $PWD:/workspace ubuntu:24.04 bash
   # Install Rust + build
   ```

2. **Test binary on different machines:**
   - Same Ubuntu version (24.04)
   - Different Ubuntu versions (22.04, 23.10)
   - Different Swift versions

3. **Verify symbols:**

   ```bash
   nm -D liblibsql.a | grep libsql_
   file liblibsql.a
   ```

4. **Size check:**

   ```bash
   ls -lh liblibsql.a  # Should be ~20-30MB
   ```

5. **Run full test suite:**

   ```bash
   LIBSQL_PREBUILT_BINARY_URL="file:///path/to/liblibsql.a" swift test
   ```

---

## Recommended Action

✅ **Implement Option 2: Plugin with Binary Download**

**Why:**

- Fastest for CI (binary download is much faster than cargo build)
- Flexible: env var controls behavior
- Safe: fallback to source build always available
- Clean: no repository bloat
- Simple: small plugin modification

**Next steps:**

1. Create `Turso/scripts/build-linux-release.sh`
2. Build binary on Ubuntu 24.04
3. Upload to GitHub Releases
4. Modify `BuildLibsqlPlugin` to check env var
5. Update CI workflow to set `LIBSQL_PREBUILT_BINARY_URL`
6. Document in README
