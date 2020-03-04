# Swift AWS Lambda

This library is designed to simplify implementing an AWS Lambda using the Swift programming language.

## Getting started

  1. Create a SwiftPM project and pull SwiftAwsLambda as dependency into your project

  ```swift
  // swift-tools-version:5.0
  import PackageDescription

  let package = Package(
    name: "my-lambda",
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda.git", .upToNextMajor(from: "0.1.0")),
    ],
    targets: [
        .target(name: "MyLambda", dependencies: ["SwiftAwsLambda"]),
    ]
  )
  ```

  2. Create a main.swift and implement your Lambda. Typically a Lambda is implemented as a closure. For example, a simple closure that receives a string payload and replies with the reverse version:

  ```swift
  import SwiftAwsLambda

  // in this example we are receiving and responding with strings
  Lambda.run { (context, payload: String, callback) in
      callback(.success(String(payload.reversed())))
  }
  ```

  Or more typically, a simple closure that receives a json payload and replies with a json response via `Codable`:

  ```swift
  private struct Request: Codable {}
  private struct Response: Codable {}

  // in this example we are receiving and responding with codables. Request and Response above are examples of how to use
  // codables to model your reqeuest and response objects
  Lambda.run { (_, _: Request, callback) in
      callback(.success(Response()))
  }
  ```

  See a complete example in SwiftAwsLambdaSample.

  3. Deploy to AWS Lambda. To do so, you need to compile your Application for EC2 Linux, package it as a Zip file, and upload to AWS. You can find sample build and deployment scripts in SwiftAwsLambdaSample.

## Architecture

The library supports three types of Lambdas:
1. `[UInt8]` (byte array) based (default): see `SwiftAwsLambdaExample`
2. `String` based: see `SwiftAwsLambdaStringExample`
3. `Codable` based: see `SwiftAwsLambdaCodableExample`. This is the most pragmatic mode of operation, since AWS Lambda is JSON based.


The library is designed to integrate with AWS Lambda Runtime Engine, via the BYOL Native Runtime API.
The latter is an HTTP server that exposes three main RESTful endpoint:
* `/runtime/invocation/next`
* `/runtime/invocation/response`
* `/runtime/invocation/error`

The library encapsulates these endpoints and the expected lifecycle via `LambdaRuntimeClient` and `LambdaRunner` respectively.

**Single Lambda Execution Workflow**

1. The library calls AWS Lambda Runtime Engine `/next` endpoint to retrieve the next invocation request.
2. The library parses the response HTTP headers and populate the `LambdaContext` object.
3. The library reads the response body and attempt to decode it, if required. Typically it decodes to user provided type which extends  `Decodable`, but users may choose to write Lambdas that receive the input as `String` or `[UInt8]` byte array which require less, or no decoding.
4. The library hands off the `Context` and `Request` to the user provided handler on a dedicated `Dispatch` queue, providing isolation between user's and the library's code.
5. User's code processes the request asynchronously, invoking a callback upon completion, which returns a result type with the `Response` or `Error` populated.
6. In case of error, the library posts to AWS Lambda Runtime Engine `/error` endpoint to provide the error details, which will show up on AWS Lambda logs.
7. In case of success, the library will attempt to encode the response, if required. Typically it encodes from user provided type which extends `Encodable`, but users may choose to write Lambdas that return a `String` or `[UInt8]` byte array, which require less, or no encoding. The library then posts to AWS Lambda Runtime Engine `/response` endpoint to provide the response.

**Lifecycle Management**

AWS Runtime Engine controls the Application lifecycle and in the happy case never terminates the application, only suspends it's execution when no work is avaialble. As such, the library main entry point is designed to run forever in a blocking fashion, performing the workflow described above in an endless loop. That loop is broken if/when an internal error occurs, such as a failure to communicate with AWS Runtime Engine API, or under other unexpected conditions.
