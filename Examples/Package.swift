// swift-tools-version:6.0

import PackageDescription

// needed for CI to test the local version of the library
import struct Foundation.URL

let package = Package(
    name: "swift-aws-lambda-runtime-example",
    platforms: [.macOS(.v15)],
    products: [
        // APIGateway
        .executable(name: "APIGateway", targets: ["APIGateway"]),
        // APIGateway+LambdaAuthorizer
        .executable(name: "APIGatewayLambda", targets: ["APIGatewayLambda"]),
        .executable(name: "AuthorizerLambda", targets: ["AuthorizerLambda"]),
        // BackgroundTasks
        .executable(name: "BackgroundTasks", targets: ["BackgroundTasks"]),
        // CDK
        .executable(name: "CDKAPIGatewayLambda", targets: ["CDKAPIGatewayLambda"]),
        // HelloJSON
        .executable(name: "HelloJSON", targets: ["HelloJSON"]),
        // HelloWorld
        .executable(name: "HelloWorld", targets: ["HelloWorld"]),
        // ResourcesPackaging
        .executable(name: "ResourcesPackaging", targets: ["ResourcesPackaging"]),
        // AWSSDKExample
        .executable(name: "AWSSDKExample", targets: ["AWSSDKExample"]),
        // SotoExample
        .executable(name: "SotoExample", targets: ["SotoExample"]),
        // S3EventNotifier
        .executable(name: "S3EventNotifier", targets: ["S3EventNotifier"]),
        // StreamingNumbers
        .executable(name: "StreamingNumbers", targets: ["StreamingNumbers"]),
        // Testing
        .executable(name: "TestedLambda", targets: ["TestedLambda"]),
        // Tutorial
        .executable(name: "Palindrome", targets: ["Palindrome"]),
    ],
    dependencies: [
        // during CI, the dependency on local version of swift-aws-lambda-runtime is added dynamically below
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "1.0.0"),
        // for the AWS SDK example
        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.0.0"),
        // for the Soto Example
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "APIGateway",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "APIGateway/Sources"
        ),
        .executableTarget(
            name: "APIGatewayLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "APIGateway+LambdaAuthorizer/Sources/APIGatewayLambda"
        ),
        .executableTarget(
            name: "AuthorizerLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "APIGateway+LambdaAuthorizer/Sources/AuthorizerLambda"
        ),
        .executableTarget(
            name: "BackgroundTasks",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "BackgroundTasks/Sources"
        ),
        .executableTarget(
            name: "CDKAPIGatewayLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "CDK/Sources"
        ),
        .executableTarget(
            name: "HelloJSON",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "HelloJSON/Sources"
        ),
        .executableTarget(
            name: "HelloWorld",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "HelloWorld/Sources"
        ),
        .executableTarget(
            name: "ResourcesPackaging",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "ResourcesPackaging",
            resources: [
                .process("hello.txt")
            ]
        ),
        .executableTarget(
            name: "AWSSDKExample",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSS3", package: "aws-sdk-swift"),
            ],
            path: "S3_AWSSDK/Sources"
        ),
        .executableTarget(
            name: "SotoExample",
            dependencies: [
                .product(name: "SotoS3", package: "soto"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "S3_Soto/Sources"
        ),
        .executableTarget(
            name: "S3EventNotifier",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "S3EventNotifier/Sources"
        ),
        .executableTarget(
            name: "StreamingNumbers",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "Streaming/Sources"
        ),
        .executableTarget(
            name: "TestedLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ],
            path: "Testing/Sources"
        ),
        .testTarget(
            name: "LambdaFunctionTests",
            dependencies: ["TestedLambda"],
            path: "Testing/Tests",
            resources: [
                .process("event.json")
            ]
        ),
        .executableTarget(
            name: "Palindrome",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "Tutorial/Sources"
        ),
    ]
)

if let localDepsPath = Context.environment["LAMBDA_USE_LOCAL_DEPS"],
    localDepsPath != "",
    let v = try? URL(fileURLWithPath: localDepsPath).resourceValues(forKeys: [.isDirectoryKey]),
    v.isDirectory == true
{
    // when we use the local runtime as deps, let's remove the dependency added above
    let indexToRemove = package.dependencies.firstIndex { dependency in
        if case .sourceControl(
            name: _,
            location: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
            requirement: _
        ) = dependency.kind {
            return true
        }
        return false
    }
    if let indexToRemove {
        package.dependencies.remove(at: indexToRemove)
    }

    // then we add the dependency on LAMBDA_USE_LOCAL_DEPS' path (typically ../..)
    print("[INFO] Compiling against swift-aws-lambda-runtime located at \(localDepsPath)")
    package.dependencies += [
        .package(name: "swift-aws-lambda-runtime", path: localDepsPath)
    ]
}
