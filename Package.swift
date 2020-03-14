// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        // core library
        .library(name: "AWSLambdaRuntime", targets: ["AWSLambdaRuntime"]),
        // foundaation utils for the core library
        .library(name: "AWSLambdaRuntimeFoundationCompat", targets: ["AWSLambdaRuntimeFoundationCompat"]),
        // common AWS events
        .library(name: "AWSLambdaEvents", targets: ["AWSLambdaEvents"]),
        // for testing only
        .library(name: "AWSLambdaTesting", targets: ["AWSLambdaTesting"]),
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
        ]),
        .target(name: "AWSLambdaRuntimeFoundationCompat", dependencies: [
            .byName(name: "AWSLambdaRuntime"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .testTarget(name: "AWSLambdaRuntimeTests", dependencies: ["AWSLambdaRuntime", "AWSLambdaRuntimeFoundationCompat"]),
        .target(name: "AWSLambdaEvents", dependencies: []),
        .testTarget(name: "AWSLambdaEventsTests", dependencies: ["AWSLambdaEvents"]),
        // testing helper
        .target(name: "AWSLambdaTesting", dependencies: [
            "AWSLambdaRuntime",
            .product(name: "NIO", package: "swift-nio"),
        ]),
        .testTarget(name: "AWSLambdaTestingTests", dependencies: ["AWSLambdaTesting", "AWSLambdaRuntimeFoundationCompat"]),
        // samples
        .target(name: "StringSample", dependencies: ["AWSLambdaRuntime"]),
        .target(name: "CodableSample", dependencies: ["AWSLambdaRuntime", "AWSLambdaRuntimeFoundationCompat"]),
        // perf tests
        .target(name: "MockServer", dependencies: [
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
    ]
)
