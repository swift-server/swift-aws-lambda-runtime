// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "MyLambda",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: [
        // this is the dependency on the swift-aws-lambda-runtime library
        // in real-world projects this would say
        // .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0")
        .package(name: "swift-aws-lambda-runtime", path: "../../.."),
        .package(name: "Shared", path: "../Shared"),
    ],
    targets: [
        .target(
            name: "MyLambda", dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "Shared", package: "Shared"),
            ]
        ),
    ]
)
