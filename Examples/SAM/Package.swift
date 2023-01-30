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

var deploymentDescriptorDependency : [Target.Dependency] = []
#if !os(Linux)
    deploymentDescriptorDependency = [.product(name: "AWSLambdaDeploymentDescriptor", package: "swift-aws-lambda-runtime")]
#endif

let package = Package(
  name: "swift-aws-lambda-runtime-example",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .executable(name: "HttpApiLambda", targets: ["HttpApiLambda"]),
    .executable(name: "SQSLambda", targets: ["SQSLambda"]),
  ],
  dependencies: [
    // this is the dependency on the swift-aws-lambda-runtime library
    // in real-world projects this would say
//    .package(url: "https://github.com/sebsto/swift-aws-lambda-runtime.git", branch: "sebsto/deployerplugin"),
//    .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
    .package(name: "swift-aws-lambda-runtime", path: "../.."),
    .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", branch: "main")
  ],
  targets: [
    .executableTarget(
      name: "HttpApiLambda",
      dependencies: [
        .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events")
      ] + deploymentDescriptorDependency,
      path: "./HttpApiLambda"
    ),
    .executableTarget(
      name: "SQSLambda",
      dependencies: [
        .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events")
      ] + deploymentDescriptorDependency,
      path: "./SQSLambda"
    )
  ]
)
