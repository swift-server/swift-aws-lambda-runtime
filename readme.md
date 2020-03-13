# SwiftAWSLambdaRuntime

SwiftAWSLambdaRuntime is a Swift implementation of [AWS Lambda Runtime](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html).
AWS Lambda runtime is a program that runs a Lambda function's handler method when the function is invoked.
SwiftAWSLambdaRuntime is designed to simplify the implementation of an AWS Lambda using the Swift programming language.

## Getting started

1. Create a SwiftPM project and pull SwiftAWSLambdaRuntime as dependency into your project

```swift
// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "my-lambda",
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", .branch("master")),
    ],
    targets: [
        .target(name: "MyLambda", dependencies: [
          .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda"),
        ]),
    ]
)
```

2. Create a main.swift and implement your Lambda. Typically a Lambda is implemented as a closure.
    For example, a closure that receives a string payload and replies with the reverse version:

```swift
import AWSLambdaRuntime

// in this example we are receiving and responding with strings
Lambda.run { (context, payload: String, callback) in
  callback(.success(String(payload.reversed())))
}
```

Or more typically, a closure that receives a JSON payload and replies with a JSON response via `Codable`:

```swift
import AWSLambdaRuntime

private struct Request: Codable {}
private struct Response: Codable {}

// in this example we are receiving and responding with codables. Request and Response above are examples of how to use
// codables to model your request and response objects
Lambda.run { (_, _: Request, callback) in
  callback(.success(Response()))
}
```

See a complete example in AWSLambdaRuntimeSample.

3. Deploy to AWS Lambda. To do so, you need to compile your Application for Amazon 2 Linux, package it as a Zip file, and upload to AWS.
    You can find sample build and deployment scripts in AWSLambdaRuntimeSample.

## Architecture

The library defined 3 base protcols for the implementation of a Lambda:

1. `ByteBufferLambdaHandler`: `EventLoopFuture` based processing protocol for a Lambda that takes a `ByteBuffer` and returns a `ByteBuffer?` asynchronously.

    `ByteBufferLambdaHandler` is a low level protocol designed to power the higher level `EventLoopLambdaHandler` and `LambdaHandler` based APIs.

    Most users are not expected to use this protocol.

2. `EventLoopLambdaHandler`: Strongly typed, `EventLoopFuture` based processing protocol for a Lambda that takes a user defined `In` and returns a user defined `Out` asynchronously.

    `EventLoopLambdaHandler` extends `ByteBufferLambdaHandler`, performing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding.

    `EventLoopLambdaHandler` executes the Lambda on the same `EventLoop` as the core runtime engine, making the processing faster but requires more care from the implementation to never block the `EventLoop`.

3. `LambdaHandler`: Strongly typed, callback based processing protocol for a Lambda that takes a user defined `In` and returns a user defined `Out` asynchronously.

    `LambdaHandler` extends `ByteBufferLambdaHandler`, performing `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding.

    `LambdaHandler` offloads the Lambda execution to a `DispatchQueue` making processing safer but slower.

In addition to protocol based Lambda, the library provides support for Closure based ones, as demosrated in the getting started section.
Closure based Lambda are based on the `LambdaHandler` protocol which mean the are safer but slower.
For most use cases, Closure based Lambda is a great fit.
Only performance sensitive use cases should explore the `EventLoopLambdaHandler` protocol based approach as it requires more care from the implementation to never block the `EventLoop`.

The library includes built-in codec for `String` and `Codable` into `ByteBuffer`, which means users can express `String` and `Codable` based Lambda without the need to provide encoding and decoding logic.
Since AWS Lambda is primarily JSON based, this covers the most common use cases.
The design does allow for other payload types as well, and such Lambda implementaion can extend one of the above protocols and provided their own `ByteBuffer` -> `In` decoding and `Out` -> `ByteBuffer` encoding.


The library is designed to integrate with AWS Lambda Runtime Engine, via the BYOL Native Runtime API.
The latter is an HTTP server that exposes three main RESTful endpoint:
* `/runtime/invocation/next`
* `/runtime/invocation/response`
* `/runtime/invocation/error`

The library encapsulates these endpoints and the expected lifecycle via `Lambda.RuntimeClient` and `Lambda.Runner` respectively.

**Single Lambda Execution Workflow**

1. The library calls AWS Lambda Runtime Engine `/next` endpoint to retrieve the next invocation request.
2. The library parses the response HTTP headers and populate the `Lambda.Context` object.
3. The library reads the response body and attempt to decode it, if required.
    Typically it decodes to user provided type which extends `Decodable`, but users may choose to write Lambdas that receive the input as `String` or `ByteBuffer` which require less, or no decoding.
4. The library hands off the `Context` and `Request` to the user provided handler.
    In the case of `LambdaHandler` based Lambda this is done on a dedicated `DispatchQueue`, providing isolation between user's and the library's code.
5. User's code processes the request asynchronously, invoking a callback or returning a future upon completion, which returns a result type with the `Response` or `Error` populated.
6. In case of error, the library posts to AWS Lambda Runtime Engine `/error` endpoint to provide the error details, which will show up on AWS Lambda logs.
7. In case of success, the library will attempt to encode the response, if required.
    Typically it encodes from user provided type which extends `Encodable`, but users may choose to write Lambdas that return a `String` or `ByteBuffer`, which require less, or no encoding.
     The library then posts to AWS Lambda Runtime Engine `/response` endpoint to provide the response.

**Lifecycle Management**

AWS Runtime Engine controls the Application lifecycle and in the happy case never terminates the application, only suspends it's execution when no work is avaialble. As such, the library main entry point is designed to run forever in a blocking fashion, performing the workflow described above in an endless loop. That loop is broken if/when an internal error occurs, such as a failure to communicate with AWS Runtime Engine API, or under other unexpected conditions.
