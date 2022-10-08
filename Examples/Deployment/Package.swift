// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime-samples",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        // introductory example
        .executable(name: "HelloWorld", targets: ["HelloWorld"]),
        // good for benchmarking
        .executable(name: "Benchmark", targets: ["Benchmark"]),
        // demonstrate different types of error handling
    ],
    dependencies: [
        // this is the dependency on the swift-aws-lambda-runtime library
        // in real-world projects this would say
        // .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0")
        .package(name: "swift-aws-lambda-runtime", path: "../.."),
    ],
    targets: [
        .executableTarget(name: "Benchmark", dependencies: [
            .product(name: "AWSLambdaRuntimeCore", package: "swift-aws-lambda-runtime"),
        ]),
        .executableTarget(name: "HelloWorld", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        ]),
    ]
)
