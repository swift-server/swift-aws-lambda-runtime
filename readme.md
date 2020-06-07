# Swift AWS Lambda Runtime

Many modern systems have client components like iOS, macOS or watchOS applications as well as server components that those clients interact with. Serverless functions are often the easiest and most efficient way for client application developers to extend their applications into the cloud.

Serverless functions are increasingly becoming a popular choice for running event-driven or otherwise ad-hoc compute tasks in the cloud. They power mission critical microservices and data intensive workloads. In many cases, serverless functions allow developers to more easily scale and control compute costs given their on-demand nature.

When using serverless functions, attention must be given to resource utilization as it directly impacts the costs of the system. This is where Swift shines! With its low memory footprint, deterministic performance, and quick start time, Swift is a fantastic match for the serverless functions architecture.

Combine this with Swift's developer friendliness, expressiveness, and emphasis on safety, and we have a solution that is great for developers at all skill levels, scalable, and cost effective.

Swift AWS Lambda Runtime was designed to make building Lambda functions in Swift simple and safe. The library is an implementation of the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) and uses an embedded asynchronous HTTP Client based on [SwiftNIO](http://github.com/apple/swift-nio) that is fine-tuned for performance in the AWS Runtime context. The library provides a multi-tier API that allows building a range of Lambda functions: From quick and simple closures to complex, performance-sensitive event handlers.

## Project status

This is the beginning of a community-driven open-source project actively seeking contributions.
While the core API is considered stable, the API may still evolve as we get closer to a `1.0` version.
There are several areas which need additional attention, including but not limited to:

* Further performance tuning
* Additional trigger events
* Additional documentation and best practices
* Additional examples

## Getting started

If you have never used AWS Lambda or Docker before, check out this [getting started guide](https://fabianfett.de/getting-started-with-swift-aws-lambda-runtime) which helps you with every step from zero to a running Lambda.

First, create a SwiftPM project and pull Swift AWS Lambda Runtime as dependency into your project

 ```swift
 // swift-tools-version:5.2

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
         .target(name: "MyLambda", dependencies: [
           .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
         ]),
     ]
 )
 ```

Next, create a `main.swift` and implement your Lambda.

 ### Using Closures

 The simplest way to use `AWSLambdaRuntime` is to pass in a closure, for example:

 ```swift
 // Import the module
 import AWSLambdaRuntime

 // in this example we are receiving and responding with strings
 Lambda.run { (context, event: String, callback) in
   callback(.success("Hello, \(event)"))
 }
 ```

 More commonly, the event would be a JSON, which is modeled using `Codable`, for example:

 ```swift
 // Import the module
 import AWSLambdaRuntime

 // Request, uses Codable for transparent JSON encoding
 private struct Request: Codable {
   let name: String
 }

 // Response, uses Codable for transparent JSON encoding
 private struct Response: Codable {
   let message: String
 }

 // In this example we are receiving and responding with `Codable`.
 Lambda.run { (context, request: Request, callback) in
   callback(.success(Response(message: "Hello, \(request.name)")))
 }
 ```

 Since most Lambda functions are triggered by events originating in the AWS platform like `SNS`, `SQS` or `APIGateway`, the package also includes a `AWSLambdaEvents` module that provides implementations for most common AWS event types further simplifying writing Lambda functions. For example, handling an `SQS` message:

 ```swift
 // Import the modules
 import AWSLambdaRuntime
 import AWSLambdaEvents

 // In this example we are receiving an SQS Message, with no response (Void).
 Lambda.run { (context, message: SQS.Message, callback) in
   ...
   callback(.success(Void()))
 }
 ```

 Modeling Lambda functions as Closures is both simple and safe. Swift AWS Lambda Runtime will ensure that the user-provided code is offloaded from the network processing thread such that even if the code becomes slow to respond or gets hang, the underlying process can continue to function. This safety comes at a small performance penalty from context switching between threads. In many cases, the simplicity and safety of using the Closure based API is often preferred over the complexity of the performance-oriented API.

### Using EventLoopLambdaHandler

 Performance sensitive Lambda functions may choose to use a more complex API which allows user code to run on the same thread as the networking handlers. Swift AWS Lambda Runtime uses [SwiftNIO](https://github.com/apple/swift-nio) as its underlying networking engine which means the APIs are based on [SwiftNIO](https://github.com/apple/swift-nio) concurrency primitives like the `EventLoop` and `EventLoopFuture`. For example:

 ```swift
 // Import the modules
 import AWSLambdaRuntime
 import AWSLambdaEvents
 import NIO

 // Our Lambda handler, conforms to EventLoopLambdaHandler
 struct Handler: EventLoopLambdaHandler {
     typealias In = SNS.Message // Request type
     typealias Out = Void // Response type

     // In this example we are receiving an SNS Message, with no response (Void).
     func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out> {
         ...
         context.eventLoop.makeSucceededFuture(Void())
     }
 }

 Lambda.run(Handler())
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
    ///  - context: Runtime `Context`.
    ///  - event: The event or request payload encoded as `ByteBuffer`.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    /// The `EventLoopFuture` should be completed with either a response encoded as `ByteBuffer` or an `Error`
    func handle(context: Lambda.Context, event: ByteBuffer) -> EventLoopFuture<ByteBuffer?>
}
```

### EventLoopLambdaHandler

`EventLoopLambdaHandler` is a strongly typed, `EventLoopFuture` based asynchronous processing protocol for a Lambda that takes a user defined In and returns a user defined Out.

`EventLoopLambdaHandler` extends `ByteBufferLambdaHandler`, providing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer?` encoding for `Codable` and String.

`EventLoopLambdaHandler` executes the user provided Lambda on the same `EventLoop` as the core runtime engine, making the processing fast but requires more care from the implementation to never block the `EventLoop`. It it designed for performance sensitive applications that use `Codable` or String based Lambda functions.

```swift
public protocol EventLoopLambdaHandler: ByteBufferLambdaHandler {
    associatedtype In
    associatedtype Out

    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///  - context: Runtime `Context`.
    ///  - event: Event of type `In` representing the event or request.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    /// The `EventLoopFuture` should be completed with either a response of type `Out` or an `Error`
    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out>

    /// Encode a response of type `Out` to `ByteBuffer`
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    /// - parameters:
    ///  - allocator: A `ByteBufferAllocator` to help allocate the `ByteBuffer`.
    ///  - value: Response of type `Out`.
    ///
    /// - Returns: A `ByteBuffer` with the encoded version of the `value`.
    func encode(allocator: ByteBufferAllocator, value: Out) throws -> ByteBuffer?

    /// Decode a`ByteBuffer` to a request or event of type `In`
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    ///
    /// - parameters:
    ///  - buffer: The `ByteBuffer` to decode.
    ///
    /// - Returns: A request or event of type `In`.
    func decode(buffer: ByteBuffer) throws -> In
}
```

### LambdaHandler

`LambdaHandler` is a strongly typed, completion handler based asynchronous processing protocol for a Lambda that takes a user defined In and returns a user defined Out.

`LambdaHandler` extends `ByteBufferLambdaHandler`, performing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding for `Codable` and String.

`LambdaHandler` offloads the user provided Lambda execution to a `DispatchQueue` making processing safer but slower.

```swift
public protocol LambdaHandler: EventLoopLambdaHandler {
    /// Defines to which `DispatchQueue` the Lambda execution is offloaded to.
    var offloadQueue: DispatchQueue { get }

    /// The Lambda handling method
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///  - context: Runtime `Context`.
    ///  - event: Event of type `In` representing the event or request.
    ///  - callback: Completion handler to report the result of the Lambda back to the runtime engine.
    ///  The completion handler expects a `Result` with either a response of type `Out` or an `Error`
    func handle(context: Lambda.Context, event: In, callback: @escaping (Result<Out, Error>) -> Void)
}
```

### Closures

In addition to protocol-based Lambda, the library provides support for Closure-based ones, as demonstrated in the overview section above. Closure-based Lambdas are based on the `LambdaHandler` protocol which mean they are safer. For most use cases, Closure-based Lambda is a great fit and users are encouraged to use them.

The library includes implementations for `Codable` and String based Lambda. Since AWS Lambda is primarily JSON based, this covers the most common use cases.

```swift
public typealias CodableClosure<In: Decodable, Out: Encodable> = (Lambda.Context, In, @escaping (Result<Out, Error>) -> Void) -> Void
```

```swift
public typealias StringClosure = (Lambda.Context, String, @escaping (Result<String, Error>) -> Void) -> Void
```

This design allows for additional event types as well, and such Lambda implementation can extend one of the above protocols and provided their own `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding.

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

The library’s behavior can be fine tuned using environment variables based configuration. The library supported the following environment variables:

* `LOG_LEVEL`: Define the logging level as defined by [SwiftLog](https://github.com/apple/swift-log). Set to INFO by default.
* `MAX_REQUESTS`: Max cycles the library should handle before exiting. Set to none by default.
* `STOP_SIGNAL`: Signal to capture for termination. Set to TERM by default.
* `REQUEST_TIMEOUT`:  Max time to wait for responses to come back from the AWS Runtime engine. Set to none by default.


### AWS Lambda Runtime Engine Integration

The library is designed to integrate with AWS Lambda Runtime Engine via the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) which was introduced as part of [AWS Lambda Custom Runtimes](https://aws.amazon.com/about-aws/whats-new/2018/11/aws-lambda-now-supports-custom-runtimes-and-layers/) in 2018. The latter is an HTTP server that exposes three main RESTful endpoint:

* `/runtime/invocation/next`
* `/runtime/invocation/response`
* `/runtime/invocation/error`

A single Lambda execution workflow is made of the following steps:

1. The library calls AWS Lambda Runtime Engine `/next` endpoint to retrieve the next invocation request.
2. The library parses the response HTTP headers and populate the Context object.
3. The library reads the `/next` response body and attempt to decode it. Typically it decodes to user provided `In` type which extends `Decodable`, but users may choose to write Lambda functions that receive the input as String or `ByteBuffer` which require less, or no decoding.
4. The library hands off the `Context` and `In` event to the user provided handler. In the case of `LambdaHandler` based handler this is done on a dedicated `DispatchQueue`, providing isolation between user's and the library's code.
5. User provided handler processes the request asynchronously, invoking a callback or returning a future upon completion, which returns a Result type with the Out or Error populated.
6.  In case of error, the library posts to AWS Lambda Runtime Engine `/error` endpoint to provide the error details, which will show up on AWS Lambda logs.
7. In case of success, the library will attempt to encode the  response. Typically it encodes from user provided `Out` type which extends `Encodable`, but users may choose to write Lambda functions that return a String or `ByteBuffer`, which require less, or no encoding. The library then posts the response to AWS Lambda Runtime Engine `/response` endpoint to provide the response to the callee.

The library encapsulates the workflow via the internal `LambdaRuntimeClient` and `LambdaRunner` structs respectively.

### Lifecycle Management

AWS Lambda Runtime Engine controls the Application lifecycle and in the happy case never terminates the application, only suspends it's execution when no work is avaialble.

As such, the library main entry point is designed to run forever in a blocking fashion, performing the workflow described above in an endless loop.

That loop is broken if/when an internal error occurs, such as a failure to communicate with AWS Lambda Runtime Engine API, or under other unexpected conditions.

By default, the library also registers a Signal handler that traps `INT` and `TERM` , which are typical Signals used in modern deployment platforms to communicate shutdown request.

### Integration with AWS Platform Events

AWS Lambda functions can be invoked directly from the AWS Lambda console UI, AWS Lambda API, AWS SDKs, AWS CLI, and AWS toolkits. More commonly, they are invoked as a reaction to an events coming from the AWS platform. To make it easier to integrate with AWS platform events, the library includes an `AWSLambdaEvents` target which provides abstractions for many commonly used events. Additional events can be easily modeled when needed following the same patterns set by `AWSLambdaEvents`. Integration points with the AWS Platform include:

* [APIGateway Proxy](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html)
* [S3 Events](https://docs.aws.amazon.com/lambda/latest/dg/with-s3.html)
* [SNS Events](https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html)
* [SQS Events](https://docs.aws.amazon.com/lambda/latest/dg/with-sqs.html)
* [CloudWatch Events](https://docs.aws.amazon.com/lambda/latest/dg/services-cloudwatchevents.html)

**Note**: Each one of the integration points mentioned above includes a set of `Codable` structs that mirror AWS' data model for these APIs.

## Performance

Lambda functions performance is usually measured across two axes:

- **Cold start times**: The time it takes for a Lambda function to startup, ask for an invocation and process the first invocation.

- **Warm invocation times**: The time it takes for a Lambda function to process an invocation after the Lambda has been invoked at least once.

Larger packages size (Zip file uploaded to AWS Lambda) negatively impact the cold start time, since AWS needs to download and unpack the package before starting the process.

Swift provides great Unicode support via [ICU](http://site.icu-project.org/home). Therefore, Swift-based Lambda functions include the ICU libraries which tend to be large. This impacts the download time mentioned above and an area for further optimization. Some of the alternatives worth exploring are using the system ICU that comes with Amazon Linux (albeit older than the one Swift ships with) or working to remove the ICU dependency altogether. We welcome ideas and contributions to this end.
