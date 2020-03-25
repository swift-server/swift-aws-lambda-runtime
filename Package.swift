// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "my-lambda",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: [
        .package(url: "git@github.com:swift-server/swift-aws-lambda-runtime.git", .branch("master")),
    ],
    targets: [
        // lambda code is abstracted into a library since we cant have a test target depend on an executable
        .target(name: "MyLambda", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        ]),
    ]
)
