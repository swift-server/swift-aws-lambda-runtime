// swift-tools-version:5.7

import class Foundation.ProcessInfo // needed for CI to test the local version of the library
import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime-example",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha"),
    ],
    targets: [
        .executableTarget(
            name: "MyLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaTesting", package: "swift-aws-lambda-runtime"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "MyLambdaTests", dependencies: ["MyLambda"], path: "Tests"),
    ]
)

// for CI to test the local version of the library
if ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"] != nil {
    package.dependencies = [
        .package(name: "swift-aws-lambda-runtime", path: "../.."),
    ]
}
