// swift-tools-version:6.1
// This example has to be in Swift 6.1 because it is used in the test archive plugin CI job
// That job runs on GitHub's ubuntu-latest environment that only supports Swift 6.1
// https://github.com/actions/runner-images?tab=readme-ov-file
// https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md
// We can update to Swift 6.2 when GitHUb hosts will have Swift 6.2

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime-example",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"])
    ],
    dependencies: [
        // For local development (default)
        .package(name: "swift-aws-lambda-runtime", path: "../..")

        // For standalone usage, comment the line above and uncomment below:
        // .package(url: "https://github.com/awslabs/swift-aws-lambda-runtime.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ],
            path: "Sources"
        )
    ]
)
