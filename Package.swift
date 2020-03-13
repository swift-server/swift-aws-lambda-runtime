// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "swift-aws-lambda",
    products: [
        .library(name: "SwiftAwsLambda", targets: ["SwiftAwsLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "SwiftAwsLambda", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Backtrace", package: "swift-backtrace"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .testTarget(name: "SwiftAwsLambdaTests", dependencies: ["SwiftAwsLambda"]),
        // samples
        .target(name: "SwiftAwsLambdaStringSample", dependencies: ["SwiftAwsLambda"]),
        .target(name: "SwiftAwsLambdaCodableSample", dependencies: ["SwiftAwsLambda"]),
        // perf tests
        .target(name: "MockServer", dependencies: [
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
    ]
)
