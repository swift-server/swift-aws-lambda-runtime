// swift-tools-version:6.0

import PackageDescription

#if os(macOS)
let platforms: [PackageDescription.SupportedPlatform]? = [.macOS(.v15)]
#else
let platforms: [PackageDescription.SupportedPlatform]? = nil
#endif

let package = Package(
    name: "swift-aws-lambda-runtime",
    platforms: platforms,
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
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.72.0")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.5.4")),
        .package(url: "https://github.com/apple/swift-testing.git", branch: "swift-DEVELOPMENT-SNAPSHOT-2024-08-29-a"),
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
                    description:
                        "Archive the Lambda binary and prepare it for uploading to AWS. Requires docker on macOS or non Amazonlinux 2 distributions."
                )
            )
        ),
        .testTarget(
            name: "AWSLambdaRuntimeCoreTests",
            dependencies: [
                .byName(name: "AWSLambdaRuntimeCore"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "Testing", package: "swift-testing"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AWSLambdaRuntimeTests",
            dependencies: [
                .byName(name: "AWSLambdaRuntimeCore"),
                .byName(name: "AWSLambdaRuntime"),
                .product(name: "Testing", package: "swift-testing"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // testing helper
        .target(
            name: "AWSLambdaTesting",
            dependencies: [
                .byName(name: "AWSLambdaRuntime"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "AWSLambdaTestingTests",
            dependencies: [
                .byName(name: "AWSLambdaTesting"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        // for perf testing
        .executableTarget(
            name: "MockServer",
            dependencies: [
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
