// swift-tools-version:5.7

import PackageDescription

import class Foundation.ProcessInfo  // needed for CI to test the local version of the library

let package = Package(
    name: "swift-aws-lambda-runtime-samples",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // introductory example
        .executable(name: "HelloWorld", targets: ["HelloWorld"]),
        // good for benchmarking
        .executable(name: "Benchmark", targets: ["Benchmark"]),
        // demonstrate different types of error handling
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha")
    ],
    targets: [
        .executableTarget(
            name: "Benchmark",
            dependencies: [
                .product(name: "AWSLambdaRuntimeCore", package: "swift-aws-lambda-runtime")
            ]
        ),
        .executableTarget(
            name: "HelloWorld",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ]
        ),
    ]
)

// for CI to test the local version of the library
if ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"] != nil {
    package.dependencies = [
        .package(name: "swift-aws-lambda-runtime", path: "../..")
    ]
}
