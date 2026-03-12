// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "axys",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "DSCore", targets: ["DSCore"]),
        .library(name: "DSDocSyncKit", targets: ["DSDocSyncKit"]),
        .executable(name: "dsctl", targets: ["DSCLI"]),
        .executable(name: "ds-doc-sync", targets: ["DSDocSync"]),
        .executable(name: "ds-mcp", targets: ["DSMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.4"),
        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.1"),
    ],
    targets: [
        .target(
            name: "DSCore",
            dependencies: [
                "DSDocSyncKit",
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .target(name: "DSDocSyncKit"),
        .target(
            name: "DSMCPKit",
            dependencies: [
                "DSCore",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .executableTarget(
            name: "DSCLI",
            dependencies: [
                "DSCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "DSDocSync",
            dependencies: [
                "DSCore",
                "DSDocSyncKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "DSMCP",
            dependencies: [
                "DSMCPKit",
            ]
        ),
        .testTarget(
            name: "DSCoreTests",
            dependencies: [
                "DSCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "DSMCPKitTests",
            dependencies: [
                "DSCore",
                "DSMCPKit",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "DSCLITests",
            dependencies: [
                "DSCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "DSDocSyncKitTests",
            dependencies: [
                "DSCore",
                "DSDocSyncKit",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
