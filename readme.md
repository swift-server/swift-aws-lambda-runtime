# Swift AWS Lambda Runtime

Many modern systems have client components like iOS, macOS or watchOS applications as well as server components that those clients interact with. Serverless functions are often the easiest and most efficient way for client application developers to extend their applications into the cloud.

Serverless functions are increasingly becoming a popular choice for running event-driven or otherwise ad-hoc compute tasks in the cloud. They power mission critical microservices and data intensive workloads. In many cases, serverless functions allow developers to more easily scale and control compute costs given their on-demand nature.

When using serverless functions, attention must be given to resource utilization as it directly impacts the costs of the system. This is where Swift shines! With its low memory footprint, deterministic performance, and quick start time, Swift is a fantastic match for the serverless functions architecture.

Combine this with Swift's developer friendliness, expressiveness, and emphasis on safety, and we have a solution that is great for developers at all skill levels, scalable, and cost effective.

Swift AWS Lambda Runtime was designed to make building Lambda functions in Swift simple and safe. The library is an implementation of the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html) and uses an embedded asynchronous HTTP Client based on [SwiftNIO](http://github.com/apple/swift-nio) that is fine-tuned for performance in the AWS Runtime context. The library provides a multi-tier API that allows building a range of Lambda functions: From quick and simple closures to complex, performance-sensitive event handlers.

## Getting started

If you have never used AWS Lambda or Docker before, check out this [getting started guide](https://fabianfett.dev/getting-started-with-swift-aws-lambda-runtime) which helps you with every step from zero to a running Lambda.

First, create a SwiftPM project and pull Swift AWS Lambda Runtime as dependency into your project

 ```swift
 // swift-tools-version:5.7

 import PackageDescription

 let package = Package(
     name: "MyLambda",
     products: [
         .executable(name: "MyLambda", targets: ["MyLambda"]),
     ],
     dependencies: [
         .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha"),
     ],
     targets: [
         .executableTarget(name: "MyLambda", dependencies: [
           .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
         ]),
     ]
 )
 ```

Next, create a `MyLambda.swift` and implement your Lambda. Note that the file can not be named `main.swift` or you will encounter the following error: `'main' attribute cannot be used in a module that contains top-level code`.

### Using async function

 The simplest way to use `AWSLambdaRuntime` is to use the `SimpleLambdaHandler` protocol and pass in an async function, for example:

 ```swift
 // Import the module
 import AWSLambdaRuntime

 @main
 struct MyLambda: SimpleLambdaHandler {
     // in this example we are receiving and responding with strings
     func handle(_ name: String, context: LambdaContext) async throws -> String {
         "Hello, \(name)"
     }
 }
 ```

 More commonly, the event would be a JSON, which is modeled using `Codable`, for example:

 ```swift
 // Import the module
 import AWSLambdaRuntime

 // Request, uses Codable for transparent JSON encoding
 struct Request: Codable {
   let name: String
 }

 // Response, uses Codable for transparent JSON encoding
 struct Response: Codable {
   let message: String
 }

 @main
 struct MyLambda: SimpleLambdaHandler {
     // In this example we are receiving and responding with `Codable`.
     func handle(_ request: Request, context: LambdaContext) async throws -> Response {
         Response(message: "Hello, \(request.name)")
     }
 }
 ```

 Since most Lambda functions are triggered by events originating in the AWS platform like `SNS`, `SQS` or `APIGateway`, the [Swift AWS Lambda Events](http://github.com/swift-server/swift-aws-lambda-events) package includes an `AWSLambdaEvents` module that provides implementations for most common AWS event types further simplifying writing Lambda functions. For example, handling a `SQS` message:

 First, add a dependency on the event packages:

 ```swift
 // swift-tools-version:5.7

 import PackageDescription

 let package = Package(
     name: "MyLambda",
     products: [
         .executable(name: "MyLambda", targets: ["MyLambda"]),
     ],
     dependencies: [
         .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha"),
         .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main"),
     ],
     targets: [
         .executableTarget(name: "MyLambda", dependencies: [
           .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
           .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
         ]),
     ]
 )
 ```

 Then in your Lambda:

 ```swift
 // Import the modules
 import AWSLambdaRuntime
 import AWSLambdaEvents

 @main
 struct MyLambda: SimpleLambdaHandler {
     // In this example we are receiving a SQS Event, with no response (Void).
     func handle(_ event: SQSEvent, context: LambdaContext) async throws {
         ...
     }
 }
 ```

 In some cases, the Lambda needs to do work on initialization.
 In such cases, use the `LambdaHandler` instead of the `SimpleLambdaHandler` which has an additional initialization method. For example:

 ```swift
 import AWSLambdaRuntime

 @main
 struct MyLambda: LambdaHandler {
     init(context: LambdaInitializationContext) async throws {
         ...
     }   

     func handle(_ event: String, context: LambdaContext) async throws -> Void {
         ...
     }
 }
 ```

 Modeling Lambda functions as async functions is both simple and safe. Swift AWS Lambda Runtime will ensure that the user-provided code is offloaded from the network processing thread such that even if the code becomes slow to respond or gets hang, the underlying process can continue to function. This safety comes at a small performance penalty from context switching between threads. In many cases, the simplicity and safety of using the Closure based API is often preferred over the complexity of the performance-oriented API.

### Using EventLoopLambdaHandler

 Performance sensitive Lambda functions may choose to use a more complex API which allows user code to run on the same thread as the networking handlers. Swift AWS Lambda Runtime uses [SwiftNIO](https://github.com/apple/swift-nio) as its underlying networking engine which means the APIs are based on [SwiftNIO](https://github.com/apple/swift-nio) concurrency primitives like the `EventLoop` and `EventLoopFuture`. For example:

 ```swift
 // Import the modules
 import AWSLambdaRuntime
 import AWSLambdaEvents
 import NIOCore

 @main
 struct Handler: EventLoopLambdaHandler {
     typealias Event = SNSEvent.Message // Event / Request type
     typealias Output = Void // Output / Response type

     static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Self> {
         context.eventLoop.makeSucceededFuture(Self())
     }

     // `EventLoopLambdaHandler` does not offload the Lambda processing to a separate thread
     // while the closure-based handlers do.
     func handle(_ event: Event, context: LambdaContext) -> EventLoopFuture<Output> {
         ...
         context.eventLoop.makeSucceededFuture(Void())
     }
 }
 ```

 Beyond the small cognitive complexity of using the `EventLoopFuture` based APIs, note these APIs should be used with extra care. An `EventLoopLambdaHandler` will execute the user code on the same `EventLoop` (thread) as the library, making processing faster but requiring the user code to never call blocking APIs as it might prevent the underlying process from functioning.

## Testing Locally

Before deploying your code to AWS Lambda, you can test it locally by setting the `LOCAL_LAMBDA_SERVER_ENABLED` environment variable to true. It will look like this on CLI:

```sh
LOCAL_LAMBDA_SERVER_ENABLED=true swift run
```

This starts a local HTTP server listening on port 7000. You can invoke your local Lambda function by sending an HTTP POST request to `http://127.0.0.1:7000/invoke`.

The request must include the JSON payload expected as an `Event` by your function. You can create a text file with the JSON payload documented by AWS or captured from a trace.  In this example, we used [the APIGatewayv2 JSON payload from the documentation](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html#apigateway-example-event), saved as `events/create-session.json` text file.

Then we use curl to invoke the local endpoint with the test JSON payload.

```sh
curl -v --header "Content-Type:\ application/json" --data @events/create-session.json http://127.0.0.1:7000/invoke
*   Trying 127.0.0.1:7000...
* Connected to 127.0.0.1 (127.0.0.1) port 7000
> POST /invoke HTTP/1.1
> Host: 127.0.0.1:7000
> User-Agent: curl/8.4.0
> Accept: */*
> Content-Type:\ application/json
> Content-Length: 1160
> 
< HTTP/1.1 200 OK
< content-length: 247
< 
* Connection #0 to host 127.0.0.1 left intact
{"statusCode":200,"isBase64Encoded":false,"body":"...","headers":{"Access-Control-Allow-Origin":"*","Content-Type":"application\/json; charset=utf-8","Access-Control-Allow-Headers":"*"}}
```
### Modifying the local endpoint

By default, when using the local Lambda server, it listens on the `/invoke` endpoint.

Some testing tools, such as the [AWS Lambda runtime interface emulator](https://docs.aws.amazon.com/lambda/latest/dg/images-test.html), require a different endpoint. In that case, you can use the `LOCAL_LAMBDA_SERVER_INVOCATION_ENDPOINT` environment variable to force the runtime to listen on a different endpoint.

Example:

```sh
LOCAL_LAMBDA_SERVER_ENABLED=true LOCAL_LAMBDA_SERVER_INVOCATION_ENDPOINT=/2015-03-31/functions/function/invocations swift run
```

## Increase logging verbosity 

You can increase the verbosity of the runtime using the `LOG_LEVEL` environment variable.

- `LOG_LEVEL=debug` displays information about the Swift AWS Lambda Runtime activity and lifecycle
- `LOG_LEVEL=trace` displays a string representation of the input event as received from the AWS Lambda service (before invoking your handler).

You can modify the verbosity of a Lambda function by passing the LOG_LEVEL environment variable both during your local testing (LOG_LEVEL=trace LOCAL_LAMBDA_SERVER_ENABLED=true swift run) or when you deploy your code on AWS Lambda.
You can [define environment variables for your Lambda functions](https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html) in the AWS console or programmatically.

This repository follows [Swift's Log Level Guidelines](https://www.swift.org/server/guides/libraries/log-levels.html). At `LOG_LEVEL=trace`, the AWS Lambda runtime will display a string representation of the input event as received from the AWS Lambda service before invoking your handler, for maximum debuggability.

## Deploying to AWS Lambda

To deploy Lambda functions to AWS Lambda, you need to compile the code for Amazon Linux which is the OS used on AWS Lambda microVMs, package it as a Zip file, and upload to AWS.

Swift AWS Lambda Runtime includes a SwiftPM plugin designed to help with the creation of the zip archive.
To build and package your Lambda, run the following command:

 ```shell
 swift package archive
 ```

The `archive` command can be customized using the following parameters

* `--output-path` A valid file system path where a folder with the archive operation result will be placed. This folder will contain the following elements:
    * A file link named `bootstrap`
    * An executable file
    * A **Zip** file ready to be uploaded to AWS
* `--verbose` A number that sets the command output detail level between the following values:
    * `0` (Silent)
    * `1` (Output)
    * `2` (Debug)
* `--swift-version` Swift language version used to define the Amazon Linux 2 Docker image. For example "5.7.3"
* `--base-docker-image` An Amazon Linux 2 docker image name available in your system.
* `--disable-docker-image-update` If flag is set, docker image will not be updated and local image will be used.

Both `--swift-version` and `--base-docker-image` are mutually exclusive

Here's an example

```zsh
swift package archive --output-path /Users/JohnAppleseed/Desktop --verbose 2
```

This command execution will generate a folder at `/Users/JohnAppleseed/Desktop` with the lambda zipped and ready to upload it and set the command detail output level to `2` (debug)

 on macOS, the archiving plugin uses docker to build the Lambda for Amazon Linux 2, and as such requires to communicate with Docker over the localhost network.
 At the moment, SwiftPM does not allow plugin communication over network, and as such the invocation requires breaking from the SwiftPM plugin sandbox. This limitation would be removed in the future.
 
 

```shell
 swift package --disable-sandbox archive
 ```

AWS offers several tools to interact and deploy Lambda functions to AWS Lambda including [SAM](https://aws.amazon.com/serverless/sam/) and the [AWS CLI](https://aws.amazon.com/cli/). The [Examples Directory](/Examples) includes complete sample build and deployment scripts that utilize these tools.

Note the examples mentioned above use dynamic linking, therefore bundle the required Swift libraries in the Zip package along side the executable. You may choose to link the Lambda function statically (using `-static-stdlib`) which could improve performance but requires additional linker flags.

To build the Lambda function for Amazon Linux 2, use the Docker image published by Swift.org on [Swift toolchains and Docker images for Amazon Linux 2](https://swift.org/download/), as demonstrated in the examples.

## Architecture

The library defines four protocols for the implementation of a Lambda Handler. From low-level to more convenient:

### ByteBufferLambdaHandler

An `EventLoopFuture` based processing protocol for a Lambda that takes a `ByteBuffer` and returns a `ByteBuffer?` asynchronously.

`ByteBufferLambdaHandler` is the lowest level protocol designed to power the higher level `EventLoopLambdaHandler` and `LambdaHandler` based APIs. Users are not expected to use this protocol, though some performance sensitive applications that operate at the `ByteBuffer` level or have special serialization needs may choose to do so.

```swift
public protocol ByteBufferLambdaHandler {
    /// Create a Lambda handler for the runtime.
    ///
    /// Use this to initialize all your resources that you want to cache between invocations. This could be database
    /// connections and HTTP clients for example. It is encouraged to use the given `EventLoop`'s conformance
    /// to `EventLoopGroup` when initializing NIO dependencies. This will improve overall performance, as it
    /// minimizes thread hopping.
    static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Self>

    /// The Lambda handling method.
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - context: Runtime ``LambdaContext``.
    ///     - event: The event or input payload encoded as `ByteBuffer`.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    ///            The `EventLoopFuture` should be completed with either a response encoded as `ByteBuffer` or an `Error`.
    func handle(_ buffer: ByteBuffer, context: LambdaContext) -> EventLoopFuture<ByteBuffer?>
}
```

### EventLoopLambdaHandler

`EventLoopLambdaHandler` is a strongly typed, `EventLoopFuture` based asynchronous processing protocol for a Lambda that takes a user defined `Event` and returns a user defined `Output`.

`EventLoopLambdaHandler` provides `ByteBuffer` -> `Event` decoding and `Output` -> `ByteBuffer?` encoding for `Codable` and `String`.

`EventLoopLambdaHandler` executes the user provided Lambda on the same `EventLoop` as the core runtime engine, making the processing fast but requires more care from the implementation to never block the `EventLoop`. It it designed for performance sensitive applications that use `Codable` or `String` based Lambda functions.

```swift
public protocol EventLoopLambdaHandler {
    /// The lambda functions input. In most cases this should be `Codable`. If your event originates from an
    /// AWS service, have a look at [AWSLambdaEvents](https://github.com/swift-server/swift-aws-lambda-events),
    /// which provides a number of commonly used AWS Event implementations.
    associatedtype Event
    /// The lambda functions output. Can be `Void`.
    associatedtype Output

    /// Create a Lambda handler for the runtime.
    ///
    /// Use this to initialize all your resources that you want to cache between invocations. This could be database
    /// connections and HTTP clients for example. It is encouraged to use the given `EventLoop`'s conformance
    /// to `EventLoopGroup` when initializing NIO dependencies. This will improve overall performance, as it
    /// minimizes thread hopping.
    static func makeHandler(context: LambdaInitializationContext) -> EventLoopFuture<Self>

    /// The Lambda handling method.
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - context: Runtime ``LambdaContext``.
    ///     - event: Event of type `Event` representing the event or request.
    ///
    /// - Returns: An `EventLoopFuture` to report the result of the Lambda back to the runtime engine.
    ///            The `EventLoopFuture` should be completed with either a response of type ``Output`` or an `Error`.
    func handle(_ event: Event, context: LambdaContext) -> EventLoopFuture<Output>

    /// Encode a response of type ``Output`` to `ByteBuffer`.
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    /// - parameters:
    ///     - value: Response of type ``Output``.
    ///     - buffer: A `ByteBuffer` to encode into, will be overwritten.
    ///
    /// - Returns: A `ByteBuffer` with the encoded version of the `value`.
    func encode(value: Output, into buffer: inout ByteBuffer) throws

    /// Decode a `ByteBuffer` to a request or event of type ``Event``.
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to decode.
    ///
    /// - Returns: A request or event of type ``Event``.
    func decode(buffer: ByteBuffer) throws -> Event
}
```

### LambdaHandler

`LambdaHandler` is a strongly typed, completion handler based asynchronous processing protocol for a Lambda that takes a user defined `Event` and returns a user defined `Output`.

`LambdaHandler` provides `ByteBuffer` -> `Event` decoding and `Output` -> `ByteBuffer` encoding for `Codable` and `String`.

`LambdaHandler` offloads the user provided Lambda execution to an async task making processing safer but slightly slower.

```swift
public protocol LambdaHandler {
    /// The lambda function's input. In most cases this should be `Codable`. If your event originates from an
    /// AWS service, have a look at [AWSLambdaEvents](https://github.com/swift-server/swift-aws-lambda-events),
    /// which provides a number of commonly used AWS Event implementations.
    associatedtype Event
    /// The lambda function's output. Can be `Void`.
    associatedtype Output

    /// The Lambda initialization method.
    /// Use this method to initialize resources that will be used in every request.
    ///
    /// Examples for this can be HTTP or database clients.
    /// - parameters:
    ///     - context: Runtime ``LambdaInitializationContext``.
    init(context: LambdaInitializationContext) async throws

    /// The Lambda handling method.
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - event: Event of type `Event` representing the event or request.
    ///     - context: Runtime ``LambdaContext``.
    ///
    /// - Returns: A Lambda result ot type `Output`.
    func handle(_ event: Event, context: LambdaContext) async throws -> Output

    /// Encode a response of type ``Output`` to `ByteBuffer`.
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    /// - parameters:
    ///     - value: Response of type ``Output``.
    ///     - buffer: A `ByteBuffer` to encode into, will be overwritten.
    ///
    /// - Returns: A `ByteBuffer` with the encoded version of the `value`.
    func encode(value: Output, into buffer: inout ByteBuffer) throws

    /// Decode a `ByteBuffer` to a request or event of type ``Event``.
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to decode.
    ///
    /// - Returns: A request or event of type ``Event``.
    func decode(buffer: ByteBuffer) throws -> Event
}
```

### SimpleLambdaHandler

`SimpleLambdaHandler` is a strongly typed, completion handler based asynchronous processing protocol for a Lambda that takes a user defined `Event` and returns a user defined `Output`.

`SimpleLambdaHandler` provides `ByteBuffer` -> `Event` decoding and `Output` -> `ByteBuffer` encoding for `Codable` and `String`.

`SimpleLambdaHandler` is the same as `LambdaHandler`, but does not require explicit initialization .

```swift
public protocol SimpleLambdaHandler {
    /// The lambda function's input. In most cases this should be `Codable`. If your event originates from an
    /// AWS service, have a look at [AWSLambdaEvents](https://github.com/swift-server/swift-aws-lambda-events),
    /// which provides a number of commonly used AWS Event implementations.
    associatedtype Event
    /// The lambda function's output. Can be `Void`.
    associatedtype Output

    init()

    /// The Lambda handling method.
    /// Concrete Lambda handlers implement this method to provide the Lambda functionality.
    ///
    /// - parameters:
    ///     - event: Event of type `Event` representing the event or request.
    ///     - context: Runtime ``LambdaContext``.
    ///
    /// - Returns: A Lambda result ot type `Output`.
    func handle(_ event: Event, context: LambdaContext) async throws -> Output

    /// Encode a response of type ``Output`` to `ByteBuffer`.
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    /// - parameters:
    ///     - value: Response of type ``Output``.
    ///     - buffer: A `ByteBuffer` to encode into, will be overwritten.
    ///
    /// - Returns: A `ByteBuffer` with the encoded version of the `value`.
    func encode(value: Output, into buffer: inout ByteBuffer) throws

    /// Decode a `ByteBuffer` to a request or event of type ``Event``.
    /// Concrete Lambda handlers implement this method to provide coding functionality.
    ///
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to decode.
    ///
    /// - Returns: A request or event of type ``Event``.
    func decode(buffer: ByteBuffer) throws -> Event
}
```

### Context

When calling the user provided Lambda function, the library provides a `LambdaContext` class that provides metadata about the execution context, as well as utilities for logging and allocating buffers.

```swift
public struct LambdaContext: CustomDebugStringConvertible, Sendable {
  /// The request ID, which identifies the request that triggered the function invocation.
  public var requestID: String {
      self.storage.requestID
  }

  /// The AWS X-Ray tracing header.
  public var traceID: String {
      self.storage.traceID
  }

  /// The ARN of the Lambda function, version, or alias that's specified in the invocation.
  public var invokedFunctionARN: String {
      self.storage.invokedFunctionARN
  }

  /// The timestamp that the function times out.
  public var deadline: DispatchWallTime {
      self.storage.deadline
  }

  /// For invocations from the AWS Mobile SDK, data about the Amazon Cognito identity provider.
  public var cognitoIdentity: String? {
      self.storage.cognitoIdentity
  }

  /// For invocations from the AWS Mobile SDK, data about the client application and device.
  public var clientContext: String? {
      self.storage.clientContext
  }

  /// `Logger` to log with.
  ///
  /// - note: The `LogLevel` can be configured using the `LOG_LEVEL` environment variable.
  public var logger: Logger {
      self.storage.logger
  }

  /// The `EventLoop` the Lambda is executed on. Use this to schedule work with.
  /// This is useful when implementing the ``EventLoopLambdaHandler`` protocol.
  ///
  /// - note: The `EventLoop` is shared with the Lambda runtime engine and should be handled with extra care.
  ///         Most importantly the `EventLoop` must never be blocked.
  public var eventLoop: EventLoop {
      self.storage.eventLoop
  }

  /// `ByteBufferAllocator` to allocate `ByteBuffer`.
  /// This is useful when implementing ``EventLoopLambdaHandler``.
  public var allocator: ByteBufferAllocator {
      self.storage.allocator
  }
}
```

Similarally, the library provides a context if and when initializing the Lambda.

```swift
public struct LambdaInitializationContext: Sendable {
    /// `Logger` to log with.
    ///
    /// - note: The `LogLevel` can be configured using the `LOG_LEVEL` environment variable.
    public let logger: Logger

    /// The `EventLoop` the Lambda is executed on. Use this to schedule work with.
    ///
    /// - note: The `EventLoop` is shared with the Lambda runtime engine and should be handled with extra care.
    ///         Most importantly the `EventLoop` must never be blocked.
    public let eventLoop: EventLoop

    /// `ByteBufferAllocator` to allocate `ByteBuffer`.
    public let allocator: ByteBufferAllocator

    /// ``LambdaTerminator`` to register shutdown operations.
    public let terminator: LambdaTerminator
}
```

### Configuration

The library’s behavior can be fine tuned using environment variables based configuration. The library supported the following environment variables:

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
4. The library hands off the `Context` and `Event` event to the user provided handler. In the case of `LambdaHandler` based handler this is done on a dedicated `DispatchQueue`, providing isolation between user's and the library's code.
5. User provided handler processes the request asynchronously, invoking a callback or returning a future upon completion, which returns a `Result` type with the `Output` or `Error` populated.
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
There are several areas which need additional attention, including but not limited to:

* Further performance tuning
* Additional documentation and best practices
* Additional examples

---
# Version 0.x (previous version) documentation
---

## Getting started

If you have never used AWS Lambda or Docker before, check out this [getting started guide](https://fabianfett.de/getting-started-with-swift-aws-lambda-runtime) which helps you with every step from zero to a running Lambda.

First, create a SwiftPM project and pull Swift AWS Lambda Runtime as dependency into your project

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

Next, create a `main.swift` and implement your Lambda.

### Using Closures

The simplest way to use `AWSLambdaRuntime` is to pass in a closure, for example:

 ```swift
 // Import the module
 import AWSLambdaRuntime

 // in this example we are receiving and responding with strings
 Lambda.run { (context, name: String, callback: @escaping (Result<String, Error>) -> Void) in
   callback(.success("Hello, \(name)"))
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
 Lambda.run { (context, request: Request, callback: @escaping (Result<Response, Error>) -> Void) in
   callback(.success(Response(message: "Hello, \(request.name)")))
 }
 ```

 Since most Lambda functions are triggered by events originating in the AWS platform like `SNS`, `SQS` or `APIGateway`, the [Swift AWS Lambda Events](http://github.com/swift-server/swift-aws-lambda-events) package includes an `AWSLambdaEvents` module that provides implementations for most common AWS event types further simplifying writing Lambda functions. For example, handling an `SQS` message:

First, add a dependency on the event packages:

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

 // In this example we are receiving an SQS Event, with no response (Void).
 Lambda.run { (context, message: SQS.Event, callback: @escaping (Result<Void, Error>) -> Void) in
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

`EventLoopLambdaHandler` is a strongly typed, `EventLoopFuture` based asynchronous processing protocol for a Lambda that takes a user defined `In` and returns a user defined `Out`.

`EventLoopLambdaHandler` extends `ByteBufferLambdaHandler`, providing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer?` encoding for `Codable` and `String`.

`EventLoopLambdaHandler` executes the user provided Lambda on the same `EventLoop` as the core runtime engine, making the processing fast but requires more care from the implementation to never block the `EventLoop`. It it designed for performance sensitive applications that use `Codable` or `String` based Lambda functions.

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

`LambdaHandler` is a strongly typed, completion handler based asynchronous processing protocol for a Lambda that takes a user defined `In` and returns a user defined `Out`.

`LambdaHandler` extends `ByteBufferLambdaHandler`, performing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding for `Codable` and `String`.

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

The library includes implementations for `Codable` and `String` based Lambda. Since AWS Lambda is primarily JSON based, this covers the most common use cases.

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
