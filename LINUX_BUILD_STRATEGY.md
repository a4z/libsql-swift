# Linux Build Strategy for libsql-swift

I want to use Swift on the Server, that means, Linux

And I want to use Turso. But that requires Turso to run on Linux,
and I am not sure that is currently the case.

So we need to find a way to build Turso's libsql-swift on Linux.
And that means, we need to build the underlying C interface/Rust implementation
of SQLite3 as part of the build, otherwise, I have to switch to Go.

## Current State

The package currently uses `.binaryTarget` pointing to `CLibsql.xcframework` (Apple-only):

```swift
.binaryTarget(name: "CLibsql", path: "Sources/CLibsql/CLibsql.xcframework")
```

This prevents Linux builds since xcframework is macOS/iOS only.

## The Problem

- `CLibsql` wraps the Rust-based `libsql-c` library
- The library is available as a git submodule at `Sources/CLibsql/libsql-c`
- Build script exists at `Sources/CLibsql/libsql-c/build.sh` with Linux support:
  - `cargo build --target x86_64-unknown-linux-gnu --features encryption`
  - `cargo build --target aarch64-unknown-linux-gnu --features encryption`
- No apt package exists - must build from source

## Chosen Approach: SwiftPM Build Tool Plugin

Use a SwiftPM build tool plugin to invoke cargo during package build.

### How It Works

1. Plugin runs before Swift compilation
2. Detects target platform
3. Invokes `cargo build --release` with appropriate target triple
4. Outputs `liblibsql.a` static library
5. SwiftPM links the library into CLibsql target

### Benefits

- Cross-platform: works on macOS, Linux, etc.
- Automatic: builds during `swift build`
- No pre-built binaries needed
- Maintains existing Apple xcframework for optimal builds there

## Implementation Plan

### Step 1: Create Build Tool Plugin

Create `Plugins/BuildLibsqlPlugin/plugin.swift`:

```swift
import PackagePlugin
import Foundation

@main
struct BuildLibsqlPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let cargoPath = try context.tool(named: "cargo").path
        let libsqlSourceDir = context.package.directory.appending(["Sources", "CLibsql", "libsql-c"])
        let outputDir = context.pluginWorkDirectory

        // Determine target triple based on platform
        let targetTriple: String
        #if os(Linux)
            #if arch(x86_64)
            targetTriple = "x86_64-unknown-linux-gnu"
            #elseif arch(arm64)
            targetTriple = "aarch64-unknown-linux-gnu"
            #else
            throw PluginError.unsupportedArchitecture
            #endif
        #elseif os(macOS)
            #if arch(x86_64)
            targetTriple = "x86_64-apple-darwin"
            #elseif arch(arm64)
            targetTriple = "aarch64-apple-darwin"
            #else
            throw PluginError.unsupportedArchitecture
            #endif
        #else
        throw PluginError.unsupportedPlatform
        #endif

        return [
            .buildCommand(
                displayName: "Building libsql with cargo for \(targetTriple)",
                executable: cargoPath,
                arguments: [
                    "build",
                    "--release",
                    "--target", targetTriple,
                    "--features", "encryption"
                ],
                environment: [
                    "CARGO_TARGET_DIR": outputDir.string
                ],
                workingDirectory: libsqlSourceDir,
                outputFilesDirectory: outputDir
            )
        ]
    }
}

enum PluginError: Error {
    case unsupportedPlatform
    case unsupportedArchitecture
}
```

### Step 2: Update Package.swift

Replace the binary target approach with a plugin-based one:

```swift
var package = Package(
    name: "Libsql",
    platforms: [ .iOS(.v12), .macOS(.v10_13), .linux ], // Add Linux
    products: [
        .library(name: "Libsql", targets: ["Libsql"]),
        // ... examples
    ],
    targets: [
        // Build tool plugin
        .plugin(
            name: "BuildLibsqlPlugin",
            capability: .buildTool()
        ),

        // CLibsql target - platform conditional
        #if os(Linux)
        .target(
            name: "CLibsql",
            path: "Sources/CLibsql",
            sources: [], // No Swift/C sources, just headers
            publicHeadersPath: "libsql-c",
            cSettings: [
                .headerSearchPath("libsql-c")
            ],
            linkerSettings: [
                .unsafeFlags(["-L", ".build/plugins/outputs/BuildLibsqlPlugin"]),
                .linkedLibrary("libsql")
            ],
            plugins: ["BuildLibsqlPlugin"]
        ),
        #else
        .binaryTarget(
            name: "CLibsql",
            path: "Sources/CLibsql/CLibsql.xcframework"
        ),
        #endif

        .target(name: "Libsql", dependencies: ["CLibsql"]),
        .testTarget(name: "LibsqlTests", dependencies: ["Libsql"]),
        // ... examples
    ]
)
```

**Note:** SwiftPM doesn't support `#if os()` directly in Package.swift. Alternative approach needed.

### Step 3: Alternative - Unified Target Approach

Since conditional targets aren't supported, use a single approach:

```swift
targets: [
    .plugin(
        name: "BuildLibsqlPlugin",
        capability: .buildTool()
    ),

    .target(
        name: "CLibsql",
        path: "Sources/CLibsql",
        exclude: ["CLibsql.xcframework", "build.sh"], // Don't use xcframework
        publicHeadersPath: "libsql-c",
        plugins: ["BuildLibsqlPlugin"]
    ),

    .target(name: "Libsql", dependencies: ["CLibsql"]),
    // ... rest
]
```

This makes the plugin build on all platforms. For macOS, consider keeping xcframework for faster builds.

## Prerequisites

On the build machine (Linux):

```bash
# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Verify installation
cargo --version
rustc --version

# Clone and prepare
git clone <repo-url>
cd libsql-swift
git submodule update --init --recursive
```

## Testing Steps

```bash
# 1. Test cargo build manually first
cd Sources/CLibsql/libsql-c
cargo build --release --features encryption

# 2. Verify output
ls -la target/release/liblibsql.a

# 3. Test SwiftPM build (after plugin implementation)
cd ../../../
swift build

# 4. Run tests
swift test

# 5. Run examples
swift run Memory
```

## Key Challenges

1. **Plugin tool resolution**: cargo must be findable by SwiftPM
   - Solution: ensure cargo is in PATH or use absolute path

2. **Output path coordination**: SwiftPM needs to know where liblibsql.a is
   - Solution: use `context.pluginWorkDirectory` for deterministic output

3. **Header path**: Swift needs to find libsql.h
   - Solution: set `publicHeadersPath` to libsql-c directory

4. **Linking**: Need to tell linker where liblibsql.a is
   - Solution: use `.linkedLibrary()` and potentially `.unsafeFlags()` for library search path

## References

- [Swift Forums: Support building Rust targets in SPM](https://forums.swift.org/t/support-building-rust-targets-in-spm/33898)
- [Mozilla: Shipping Rust Components as Swift Packages](https://mozilla.github.io/application-services/book/design/swift-package-manager.html)
- [cargo-swift plugin](https://github.com/antoniusnaumann/cargo-swift)
- [SwiftPM Plugin Documentation](https://github.com/apple/swift-package-manager/blob/main/Documentation/Plugins.md)

## libsql-c Repository

- Submodule URL: <https://github.com/tursodatabase/libsql-c>
- Location: `Sources/CLibsql/libsql-c`
- Build script: `Sources/CLibsql/libsql-c/build.sh`
- Header: `Sources/CLibsql/libsql-c/libsql.h`

## Platform Differences: Module Structure

### macOS/iOS (Sources/CLibsql/)

- Uses pre-built `.xcframework` with embedded headers
- `module.modulemap` references `header "libsql.h"` directly
- Headers are inside the xcframework's platform-specific `Headers/` directories

### Linux (Sources/CLibsqlLinux/)

- Custom target created for Linux build
- Follows SwiftPM convention: headers in `include/` subdirectory
- `module.modulemap` references `header "include/libsql.h"`
- Header copied from `Sources/CLibsql/libsql-c/libsql.h` to `Sources/CLibsqlLinux/include/libsql.h`
- Library built by plugin and placed in `.build/plugins/outputs/.../liblibsql.so`

## Next Steps

1. Create `Plugins/BuildLibsqlPlugin/plugin.swift` ✅
2. Modify `Package.swift` to use plugin ✅
3. Test manual cargo build on Linux ✅
4. Test SwiftPM build with plugin ✅
5. Iterate on linker settings until it works ✅
6. Document build requirements in README

## TODO / Future Improvements

### Plugin Implementation

- [ ] **Replace bash script with pure Swift implementation**
  - Currently using generated bash script for cargo invocation
  - Could use `Process` directly in Swift for better integration
  - Would eliminate bash dependency and make error handling cleaner
  - Tradeoff: More complex Swift code vs simpler bash script

### Rebuild Detection

- [ ] **Improve rebuild detection beyond Cargo.toml timestamp**
  - Current limitation: Only checks if `Cargo.toml` changed
  - Missing cases:
    - Rust source file changes (`.rs` files)
    - Git submodule updates (new commits in libsql-c)
    - `Cargo.lock` changes (dependency updates)
    - Build configuration changes
  - Options to consider:
    - Check `Cargo.lock` timestamp as well
    - Track git submodule commit hash (save in `.last-build-commit`)
    - Remove check entirely and let cargo handle it (fast incremental builds)
    - Check all Rust source files (expensive but thorough)

### Runtime Library Loading

- [ ] **Fix LD_LIBRARY_PATH requirement for running executables**
  - Current workaround: Must set `LD_LIBRARY_PATH` to run examples
  - Example: `LD_LIBRARY_PATH=.build/plugins/outputs/libsql-swift/CLibsqlLinux/destination/BuildLibsqlPlugin swift run Memory`
  - Possible solutions:
    - Add proper rpath support (attempted but $ORIGIN didn't work)
    - Install library to system path
    - Create wrapper scripts for examples
    - Copy library to executable directory

### Documentation

- [ ] Add Linux build instructions to README
- [ ] Document Rust/cargo prerequisite
- [ ] Document rebuild detection limitations
- [ ] Add troubleshooting section for common issues
