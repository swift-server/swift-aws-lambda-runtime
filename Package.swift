// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "swift-aws-lambda",
    products: [
        .library(name: "SwiftAwsLambda", targets: ["SwiftAwsLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/ianpartridge/swift-backtrace.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "SwiftAwsLambda", dependencies: ["Logging", "Backtrace", "NIOHTTP1"]),
        .testTarget(name: "SwiftAwsLambdaTests", dependencies: ["SwiftAwsLambda"]),
        // samples
        .target(name: "SwiftAwsLambdaSample", dependencies: ["SwiftAwsLambda"]),
        .target(name: "SwiftAwsLambdaStringSample", dependencies: ["SwiftAwsLambda"]),
        .target(name: "SwiftAwsLambdaCodableSample", dependencies: ["SwiftAwsLambda"]),
        // perf tests
        .target(name: "MockServer", dependencies: ["Logging", "NIOHTTP1"]),
    ]
)
