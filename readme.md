# Swift AWS Lambda Runtime

Many modern systems have client components like iOS, macOS or watchOS applications as well as server components that those clients interact with. Serverless functions are often the easiest and most efficient way for client application developers to extend their applications into the cloud.

Serverless functions are increasingly becoming a popular choice for running event-driven or otherwise ad-hoc compute tasks in the cloud. They power mission critical microservices and data intensive workloads. In many cases, serverless functions allow developers to more easily scale and control compute costs given their on-demand nature.

When using serverless functions, attention must be given to resource utilization as it directly impacts the costs of the system. This is where Swift shines! With its low memory footprint, deterministic performance, and quick start time, Swift is a fantastic match for the serverless functions architecture.

Combine this with Swift's developer friendliness, expressiveness, and emphasis on safety, and we have a solution that is great for developers at all skill levels, scalable, and cost effective.

Swift AWS Lambda Runtime was designed to make building Lambda functions in Swift simple and safe. The library is an implementation of the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) and uses an embedded asynchronous HTTP Client based on [SwiftNIO](http://github.com/apple/swift-nio) that is fine-tuned for performance in the AWS Runtime context. The library provides a multi-tier API that allows building a range of Lambda functions: From quick and simple closures to complex, performance-sensitive event handlers.

## Getting started

If you have never used AWS Lambda or Docker before, check out this [getting started guide](https://fabianfett.de/getting-started-with-swift-aws-lambda-runtime) which helps you with every step from zero to a running Lambda.

First, create a SwiftPM project with an executable target and pull Swift AWS Lambda Runtime as dependency into your project:

```swift
// swift-tools-version:5.6
import PackageDescription
let package = Package(
    name: "my-lambda",
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(name: "MyLambda", dependencies: [
          .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        ]),
    ]
)
```

Now you can start implementing your Lambda!

### Creating an Entry Point for your Lambda 

The simplest way to use `AWSLambdaRuntime` is to create a type conforming to the `LambdaHandler`
protocol:

```swift
// Import the module
import AWSLambdaRuntime

@main
struct Handler: LambdaHandler {
    // in this example we are receiving and responding with strings
    func handle(request: String, context: LambdaContext) -> String {
        "Hello, \(request)!"
    }
}
```

> Using the `@main` attribute provides a signal to `AWSLambdaRuntime` that this is your application's entry point. The framework will handle everything else from there. This means that you don't have to create a main.swift file. 

### Using JSON as your Lambda's Input/Output

More commonly, events coming into your Lambda will most likely be JSON objects, which is modeled using `Codable`, for example:

```swift
// Import the module
import AWSLambdaRuntime
import Foundation

// Request, uses `Decodable` for transparent JSON encoding
private struct Request: Decodable {
    let name: String
}

// Response, uses `Encodable` for transparent JSON encoding
private struct Response: Encodable {
    let message: String
}

@main
struct Handler: LambdaHandler {
    // In this example we are receiving a `Decodable` and responding with an `Encodable`.
    func handle(request: Request, context: LambdaContext) -> Response {
        Response(message: Hello, \(request.name)!")
    }
}
```

### Using Popular AWS Events

Since most Lambda functions are triggered by events originating in the AWS platform like `SNS`, `SQS` or `APIGateway`, the [Swift AWS Lambda Events](http://github.com/swift-server/swift-aws-lambda-events) package includes an `AWSLambdaEvents` module that provides implementations for most common AWS event types further simplifying writing Lambda functions. For example, handling an `SQS` message:

First, add a dependency on the event package:

```swift
// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "my-lambda",
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(name: "MyLambda", dependencies: [
          .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
          .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
        ]),
    ]
)
```


```swift
// Import the modules
import AWSLambdaRuntime
import AWSLambdaEvents

@main
struct Handler: LambdaHandler {
    // In this example we are receiving a Decodable, with no response (Void).
    func handle(request: SQS.Event, context: LambdaContext) {
        ...
    }
}
```

### Using EventLoopLambdaHandler

Performance sensitive Lambda functions may choose to use a more complex API which allows user code to run on the same thread as the networking handlers. Swift AWS Lambda Runtime uses [SwiftNIO](https://github.com/apple/swift-nio) as its underlying networking engine which means the APIs are based on [SwiftNIO](https://github.com/apple/swift-nio) concurrency primitives like the `EventLoop` and `EventLoopFuture`. For example:

```swift
// Import the modules
import AWSLambdaRuntime
import AWSLambdaEvents
import NIO

// Our Lambda handler which conforms to `EventLoopLambdaHandler`
@main
struct Handler: EventLoopLambdaHandler {
    // In this example we are receiving an SNS Message, with no response (Void).
    func handle(event: SNS.Message, context: LambdaContext) -> EventLoopFuture<Void> {
        ...
        context.eventLoop.makeSucceededFuture(Void())
    }
}
```

Beyond the small cognitive complexity of using the `EventLoopFuture` based APIs, note these APIs should be used with extra care. An `EventLoopLambdaHandler` will execute the user code on the same `EventLoop` (thread) as the library, making processing faster but requiring the user code to never call blocking APIs as it might prevent the underlying process from functioning.

## Deploying to AWS Lambda

To deploy Lambda functions to AWS Lambda, you need to compile the code for Amazon Linux which is the OS used on AWS Lambda microVMs, package it as a Zip file, and upload to AWS.

AWS offers several tools to interact and deploy Lambda functions to AWS Lambda including [SAM](https://aws.amazon.com/serverless/sam/) and the [AWS CLI](https://aws.amazon.com/cli/). The [Examples Directory](/Examples) includes complete sample build and deployment scripts that utilize these tools.

Note the examples mentioned above use dynamic linking, therefore bundle the required Swift libraries in the Zip package along side the executable. You may choose to link the Lambda function statically (using `-static-stdlib`) which could improve performance but requires additional linker flags.

To build the Lambda function for Amazon Linux, use the Docker image published by Swift.org on [Swift toolchains and Docker images for Amazon Linux 2](https://swift.org/download/), as demonstrated in the examples.

## Architecture

The library defines three protocols for the implementation of a Lambda Handler. From low-level to more convenient:

### ByteBufferLambdaHandler

An `EventLoopFuture` based processing protocol for a Lambda that takes a `ByteBuffer` and returns a `ByteBuffer?` asynchronously.

`ByteBufferLambdaHandler` is the lowest level protocol designed to power the higher level `EventLoopLambdaHandler` and `LambdaHandler` based APIs. Users are not expected to use this protocol, though some performance sensitive applications that operate at the `ByteBuffer` level or have special serialization needs may choose to do so.

```swift
public protocol ByteBufferLambdaHandler {
    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///  - buffer: The event or request payload encoded as a `ByteBuffer`.
    ///  - context: Runtime `Context`.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    /// The `EventLoopFuture` should be completed with either a response encoded as `ByteBuffer` or an `Error`
    func handle(buffer: ByteBuffer, context: LambdaContext) -> EventLoopFuture<ByteBuffer?>
}
```

### EventLoopLambdaHandler

`EventLoopLambdaHandler` is a strongly typed, `EventLoopFuture` based asynchronous processing protocol for a Lambda that takes a user defined `Event` type and returns a user defined `Output` type.

`EventLoopLambdaHandler` extends `ByteBufferLambdaHandler`, providing `ByteBuffer` -> `Event` decoding and `Output` -> `ByteBuffer?` encoding for `Codable` and `String`.

`EventLoopLambdaHandler` executes the user provided Lambda on the same `EventLoop` as the core runtime engine, making the processing fast but requires more care from the implementation to never block the `EventLoop`. It is designed for performance sensitive applications that use `Codable` or `String` based Lambda functions.

```swift
public protocol EventLoopLambdaHandler: ByteBufferLambdaHandler {
    associatedtype Event
    associatedtype Output

    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///  - event: Event of type `Event` representing the event or request.
    ///  - context: Runtime `Context`.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    /// The `EventLoopFuture` should be completed with either a response of type `Output` or an `Error`
    func handle(event: Event, context: LambdaContext) -> EventLoopFuture<Output>

    /// Encode a response of type `Output` to `ByteBuffer`
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    /// - parameters:
    ///  - allocator: A `ByteBufferAllocator` to help allocate the `ByteBuffer`.
    ///  - value: Response of type `Output`.
    ///
    /// - Returns: A `ByteBuffer` with the encoded version of the `value`.
    func encode(allocator: ByteBufferAllocator, value: Output) throws -> ByteBuffer?

    /// Decode a `ByteBuffer` to a request or event of type `Event`
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    ///
    /// - parameters:
    ///  - buffer: The `ByteBuffer` to decode.
    ///
    /// - Returns: A request or event of type `Event`.
    func decode(buffer: ByteBuffer) throws -> Event
}
```

### LambdaHandler

`LambdaHandler` is a strongly-typed processing protocol that uses Swift concurrency primitives for a Lambda that takes a user defined `Request` and returns a user defined `Response`.

`LambdaHandler` extends `EventLoopLambdaHandler`, allowing the user to write Swift async logic in the body of their `handle(request:context:)` function.

```swift
public protocol LambdaHandler: EventLoopLambdaHandler {
    /// The Lambda handling method.
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - request: Event of type `Request` representing the event or request.
    ///     - context: Runtime ``LambdaContext``.
    ///
    /// - Returns: A Lambda result ot type `Output`.
    func handle(request: Request, context: LambdaContext) async throws -> Response
}
```

### Context

When calling the user provided Lambda function, the library provides a `Context` class that provides metadata about the execution context, as well as utilities for logging and allocating buffers.

```swift
public final class Context {
    /// The request ID, which identifies the request that triggered the function invocation.
    public let requestID: String

    /// The AWS X-Ray tracing header.
    public let traceID: String

    /// The ARN of the Lambda function, version, or alias that's specified in the invocation.
    public let invokedFunctionARN: String

    /// The timestamp that the function times out
    public let deadline: DispatchWallTime

    /// For invocations from the AWS Mobile SDK, data about the Amazon Cognito identity provider.
    public let cognitoIdentity: String?

    /// For invocations from the AWS Mobile SDK, data about the client application and device.
    public let clientContext: String?

    /// `Logger` to log with
    ///
    /// - note: The `LogLevel` can be configured using the `LOG_LEVEL` environment variable.
    public let logger: Logger

    /// The `EventLoop` the Lambda is executed on. Use this to schedule work with.
    /// This is useful when implementing the `EventLoopLambdaHandler` protocol.
    ///
    /// - note: The `EventLoop` is shared with the Lambda runtime engine and should be handled with extra care.
    ///  Most importantly the `EventLoop` must never be blocked.
    public let eventLoop: EventLoop

    /// `ByteBufferAllocator` to allocate `ByteBuffer`
    /// This is useful when implementing `EventLoopLambdaHandler`
    public let allocator: ByteBufferAllocator
}
```

### Configuration

This library’s behavior can be fine tuned using environment variables based configuration. This library supports the following environment variables:

* `LOG_LEVEL`: Define the logging level as defined by [SwiftLog](https://github.com/apple/swift-log). Set to INFO by default.
* `MAX_REQUESTS`: Max cycles the library should handle before exiting. Set to none by default.
* `STOP_SIGNAL`: Signal to capture for termination. Set to `TERM` by default.
* `REQUEST_TIMEOUT`:  Max time to wait for responses to come back from the AWS Runtime engine. Set to none by default.


### AWS Lambda Runtime Engine Integration

The library is designed to integrate with AWS Lambda Runtime Engine via the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) which was introduced as part of [AWS Lambda Custom Runtimes](https://aws.amazon.com/about-aws/whats-new/2018/11/aws-lambda-now-supports-custom-runtimes-and-layers/) in 2018. The latter is an HTTP server that exposes three main RESTful endpoint:

* `/runtime/invocation/next`
* `/runtime/invocation/response`
* `/runtime/invocation/error`

A single Lambda execution workflow is made of the following steps:

1. The library calls AWS Lambda Runtime Engine `/next` endpoint to retrieve the next invocation request.
2. The library parses the response HTTP headers and populate the `Context` object.
3. The library reads the `/next` response body and attempt to decode it. Typically it decodes to user provided `Event` type which extends `Decodable`, but users may choose to write Lambda functions that receive the input as `String` or `ByteBuffer` which require less, or no decoding.
4. The library hands off the `Context` and `Event` event to the user provided handler.
5. The user-provided handler processes the request asynchronously, returning a future or the result itself upon completion, which returns a `Result` type with the `Output` or `Error` populated.
6. In case of error, the library posts to AWS Lambda Runtime Engine `/error` endpoint to provide the error details, which will show up on AWS Lambda logs.
7. In case of success, the library will attempt to encode the response. Typically it encodes from user provided `Output` type which extends `Encodable`, but users may choose to write Lambda functions that return a `String` or `ByteBuffer`, which require less, or no encoding. The library then posts the response to AWS Lambda Runtime Engine `/response` endpoint to provide the response to the callee.

The library encapsulates the workflow via the internal `LambdaRuntimeClient` and `LambdaRunner` structs respectively.

### Lifecycle Management

AWS Lambda Runtime Engine controls the Application lifecycle and in the happy case never terminates the application, only suspends its execution when no work is available.

As such, the library's main entry point is designed to run forever in a blocking fashion, performing the workflow described above in an endless loop.

That loop is broken if/when an internal error occurs, such as a failure to communicate with AWS Lambda Runtime Engine API, or under other unexpected conditions.

By default, the library also registers a Signal handler that traps `INT` and `TERM`, which are typical Signals used in modern deployment platforms to communicate shutdown request.

### Integration with AWS Platform Events

AWS Lambda functions can be invoked directly from the AWS Lambda console UI, AWS Lambda API, AWS SDKs, AWS CLI, and AWS toolkits. More commonly, they are invoked as a reaction to an events coming from the AWS platform. To make it easier to integrate with AWS platform events, [Swift AWS Lambda Runtime Events](http://github.com/swift-server/swift-aws-lambda-events) library is available, designed to work together with this runtime library. [Swift AWS Lambda Runtime Events](http://github.com/swift-server/swift-aws-lambda-events) includes an `AWSLambdaEvents` target which provides abstractions for many commonly used events.

## Performance

Lambda functions performance is usually measured across two axes:

- **Cold start times**: The time it takes for a Lambda function to startup, ask for an invocation and process the first invocation.

- **Warm invocation times**: The time it takes for a Lambda function to process an invocation after the Lambda has been invoked at least once.

Larger packages size (Zip file uploaded to AWS Lambda) negatively impact the cold start time, since AWS needs to download and unpack the package before starting the process.

Swift provides great Unicode support via [ICU](http://site.icu-project.org/home). Therefore, Swift-based Lambda functions include the ICU libraries which tend to be large. This impacts the download time mentioned above and an area for further optimization. Some of the alternatives worth exploring are using the system ICU that comes with Amazon Linux (albeit older than the one Swift ships with) or working to remove the ICU dependency altogether. We welcome ideas and contributions to this end.

## Security

Please see [SECURITY.md](SECURITY.md) for details on the security process.

## Project status

This is a community-driven open-source project actively seeking contributions.
While the core API is considered stable, the API may still evolve as we get closer to a `1.0` version.
There are several areas which need additional attention, including but not limited to:

* Further performance tuning
* Additional documentation and best practices
* Additional examples
