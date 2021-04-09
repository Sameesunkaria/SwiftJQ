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
            url: "https://github.com/Sameesunkaria/JQ-Darwin/releases/download/1.0.1/Cjq.xcframework.zip",
            checksum: "67ec20a7f2fd61c946476bec28eabfb1a1c971c412454f15ff646cfc5d7fb603"),
        .binaryTarget(
            name: "Coniguruma",
            url: "https://github.com/Sameesunkaria/JQ-Darwin/releases/download/1.0.1/Coniguruma.xcframework.zip",
            checksum: "c307ff4552ab8e110e3ecaf7bf4823991cc5dd059065b32e1b3daf9d15fe7081"),
    ]
)

import Foundation

// Temporary workaround so builds on watchOS pass.
// watchOS will support XCTest with Xcode 12.5.
if ProcessInfo.processInfo.environment["DISABLE_TESTS"] == "true" {
    package.targets.removeAll(where: \.isTest)
}
