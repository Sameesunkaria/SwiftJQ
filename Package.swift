// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftJQ",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12),
        .watchOS(.v3),
        .tvOS(.v10)
    ],
    products: [
        .library(
            name: "SwiftJQ",
            targets: ["SwiftJQ"]),
    ],
    targets: [
        .target(
            name: "SwiftJQ",
            dependencies: ["Cjq", "Coniguruma"]),
        .testTarget(
            name: "SwiftJQTests",
            dependencies: ["SwiftJQ"],
            resources: [.process("Resources")]),
        .binaryTarget(
            name: "Cjq",
            url: "https://github.com/Sameesunkaria/JQ-Darwin/releases/download/1.0.0/Cjq.xcframework.zip",
            checksum: "60d6ac4ccbf6d56e0437122665182acd8f58b725d56cbeafcb956ab8da80afad"),
        .binaryTarget(
            name: "Coniguruma",
            url: "https://github.com/Sameesunkaria/JQ-Darwin/releases/download/1.0.0/Coniguruma.xcframework.zip",
            checksum: "0d4013da2c53e05063a3452e1f013350c1979611a311478049f203f154f92794"),
    ]
)
