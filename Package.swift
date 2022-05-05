// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ocrit",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "ocrit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "ocritTests",
            dependencies: ["ocrit"],
            exclude: ["Resources/ocrit-fixtures.sketch"],
            resources: [
                .copy("Resources/test-en.png"),
                .copy("Resources/test-pt.png"),
                .copy("Resources/test-zh.png")
            ]
        ),
    ]
)
