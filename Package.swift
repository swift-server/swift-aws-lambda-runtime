// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        // this library exports `AWSLambdaRuntimeCore` and adds Foundation convenience methods
        .library(name: "AWSLambdaRuntime", targets: ["AWSLambdaRuntime"]),
        // this has all the main functionality for lambda and it does not link Foundation
        .library(name: "AWSLambdaRuntimeCore", targets: ["AWSLambdaRuntimeCore"]),
        // plugin to package the lambda, creating an archive that can be uploaded to AWS
        .plugin(name: "AWSLambdaPackager", targets: ["AWSLambdaPackager"]),
        // plugin to deploy the lambda, relies on AWS SAM command line
        .plugin(name: "AWSLambdaDeployer", targets: ["AWSLambdaDeployer"]),
        // Shared Library to generate a SAM deployment descriptor
        .library(name: "AWSLambdaDeploymentDescriptor", type: .dynamic, targets: ["AWSLambdaDeploymentDescriptor"]),
        // for testing only
        .library(name: "AWSLambdaTesting", targets: ["AWSLambdaTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.43.1")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.4.2")),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", .upToNextMajor(from: "1.2.3")),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", .upToNextMajor(from: "5.0.5")),
    ],
    targets: [
        .target(name: "AWSLambdaRuntime", dependencies: [
            .byName(name: "AWSLambdaRuntimeCore"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .target(name: "AWSLambdaRuntimeCore", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Backtrace", package: "swift-backtrace"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
            .product(name: "NIOPosix", package: "swift-nio"),
        ]),
        .plugin(
            name: "AWSLambdaPackager",
            capability: .command(
                intent: .custom(
                    verb: "archive",
                    description: "Archive the Lambda binary and prepare it for uploading to AWS. Requires docker on macOS or non Amazonlinux 2 distributions."
                )
            )
        ),
        .target(
            name: "AWSLambdaDeploymentDescriptor",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/AWSLambdaDeploymentDescriptor"
        ),
        .plugin(
            name: "AWSLambdaDeployer",
            capability: .command(
                intent: .custom(
                    verb: "deploy",
                    description: "Deploy the Lambda ZIP created by the archive plugin. Generates SAM-compliant deployment files based on deployment struct passed by the developer and invoke the SAM command."
                )
//                permissions: [.writeToPackageDirectory(reason: "This plugin generates a SAM template to describe your deployment")]
            )
        ),
        .testTarget(name: "AWSLambdaRuntimeCoreTests", dependencies: [
            .byName(name: "AWSLambdaRuntimeCore"),
            .product(name: "NIOTestUtils", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .testTarget(name: "AWSLambdaRuntimeTests", dependencies: [
            .byName(name: "AWSLambdaRuntimeCore"),
            .byName(name: "AWSLambdaRuntime"),
        ]),
        .testTarget(name: "AWSLambdaDeploymentDescriptorTests", dependencies: [
            .byName(name: "AWSLambdaDeploymentDescriptor"),
        ]),
        // testing helper
        .target(name: "AWSLambdaTesting", dependencies: [
            .byName(name: "AWSLambdaRuntime"),
            .product(name: "NIO", package: "swift-nio"),
        ]),
        .testTarget(name: "AWSLambdaTestingTests", dependencies: ["AWSLambdaTesting"]),
        // for perf testing
        .executableTarget(name: "MockServer", dependencies: [
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIO", package: "swift-nio"),
        ]),
    ]
)
