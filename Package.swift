// swift-tools-version: 5.9.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let libsqlDependencies: [Target.Dependency] = ["CLibsql"]

// SwiftPM passes -F (framework search path) to clang on Linux even though frameworks
// don't exist there. This causes a warning. We suppress it with this linker setting.
#if os(Linux)
    let linkerSettings: [LinkerSetting] = [
        .unsafeFlags(["-Xclang-linker", "-Wno-unused-command-line-argument"])
    ]
#else
    let linkerSettings: [LinkerSetting] = []
#endif

// Toggle for local development: set to true to use local builds instead of downloaded binaries
let useLocalBinaries = false

let clibsqlTarget: Target = {
    if useLocalBinaries {
        // Local builds for development
        #if os(Linux)
            #if arch(x86_64)
                let path = "Turso/CLibsqlLinux-x86_64-unknown-linux-gnu.artifactbundle"
            #elseif arch(arm64)
                let path = "Turso/CLibsqlLinux-aarch64-unknown-linux-gnu.artifactbundle"
            #else
                fatalError("Unsupported Linux architecture.")
            #endif
        #else
            let path = "Turso/CLibsql/CLibsql.xcframework"
        #endif
        return .binaryTarget(name: "CLibsql", path: path)
    } else {
        // Downloaded binaries from GitHub releases
        #if os(Linux)
            return .binaryTarget(
                name: "CLibsql",
                url: "https://github.com/a4z/libsql-swift/releases/download/lsqlc-0.0.1/CLibsqlLinux-x86_64-unknown-linux-gnu.artifactbundle.zip",
                checksum: "cc8d804e9649a42a7c141a6060561f57b81e26d9d0837a4be99337d4aa54bf37"
            )
        #else
            return .binaryTarget(
                name: "CLibsql",
                url: "https://github.com/a4z/libsql-swift/releases/download/lsqlc-0.0.1/CLibsql.xcframework.zip",
                checksum: "37de28c475ed5de5cbb9eebe493ad5b16b8dec8e70f415af0eb4ef6ec9588803"
            )
        #endif
    }
}()

var package = Package(
    name: "Libsql",
    platforms: [.iOS(.v12), .macOS(.v10_13)],
    products: [
        .library(name: "Libsql", targets: ["Libsql"]),

        // Examples
        .executable(name: "Query", targets: ["Query"]),
        .executable(name: "Transaction", targets: ["Transaction"]),
        .executable(name: "Batch", targets: ["Batch"]),
    ],
    targets: [
        .target(
            name: "Libsql",
            dependencies: libsqlDependencies

        ),
        clibsqlTarget,
        .testTarget(name: "LibsqlTests", dependencies: ["Libsql"], linkerSettings: linkerSettings),

        // Examples
        .executableTarget(
            name: "Query",
            dependencies: ["Libsql"],
            path: "Examples/Query",
            linkerSettings: linkerSettings
        ),
        .executableTarget(
            name: "Transaction",
            dependencies: ["Libsql"],
            path: "Examples/Transaction",
            linkerSettings: linkerSettings
        ),
        .executableTarget(
            name: "Batch",
            dependencies: ["Libsql"],
            path: "Examples/Batch",
            exclude: ["README.md"],
            linkerSettings: linkerSettings
        ),
        .executableTarget(
            name: "Local",
            dependencies: ["Libsql"],
            path: "Examples/Local",
            exclude: ["README.md"],
            linkerSettings: linkerSettings
        ),
        .executableTarget(
            name: "Memory",
            dependencies: ["Libsql"],
            path: "Examples/Memory",
            exclude: ["README.md"],
            linkerSettings: linkerSettings
        ),
        .executableTarget(
            name: "Remote",
            dependencies: ["Libsql"],
            path: "Examples/Remote",
            exclude: ["README.md"],
            linkerSettings: linkerSettings
        ),
        .executableTarget(
            name: "RemoteSync",
            dependencies: ["Libsql"],
            path: "Examples/RemoteSync",
            exclude: ["README.md"],
            linkerSettings: linkerSettings
        ),        
        .executableTarget(
            name: "Sync",
            dependencies: ["Libsql"],
            path: "Examples/Sync",
            exclude: ["README.md"],
            linkerSettings: linkerSettings
        ),
        .executableTarget(
            name: "Transactions",
            dependencies: ["Libsql"],
            path: "Examples/Transactions",
            exclude: ["README.md"],
            linkerSettings: linkerSettings
        ),
        .executableTarget(
            name: "Vector",
            dependencies: ["Libsql"],
            path: "Examples/Vector",
            exclude: ["README.md"],
            linkerSettings: linkerSettings
        ),
    ]
)
