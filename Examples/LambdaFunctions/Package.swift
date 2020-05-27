// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "swift-aws-lambda-runtime-samples",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // introductory example
        .executable(name: "HelloWorld", targets: ["HelloWorld"]),
        // good for benchmarking
        .executable(name: "Benchmark", targets: ["Benchmark"]),
        // demonstrate different types of error handling
        .executable(name: "ErrorHandling", targets: ["ErrorHandling"]),
        // demostrate how to integrate with AWS API Gateway
        .executable(name: "APIGateway", targets: ["APIGateway"]),
        // demostrate how to integrate with AWS DynamoDB as a backend
        .executable(name: "DynamoDBPutBackend", targets: ["DynamoDBPutBackend"]),
        // fully featured example with domain specific business logic
        .executable(name: "CurrencyExchange", targets: ["CurrencyExchange"]),
    ],
    dependencies: [
        // this is the dependency on the swift-aws-lambda-runtime library
        // in real-world projects this would say
        // .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0")
        .package(name: "swift-aws-lambda-runtime", path: "../.."),
        .package(url: "https://github.com/amzn/smoke-aws-credentials.git", from: "2.0.0"),
        .package(url: "https://github.com/amzn/smoke-dynamodb.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "HelloWorld", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        ]),
        .target(name: "Benchmark", dependencies: [
            .product(name: "AWSLambdaRuntimeCore", package: "swift-aws-lambda-runtime"),
        ]),
        .target(name: "ErrorHandling", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        ]),
        .target(name: "APIGateway", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
        ]),
        .target(name: "CurrencyExchange", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        ]),
        .target(name: "DynamoDBPutBackend", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "SmokeAWSCredentials", package: "smoke-aws-credentials"),
            .product(name: "SmokeDynamoDB", package: "smoke-dynamodb"),
        ]),
    ]
)
