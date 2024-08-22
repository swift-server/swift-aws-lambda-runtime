// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // this library exports `AWSLambdaRuntimeCore` and adds Foundation convenience methods
        .library(name: "AWSLambdaRuntime", targets: ["AWSLambdaRuntime"]),
        // this has all the main functionality for lambda and it does not link Foundation
        .library(name: "AWSLambdaRuntimeCore", targets: ["AWSLambdaRuntimeCore"]),
        // plugin to package the lambda, creating an archive that can be uploaded to AWS
        // requires Linux or at least macOS v15
        .plugin(name: "AWSLambdaPackager", targets: ["AWSLambdaPackager"]),
        // for testing only
        .library(name: "AWSLambdaTesting", targets: ["AWSLambdaTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.67.0")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.5.4")),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AWSLambdaRuntime",
            dependencies: [
                .byName(name: "AWSLambdaRuntimeCore"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "AWSLambdaRuntimeCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .plugin(
            name: "AWSLambdaPackager",
            capability: .command(
                intent: .custom(
                    verb: "archive",
                    description: "Archive the Lambda binary and prepare it for uploading to AWS. Requires docker on macOS or non Amazonlinux 2 distributions."
                )
            )
        ),
        .testTarget(
            name: "AWSLambdaRuntimeCoreTests",
            dependencies: [
                .byName(name: "AWSLambdaRuntimeCore"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AWSLambdaRuntimeTests",
            dependencies: [
                .byName(name: "AWSLambdaRuntimeCore"),
                .byName(name: "AWSLambdaRuntime"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // testing helper
        .target(
            name: "AWSLambdaTesting",
            dependencies: [
                .byName(name: "AWSLambdaRuntime"),
                .product(name: "NIO", package: "swift-nio"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AWSLambdaTestingTests",
            dependencies: ["AWSLambdaTesting"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // for perf testing
        .executableTarget(
            name: "MockServer",
            dependencies: [
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIO", package: "swift-nio"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
