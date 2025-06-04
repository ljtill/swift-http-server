// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "swift-http-server",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "swift-http-server",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ],
        ),
        .testTarget(
            name: "ServerTests",
            dependencies: [
                "swift-http-server"
            ]),
    ]
)
