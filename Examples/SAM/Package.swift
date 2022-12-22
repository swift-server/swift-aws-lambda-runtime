// swift-tools-version:5.7

// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
  name: "swift-aws-lambda-runtime-example",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .executable(name: "HttpApiLambda", targets: ["HttpApiLambda"]),
    .executable(name: "SQSLambda", targets: ["SQSLambda"]),
    // this generate the AWS SAM template for deployment. It is called by the deployment plugin (swift package deploy)
    .executable(name: "Deploy", targets: ["Deploy"])
  ],
  dependencies: [
    // this is the dependency on the swift-aws-lambda-runtime library
    // in real-world projects this would say
    // .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
    .package(name: "swift-aws-lambda-runtime", path: "../.."),
    .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main")
  ],
  targets: [
    .executableTarget(
      name: "Deploy",
      dependencies: [
        .product(name: "AWSLambdaDeploymentDescriptor", package: "swift-aws-lambda-runtime")
      ],
      path: "./Deploy"
    ),
    .executableTarget(
      name: "HttpApiLambda",
      dependencies: [
        .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events")
      ],
      path: "./HttpApiLambda"
    ),
    .executableTarget(
      name: "SQSLambda",
      dependencies: [
        .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events")
      ],
      path: "./SQSLambda"
    )
  ]
)
