# Swift AWS Lambda

This library is designed to allow writing AWS Lambdas using the Swift programming language.

## Getting started

  1. Create a SwiftPM project and pull SwiftAwsLambda as dependency into your project

  ```
  // swift-tools-version:4.0

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

  2. Create a main.swift and implement you lambda. typically a lambda is implemented as a closure. For example, a simple lambda for a closure that receives a string payload and replies with the reverse version:

  ```
  import SwiftAwsLambda

  _ = Lambda.run { (context: LambdaContext, payload: String, callback: LambdaStringCallback) in
      callback(.success(String(payload.reversed())))
  }
  ```

note you can implement 3 types of lambdas:

1. `[UInt8]` (byte array) based (default): see `SwiftAwsLambdaExample`
2. `String` based: see `SwiftAwsLambdaStringExample`
3. `Codable` based: see `SwiftAwsLambdaCodableExample`

## Architecture

TODO

## Deploying

TODO
