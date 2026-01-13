# VS Code IDE Issues with Binary Targets

## Problem

When using VS Code with the Swift extension, autocomplete and `@testable import` were not working for the `Libsql` module.

## Root Cause

SourceKit-LSP's background indexing system uses `swift build --experimental-prepare-for-indexing` with a separate build directory (`.build/index-build/`). When a package uses a **binary target** (XCFramework), the static library file is not automatically copied or linked into this index build directory.

The indexing build failed with:

```txt
error: couldn't build Libsql.swiftmodule because of missing inputs:
/Users/a4z/hands/swift/libsql-swift/.build/index-build/arm64-apple-macosx/debug/liblibsql.a
```

The actual library exists in:

```txt
Turso/CLibsql/CLibsql.xcframework/macos-arm64/liblibsql.a
```

But SourceKit couldn't find it in the index-build directory where it expected it.

## Why Linux Works

On Linux, the package doesn't use an XCFramework. Instead, it builds the library from source using the `BuildLibsqlPlugin` build plugin. This means the library is built directly into the index-build directory, so SourceKit can find it without issues.

## Solution

### Option 1: Configure SourceKit-LSP

Create a `.sourcekit-lsp/config.json` file with:

```json
{
  "backgroundPreparationMode": "build"
}
```

This tells SourceKit-LSP to use the regular build system instead of the separate indexing build, which resolves the binary target issue. After creating this file and reloading VS Code, autocomplete and `@testable import` work correctly.

See <https://github.com/swiftlang/sourcekit-lsp/blob/main/Documentation/Configuration%20File.md> for more info

### Option 2: Create Symlink (Alternative)

If you prefer to keep the separate indexing build, create a symlink from the index-build directory to the actual library in the XCFramework:

```bash
mkdir -p .build/index-build/arm64-apple-macosx/debug
ln -sf "$PWD/Turso/CLibsql/CLibsql.xcframework/macos-arm64/liblibsql.a" \
       .build/index-build/arm64-apple-macosx/debug/liblibsql.a
```

After creating the symlink and reloading VS Code, autocomplete and `@testable import` work correctly.

## Potential Automation

**Note**: With the `.sourcekit-lsp/config.json` configuration (Option 1), no automation is needed as it's a one-time setup that's committed to the repository.

With the symlink approach (Option 2), the symlink needs to be recreated if:

- The `.build/` directory is cleaned
- The project is cloned fresh

Possible solutions:

1. **Post-build script**: Add a script that creates the symlink after building
2. **Git hook**: Use a post-checkout hook to create the symlink
3. **Package plugin**: Potentially create a plugin that handles this (though plugins may not run for indexing builds)
4. **Developer documentation**: Document this as a setup step for contributors

## Notes

This is a known limitation when using binary targets with SourceKit-LSP. The VS Code Swift extension uses a separate indexing build that doesn't have the same linking setup as regular builds, which is why `swift build` and `swift test` work fine but IDE features don't.
