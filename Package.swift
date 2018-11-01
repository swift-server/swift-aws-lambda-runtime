// swift-tools-version:4.0

import PackageDescription

var targets: [PackageDescription.Target] = [
    .target(name: "SwiftAwsLambda", dependencies: ["NIOHTTP1"]),
    .target(name: "SwiftAwsLambdaSample", dependencies: ["SwiftAwsLambda"]),
    .target(name: "SwiftAwsLambdaStringSample", dependencies: ["SwiftAwsLambda"]),
    .target(name: "SwiftAwsLambdaCodableSample", dependencies: ["SwiftAwsLambda"]),
    .testTarget(name: "SwiftAwsLambdaTests", dependencies: ["SwiftAwsLambda"]),
]

let package = Package(
    name: "swift-aws-lambda",
    products: [
        .library(name: "SwiftAwsLambda", targets: ["SwiftAwsLambda"]),
        .executable(name: "SwiftAwsLambdaSample", targets: ["SwiftAwsLambdaSample"]),
        .executable(name: "SwiftAwsLambdaStringSample", targets: ["SwiftAwsLambdaStringSample"]),
        .executable(name: "SwiftAwsLambdaCodableSample", targets: ["SwiftAwsLambdaCodableSample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "1.9.5")),
    ],
    targets: targets
)
