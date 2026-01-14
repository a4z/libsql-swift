// swift-tools-version: 5.9.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let libsqlDependencies: [Target.Dependency] = ["CLibsql"]

#if os(Linux)
let binaryDependencyPath: String = {
    #if arch(x86_64)
    return "Turso/CLibsqlLinux-x86_64-unknown-linux-gnu.artifactbundle.zip"
    #elseif arch(arm64)
    return "Turso/CLibsqlLinux-aarch64-unknown-linux-gnu.artifactbundle.zip"
    #else
    fatalError("Unsupported Linux architecture.")
    #endif
}()
#else
let binaryDependencyPath = "Turso/CLibsql/CLibsql.xcframework"
#endif

let clibsqlTarget: Target = .binaryTarget(
    name: "CLibsql",
    path: binaryDependencyPath
)

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
        .testTarget(name: "LibsqlTests", dependencies: ["Libsql"]),

        // Examples
        .executableTarget(
            name: "Query",
            dependencies: ["Libsql"],
            path: "Examples/Query"
        ),
        .executableTarget(
            name: "Transaction",
            dependencies: ["Libsql"],
            path: "Examples/Transaction"
        ),
        .executableTarget(
            name: "Batch",
            dependencies: ["Libsql"],
            path: "Examples/Batch",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "Local",
            dependencies: ["Libsql"],
            path: "Examples/Local",
            exclude: ["README.md",]
        ),
        .executableTarget(
            name: "Memory",
            dependencies: ["Libsql"],
            path: "Examples/Memory",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "Remote",
            dependencies: ["Libsql"],
            path: "Examples/Remote",
            exclude: [
                "README.md", 
            ]
        ),
        .executableTarget(
            name: "Sync",
            dependencies: ["Libsql"],
            path: "Examples/Sync",
            exclude: [
                "README.md", 
            ]
        ),
        .executableTarget(
            name: "Transactions",
            dependencies: ["Libsql"],
            path: "Examples/Transactions",
            exclude: ["README.md",]
        ),
        .executableTarget(
            name: "Vector",
            dependencies: ["Libsql"],
            path: "Examples/Vector",
            exclude: ["README.md"]
        ),
    ]
)
