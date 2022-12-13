// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "MyLambda",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
        .library(name: "Shared", targets: ["Shared"]),
    ],
    dependencies: [
        // this is the dependency on the swift-aws-lambda-runtime library
        // in real-world projects this would say
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
//        .package(name: "swift-aws-lambda-runtime", path: "../../.."),
    ],
    targets: [
        .executableTarget(
            name: "MyLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .byName(name: "Shared"),
            ],
            path: "./MyLambda",
            exclude: ["scripts/", "Dockerfile"]
        ),
        .target(name: "Shared", 
                dependencies: [],
                path: "./Shared") 
    ]
)
