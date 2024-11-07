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
        // plugin to create a new Lambda function, based on a template
        .plugin(name: "AWSLambdaInitializer", targets: ["AWSLambdaInitializer"]),
        // plugin to package the lambda, creating an archive that can be uploaded to AWS
        // requires Linux or at least macOS v15
        .plugin(name: "AWSLambdaPackager", targets: ["AWSLambdaPackager"]),
        // plugin to deploy a Lambda function
        .plugin(name: "AWSLambdadeployer", targets: ["AWSLambdaDeployer"]),
        .executable(name: "AWSLambdaDeployerHelper", targets: ["AWSLambdaDeployerHelper"]),
        // for testing only
        .library(name: "AWSLambdaTesting", targets: ["AWSLambdaTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.72.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.9.1"),
    ],
    targets: [
        .target(
            name: "AWSLambdaRuntime",
            dependencies: [
                .byName(name: "AWSLambdaRuntimeCore"),
                .product(name: "NIOCore", package: "swift-nio"),
            ]
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
            name: "AWSLambdaInitializer",
            capability: .command(
                intent: .custom(
                    verb: "lambda-init",
                    description:
                        "Create a new Lambda function in the current project directory."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Create a file with an HelloWorld Lambda function.")
                ]
            )
        ),
        .plugin(
            name: "AWSLambdaPackager",
            capability: .command(
                intent: .custom(
                    verb: "archive",
                    description:
                        "Archive the Lambda binary and prepare it for uploading to AWS. Requires docker on macOS or non Amazonlinux 2 distributions."
                ),
                permissions: [
                    .allowNetworkConnections(
                        scope: .docker,
                        reason: "This plugin uses Docker to create the AWS Lambda ZIP package."
                    )
                ]
            )
        ),
        .plugin(
            name: "AWSLambdaDeployer",
            capability: .command(
                intent: .custom(
                    verb: "deploy",
                    description:
                        "Deploy the Lambda function. You must have an AWS account and know an access key and secret access key."
                ),
                permissions: [
                    .allowNetworkConnections(
                        scope: .all(ports: [443]),
                        reason: "This plugin uses the AWS Lambda API to deploy the function."
                    )
                ]
            ),
            dependencies: [
                .target(name: "AWSLambdaDeployerHelper")
            ]
        ),
        .executableTarget(
            name: "AWSLambdaDeployerHelper",
            dependencies: [
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "AWSLambdaRuntimeCoreTests",
            dependencies: [
                .byName(name: "AWSLambdaRuntimeCore"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "AWSLambdaRuntimeTests",
            dependencies: [
                .byName(name: "AWSLambdaRuntimeCore"),
                .byName(name: "AWSLambdaRuntime"),
            ]
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
                .byName(name: "AWSLambdaTesting")
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
