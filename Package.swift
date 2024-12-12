// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ocrit",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.0"),
        .package(url: "https://github.com/kylef/PathKit", from: "1.0.1")
    ],
    targets: [
        .executableTarget(
            name: "ocrit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "PathKit", package: "PathKit")
            ]),
        .testTarget(
            name: "ocritTests",
            dependencies: ["ocrit"],
            exclude: ["Resources/ocrit-fixtures.sketch"],
            resources: [
                .copy("Resources/test-en.png"),
                .copy("Resources/test-pt.png"),
                .copy("Resources/test-zh.png"),
                .copy("Resources/test-multi-en-ko.png"),
                .copy("Resources/test-en-singlepage.pdf"),
                .copy("Resources/test-en-multipage.pdf"),
            ]
        ),
    ]
)
