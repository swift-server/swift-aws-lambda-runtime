// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime",
    products: [
        .library(name: "AWSLambdaRuntime", targets: ["AWSLambdaRuntime"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "AWSLambdaRuntime", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Backtrace", package: "swift-backtrace"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .testTarget(name: "AWSLambdaRuntimeTests", dependencies: ["AWSLambdaRuntime"]),
        // samples
        .target(name: "StringSample", dependencies: ["AWSLambdaRuntime"]),
        .target(name: "CodableSample", dependencies: ["AWSLambdaRuntime"]),
        // perf tests
        .target(name: "MockServer", dependencies: [
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
    ]
)
