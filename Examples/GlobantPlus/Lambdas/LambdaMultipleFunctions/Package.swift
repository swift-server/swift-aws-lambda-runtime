// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LambdaMultipleFunctions",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "Lambda1",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ]),
        .executableTarget(
            name: "Lambda2",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ]),
        .testTarget(
            name: "Lambda1Tests",
            dependencies: ["Lambda1"],
            path: "Tests/Lambda1Tests"
        ),
        .testTarget(
            name: "Lambda2Tests",
            dependencies: ["Lambda2"],
            path: "Tests/Lambda2Tests"
        )
    ]
)
