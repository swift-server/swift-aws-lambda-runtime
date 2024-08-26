// swift-tools-version:5.7

import PackageDescription

import class Foundation.ProcessInfo  // needed for CI to test the local version of the library

let package = Package(
    name: "MyLambda",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha"),
        .package(name: "Shared", path: "../Shared"),
    ],
    targets: [
        .executableTarget(
            name: "MyLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "Shared", package: "Shared"),
            ],
            path: ".",
            exclude: ["scripts/", "Dockerfile"]
        )
    ]
)

// for CI to test the local version of the library
if ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"] != nil {
    package.dependencies = [
        .package(name: "swift-aws-lambda-runtime", path: "../../.."),
        .package(name: "Shared", path: "../Shared"),
    ]
}
