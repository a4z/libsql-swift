# Refactor source locations

I have a few problems with VS Code and SourceKit in this project, and I wonder if it is because the CLibsql and CLibsqlLinux are in the Source folder

`@testable import`  does not work, and autocompletion on everything coming from Libsql fails.
There is no autocompletion.

This problem is not available on Linux, so I wonder, if the reason is that I have so much non Swift Code in the Source folder,
and I want to check if I can move it out.

Problem: Sources/CLibsql/libsql-c is a git sub module. So if we can move, we need to move that.

So basically, we move the xc-framework on MacOS and the Linux library builds into the top level of the project.

Let me know

- if that is techical possible
- if there are any questions

## Solution

Move all three folders (CLibsql, CLibsqlLinux, Libsql) into a new `Turso/` subfolder at the root level.

### New Structure

```txt
/Turso/
  /CLibsql/
    /CLibsql.xcframework/
    /libsql-c/  (git submodule)
    /build.sh
    /module.modulemap
  /CLibsqlLinux/
    /include/
    /module.modulemap
  /Libsql/
    /Libsql.swift
```

### Execution Plan

1. **Clean existing builds and caches**
   - Run `swift package clean` to clear Swift package build artifacts
   - Remove old XCFramework build (if any temporary builds exist)
   - Ensure starting from a clean state

2. **Check dependencies and scripts**
   - Check `.gitmodules` for submodule configuration
   - Check `Sources/CLibsql/build.sh` for path references
   - Check the build plugin for any hardcoded paths

3. **Create new directory structure**
   - Create `Turso/` directory at root
   - Move `Sources/Libsql` → `Turso/Libsql`
   - Move `Sources/CLibsql` → `Turso/CLibsql`
   - Move `Sources/CLibsqlLinux` → `Turso/CLibsqlLinux`

4. **Update git submodule configuration**
   - Update `.gitmodules` to point to new submodule path: `Turso/CLibsql/libsql-c`
   - Run `git submodule sync` to update configuration

5. **Update Package.swift**
   - Update Libsql target path: `path: "Turso/Libsql"`
   - Update CLibsql binary target path: `path: "Turso/CLibsql/CLibsql.xcframework"`
   - Update CLibsqlLinux target path: `path: "Turso/CLibsqlLinux"`

6. **Update any scripts with hardcoded paths**
   - Update build.sh if needed
   - Update plugin.swift if needed

7. **Rebuild the XCFramework**
   - Run the build script to build the XCFramework from scratch
   - This simulates a fresh checkout and ensures everything works end-to-end
   - Note: Linux build cannot be tested on macOS, will be verified later on Linux machine

8. **Verify the changes**
   - Run `swift package resolve` to verify package structure
   - Test build on macOS
   - Run tests with `swift test`
   - Verify SourceKit/autocomplete works

9. **Clean up**
   - Remove old `Sources/` directories (should be empty except for .gitkeep if needed)
   - Commit changes
