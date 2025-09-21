// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-http-server",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "HttpServerCore",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            path: "Sources/HttpServerCore"
        ),
        .executableTarget(
            name: "HttpServer",
            dependencies: [
                "HttpServerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/HttpServer",
        ),
        .testTarget(
            name: "HttpServerTests",
            dependencies: [
                "HttpServerCore",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            path: "Tests/HttpServerTests",
        ),
    ]
)
