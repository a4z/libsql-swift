import Foundation
import PackagePlugin

@main
struct BuildLibsqlPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        #if os(Linux)
        return try createLinuxBuildCommands(context: context)
        #else
        // On macOS/iOS, use the xcframework - no build needed
        return []
        #endif
    }

    #if os(Linux)
    private func createLinuxBuildCommands(context: PluginContext) throws -> [Command] {
        let libsqlCPath = context.package.directory.appending(["Sources", "CLibsql", "libsql-c"])
        let cargoToml = libsqlCPath.appending("Cargo.toml")
        let outputDir = context.pluginWorkDirectory
        let cargoTargetDir = outputDir.appending("release")
        let pathIncludingCargo = makePathIncludingCargo()

        return [
            .prebuildCommand(
                displayName: "Building libsql-c (cargo --release)",
                executable: Path("/usr/bin/env"),
                arguments: [
                    "cargo",
                    "build",
                    "--release",
                    "--features",
                    "encryption",
                    "--manifest-path",
                    cargoToml.string,
                    "--target-dir",
                    outputDir.string
                ],
                environment: [
                    "PATH": pathIncludingCargo
                ],
                outputFilesDirectory: cargoTargetDir
            )
        ]
    }

    private func makePathIncludingCargo() -> String {
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let cargoBin = "\(homeDir)/.cargo/bin"
        return "\(cargoBin):\(envPath)"
    }
    #endif
}
