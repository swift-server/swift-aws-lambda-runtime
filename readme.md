> [!IMPORTANT] 
> The documentation included here refers to the Swift AWS Lambda Runtime v2 (code from the main branch). If you're developing for the runtime v1.x, check this [readme](https://github.com/swift-server/swift-aws-lambda-runtime/blob/v1/readme.md) instead.

> [!WARNING]
> The Swift AWS Runtime v2 is work in progress. We will add more documentation and code examples over time.

## The Swift AWS Lambda Runtime

Many modern systems have client components like iOS, macOS or watchOS applications as well as server components that those clients interact with. Serverless functions are often the easiest and most efficient way for client application developers to extend their applications into the cloud.

Serverless functions are increasingly becoming a popular choice for running event-driven or otherwise ad-hoc compute tasks in the cloud. They power mission critical microservices and data intensive workloads. In many cases, serverless functions allow developers to more easily scale and control compute costs given their on-demand nature.

When using serverless functions, attention must be given to resource utilization as it directly impacts the costs of the system. This is where Swift shines! With its low memory footprint, deterministic performance, and quick start time, Swift is a fantastic match for the serverless functions architecture.

Combine this with Swift's developer friendliness, expressiveness, and emphasis on safety, and we have a solution that is great for developers at all skill levels, scalable, and cost effective.

Swift AWS Lambda Runtime was designed to make building Lambda functions in Swift simple and safe. The library is an implementation of the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) and uses an embedded asynchronous HTTP Client based on [SwiftNIO](http://github.com/apple/swift-nio) that is fine-tuned for performance in the AWS Runtime context. The library provides a multi-tier API that allows building a range of Lambda functions: From quick and simple closures to complex, performance-sensitive event handlers.

## Pre-requisites

- Ensure you have the Swift 6.x toolchain installed.  You can [install Swift toolchains](https://www.swift.org/install/macos/) from Swift.org

- When developing on macOS, be sure you use macOS 15 (Sequoia) or a more recent macOS version.

- To build and archive your Lambda function, you need to [install docker](https://docs.docker.com/desktop/install/mac-install/).

- To deploy the Lambda function and invoke it, you must have [an AWS account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-creating.html) and [install and configure the `aws` command line](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

- Some examples are using [AWS SAM](https://aws.amazon.com/serverless/sam/). Install the [SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) before deploying these examples.

## Getting started

To get started, read [the Swift AWS Lambda runtime v1 tutorial](https://swiftpackageindex.com/swift-server/swift-aws-lambda-runtime/1.0.0-alpha.3/tutorials/table-of-content). It provides developers with detailed step-by-step instructions to develop, build, and deploy a Lambda function.

Or, if you're impatient to start with runtime v2, try these six steps:

The `Examples/_MyFirstFunction` contains a script that goes through the steps described in this section. 

If you are really impatient, just type:

```bash
cd Examples/_MyFirstFunction
./create_and_deploy_function.sh
```

Otherwise, continue reading.

1. Create a new Swift executable project

```bash
mkdir MyLambda && cd MyLambda
swift package init --type executable
```

2. Prepare your `Package.swift` file

    2.1 Add the Swift AWS Lambda Runtime as a dependency

    ```bash
    swift package add-dependency https://github.com/swift-server/swift-aws-lambda-runtime.git --branch main
    swift package add-target-dependency AWSLambdaRuntime MyLambda --package swift-aws-lambda-runtime
    ```

    2.2 (Optional - only on macOS) Add `platforms` after `name`

    ```
        platforms: [.macOS(.v15)],
    ```

    2.3 Your `Package.swift` file must look like this

    ```swift
    // swift-tools-version: 6.0

    import PackageDescription

    let package = Package(
        name: "MyLambda",
        platforms: [.macOS(.v15)],
        dependencies: [
            .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        ],
        targets: [
            .executableTarget(
                name: "MyLambda",
                dependencies: [
                    .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                ]
                ),
        ]
    )
    ```

3. Scaffold a minimal Lambda function

The runtime comes with a plugin to generate the code of a simple AWS Lambda function:
 
```bash
swift package lambda-init --allow-writing-to-package-directory 
```

Your `Sources/main.swift` file must look like this. 

```swift
import AWSLambdaRuntime

// in this example we are receiving and responding with strings

let runtime = LambdaRuntime {
    (event: String, context: LambdaContext) in
        return String(event.reversed())
}

try await runtime.run()
```

4. Build & archive the package 

The runtime comes with a plugin to compile on Amazon Linux and create a ZIP archive:

```bash
swift package archive --allow-network-connections docker
```

If there is no error, the ZIP archive is ready to deploy. 
The ZIP file is located at `.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/MyLambda/MyLambda.zip`

5. Deploy to AWS

There are multiple ways to deploy to AWS ([SAM](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html), [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started), [AWS Cloud Development Kit (CDK)](https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html), [AWS Console](https://docs.aws.amazon.com/lambda/latest/dg/getting-started.html)) that are covered later in this doc.

Here is how to deploy using the `aws` command line.

```bash
aws lambda create-function \
--function-name MyLambda \
--zip-file fileb://.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/MyLambda/MyLambda.zip \
--runtime provided.al2 \
--handler provided  \
--architectures arm64 \
--role arn:aws:iam::<YOUR_ACCOUNT_ID>:role/lambda_basic_execution
```

The `--architectures` flag is only required when you build the binary on an Apple Silicon machine (Apple M1 or more recent). It defaults to `x64`.

Be sure to replace <YOUR_ACCOUNT_ID> with your actual AWS account ID (for example: 012345678901).

6. Invoke your Lambda function

```bash
aws lambda invoke \
--function-name MyLambda \
--payload $(echo \"Hello World\" | base64)  \
out.txt && cat out.txt && rm out.txt
```

This should print 

```
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
"dlroW olleH"
```

## Developing your Swift Lambda functions 

### Receive and respond with JSON objects

Typically, your Lambda functions will receive an input parameter expressed as JSON and will respond with some other JSON. The Swift AWS Lambda runtime automatically takes care of encoding and decoding JSON objects when your Lambda function handler accepts `Decodable` and returns `Encodable` conforming types.

Here is an example of a minimal function that accepts a JSON object as input and responds with another JSON object.

```swift
import AWSLambdaRuntime

// the data structure to represent the input parameter
struct HelloRequest: Decodable {
    let name: String
    let age: Int
}

// the data structure to represent the output response
struct HelloResponse: Encodable {
    let greetings: String
}

// the Lambda runtime
let runtime = LambdaRuntime {
    (event: HelloRequest, context: LambdaContext) in

    HelloResponse(
        greetings: "Hello \(event.name). You look \(event.age > 30 ? "younger" : "older") than your age."
    )
}

// start the loop
try await runtime.run()
```

You can learn how to deploy and invoke this function in [the Hello JSON example README file](Examples/HelloJSON/README.md).

### Lambda Streaming Response

You can configure your Lambda function to stream response payloads back to clients. Response streaming can benefit latency sensitive applications by improving time to first byte (TTFB) performance. This is because you can send partial responses back to the client as they become available. Additionally, you can use response streaming to build functions that return larger payloads. Response stream payloads have a soft limit of 20 MB as compared to the 6 MB limit for buffered responses. Streaming a response also means that your function doesn’t need to fit the entire response in memory. For very large responses, this can reduce the amount of memory you need to configure for your function.

Streaming responses incurs a cost. For more information, see [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/).

You can stream responses through [Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html), the AWS SDK, or using the Lambda [InvokeWithResponseStream](https://docs.aws.amazon.com/lambda/latest/dg/API_InvokeWithResponseStream.html) API. In this example, we create an authenticated Lambda function URL.

Here is an example of a minimal function that streams 10 numbers with an interval of one second for each number.

```swift
import AWSLambdaRuntime
import NIOCore

struct SendNumbersWithPause: StreamingLambdaHandler {
    func handle(
        _ event: ByteBuffer,
        responseWriter: some LambdaResponseStreamWriter,
        context: LambdaContext
    ) async throws {
        for i in 1...10 {
            // Send partial data
            try await responseWriter.write(ByteBuffer(string: "\(i)\n"))
            // Perform some long asynchronous work
            try await Task.sleep(for: .milliseconds(1000))
        }
        // All data has been sent. Close off the response stream.
        try await responseWriter.finish()
    }
}

let runtime = LambdaRuntime.init(handler: SendNumbersWithPause())
try await runtime.run()
```

You can learn how to deploy and invoke this function in [the streaming example README file](Examples/Streaming/README.md).

### Integration with AWS Services

 Most Lambda functions are triggered by events originating in other AWS services such as `Amazon SNS`, `Amazon SQS` or `AWS APIGateway`.
 
 The [Swift AWS Lambda Events](http://github.com/swift-server/swift-aws-lambda-events) package includes an `AWSLambdaEvents` module that provides implementations for most common AWS event types further simplifying writing Lambda functions.

 Here is an example Lambda function invoked when the AWS APIGateway receives an HTTP request.

 ```swift
import AWSLambdaEvents
import AWSLambdaRuntime

let runtime = LambdaRuntime {
    (event: APIGatewayV2Request, context: LambdaContext) -> APIGatewayV2Response in

    APIGatewayV2Response(statusCode: .ok, body: "Hello World!")
}

try await runtime.run()
```

 You can learn how to deploy and invoke this function in [the API Gateway example README file](Examples/APIGateway/README.md).

### Integration with Swift Service LifeCycle 

tbd + link to docc

### Use Lambda Background Tasks 

Background tasks allow code to execute asynchronously after the main response has been returned, enabling additional processing without affecting response latency. This approach is ideal for scenarios like logging, data updates, or notifications that can be deferred. The code leverages Lambda's "Response Streaming" feature, which is effective for balancing real-time user responsiveness with the ability to perform extended tasks post-response. For more information about Lambda background tasks, see [this AWS blog post](https://aws.amazon.com/blogs/compute/running-code-after-returning-a-response-from-an-aws-lambda-function/).


Here is an example of a minimal function that waits 10 seconds after it returned a response but before the handler returns.
```swift
import AWSLambdaRuntime
import Foundation

struct BackgroundProcessingHandler: LambdaWithBackgroundProcessingHandler {
    struct Input: Decodable {
        let message: String
    }

    struct Greeting: Encodable {
        let echoedMessage: String
    }

    typealias Event = Input
    typealias Output = Greeting

    func handle(
        _ event: Event,
        outputWriter: some LambdaResponseWriter<Output>,
        context: LambdaContext
    ) async throws {
        // Return result to the Lambda control plane
        context.logger.debug("BackgroundProcessingHandler - message received")
        try await outputWriter.write(Greeting(echoedMessage: event.message))

        // Perform some background work, e.g:
        context.logger.debug("BackgroundProcessingHandler - response sent. Performing background tasks.")
        try await Task.sleep(for: .seconds(10))

        // Exit the function. All asynchronous work has been executed before exiting the scope of this function.
        // Follows structured concurrency principles.
        context.logger.debug("BackgroundProcessingHandler - Background tasks completed. Returning")
        return
    }
}

let adapter = LambdaCodableAdapter(handler: BackgroundProcessingHandler())
let runtime = LambdaRuntime.init(handler: adapter)
try await runtime.run()
```

You can learn how to deploy and invoke this function in [the background tasks example README file](Examples/BackgroundTasks/README.md).

## Deploying your Swift Lambda functions


TODO


## Swift AWS Lambda Runtime - Design Principles

The [design document](Sources/AWSLambdaRuntimeCore/Documentation.docc/Proposals/0001-v2-api.md) details the v2 API proposal for the swift-aws-lambda-runtime library, which aims to enhance the developer experience for building serverless functions in Swift.

The proposal has been reviewed and [incorporated feedback from the community](https://forums.swift.org/t/aws-lambda-v2-api-proposal/73819). The full v2 API design document is available [in this repository](Sources/AWSLambdaRuntimeCore/Documentation.docc/Proposals/0001-v2-api.md).

### Key Design Principles

The v2 API prioritizes the following principles:

- Readability and Maintainability: Extensive use of `async`/`await` improves code clarity and simplifies maintenance.

- Developer Control: Developers own the `main()` function and have the flexibility to inject dependencies into the `LambdaRuntime`. This allows you to manage service lifecycles efficiently using [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle) for structured concurrency.

- Simplified Codable Support: The `LambdaCodableAdapter` struct eliminates the need for verbose boilerplate code when encoding and decoding events and responses.

### New Capabilities

The v2 API introduces two new features:

[Response Streaming](https://aws.amazon.com/blogs/compute/introducing-aws-lambda-response-streaming/]): This functionality is ideal for handling large responses that need to be sent incrementally.   

[Background Work](https://aws.amazon.com/blogs/compute/running-code-after-returning-a-response-from-an-aws-lambda-function/): Schedule tasks to run after returning a response to the AWS Lambda control plane.

These new capabilities provide greater flexibility and control when building serverless functions in Swift with the swift-aws-lambda-runtime library.