import Foundation
import PackagePlugin

@main
struct BuildLibsqlPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        #if os(Linux)
        return try createLinuxBuildCommands(context: context, target: target)
        #else
        // On macOS/iOS, use the xcframework - no build needed
        return []
        #endif
    }

    #if os(Linux)
    private func createLinuxBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let libsqlCPath = context.package.directory.appending(["Sources", "CLibsql", "libsql-c"])
        let cargoToml = libsqlCPath.appending("Cargo.toml")
        let targetDir = libsqlCPath.appending(["target", "release"])
        let builtLibrary = targetDir.appending("liblibsql.so")

        // Output directory provided by SwiftPM
        let outputDir = context.pluginWorkDirectory
        let outputLibrary = outputDir.appending("liblibsql.so")

        // Get HOME directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Build script that handles both cargo build and copy
        let buildScript = """
        #!/bin/bash
        set -e

        CARGO_TOML="\(cargoToml.string)"
        BUILT_LIB="\(builtLibrary.string)"
        OUTPUT_LIB="\(outputLibrary.string)"
        HOME_DIR="\(homeDir)"

        # Add common cargo paths to PATH
        export PATH="$HOME_DIR/.cargo/bin:/usr/local/bin:/usr/bin:$PATH"

        # Check if we need to rebuild
        if [ -f "$OUTPUT_LIB" ] && [ "$OUTPUT_LIB" -nt "$CARGO_TOML" ]; then
            echo "libsql library is up to date, skipping build"
            exit 0
        fi

        # Verify cargo is available
        if ! command -v cargo &> /dev/null; then
            echo "Error: cargo not found in PATH"
            echo "Searched in: $HOME_DIR/.cargo/bin, /usr/local/bin, /usr/bin"
            echo "Please ensure Rust is installed: https://rustup.rs"
            exit 1
        fi

        echo "Building libsql-c with cargo..."
        cd "\(libsqlCPath.string)"
        cargo build --release --features encryption

        echo "Copying library to output directory..."
        cp "$BUILT_LIB" "$OUTPUT_LIB"

        echo "Build complete: $OUTPUT_LIB"
        """

        let buildScriptPath = outputDir.appending("build-libsql.sh")
        try buildScript.write(toFile: buildScriptPath.string, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: buildScriptPath.string)

        return [
            .prebuildCommand(
                displayName: "Building libsql-c for Linux",
                executable: Path("/bin/bash"),
                arguments: [buildScriptPath.string],
                outputFilesDirectory: outputDir
            )
        ]
    }
    #endif
}

enum PluginError: Error {
    case cargoNotFound
}
