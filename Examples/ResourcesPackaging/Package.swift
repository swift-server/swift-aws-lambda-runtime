// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ResourcesPackaging",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "MyLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            ],
            path: ".",
            resources: [
                .process("hello.txt"),
            ]
        ),
    ]
)
