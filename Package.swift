// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        // this library exports `AWSLambdaRuntimeCore` and adds Foundation convenience methods
        .library(name: "AWSLambdaRuntime", targets: ["AWSLambdaRuntime"]),
        // this has all the main functionality for lambda and it does not link Foundation
        .library(name: "AWSLambdaRuntimeCore", targets: ["AWSLambdaRuntimeCore"]),
        // common AWS events
        .library(name: "AWSLambdaEvents", targets: ["AWSLambdaEvents"]),
        // for testing only
        .library(name: "AWSLambdaTesting", targets: ["AWSLambdaTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.17.0")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", .upToNextMajor(from: "1.1.0")),
    ],
    targets: [
        .target(name: "AWSLambdaRuntime", dependencies: [
            .byName(name: "AWSLambdaRuntimeCore"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .target(name: "AWSLambdaRuntimeCore", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Backtrace", package: "swift-backtrace"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .testTarget(name: "AWSLambdaRuntimeCoreTests", dependencies: [
            .byName(name: "AWSLambdaRuntimeCore"),
        ]),
        .testTarget(name: "AWSLambdaRuntimeTests", dependencies: [
            .byName(name: "AWSLambdaRuntimeCore"),
            .byName(name: "AWSLambdaRuntime"),
        ]),
        .target(name: "AWSLambdaEvents", dependencies: []),
        .testTarget(name: "AWSLambdaEventsTests", dependencies: ["AWSLambdaEvents"]),
        // testing helper
        .target(name: "AWSLambdaTesting", dependencies: [
            .byName(name: "AWSLambdaRuntime"),
            .product(name: "NIO", package: "swift-nio"),
        ]),
        .testTarget(name: "AWSLambdaTestingTests", dependencies: [
            .byName(name: "AWSLambdaTesting"),
            .byName(name: "AWSLambdaRuntime"),
        ]),
        // samples
        .target(name: "StringSample", dependencies: [
            .byName(name: "AWSLambdaRuntime"),
        ]),
        .target(name: "CodableSample", dependencies: [
            .byName(name: "AWSLambdaRuntime"),
        ]),
        // perf tests
        .target(name: "MockServer", dependencies: [
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
    ]
)
