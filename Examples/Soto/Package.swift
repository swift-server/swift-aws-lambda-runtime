// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

//===----------------------------------------------------------------------===//
//
// This source file is part of the AWS Lambda Swift 
// VSCode extension open source project.
//
// Copyright (c) 2024, the VSCode AWS Lambda Swift extension project authors.
// Licensed under Apache License v2.0.
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of VSCode AWS Lambda Swift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import PackageDescription

// needed for CI to test the local version of the library
import class Foundation.ProcessInfo
import struct Foundation.URL

#if os(macOS)
let platforms: [PackageDescription.SupportedPlatform]? = [.macOS(.v15)]
#else
let platforms: [PackageDescription.SupportedPlatform]? = nil
#endif


let package = Package(
    name: "SotoLambdaExample",
    platforms: platforms,
    products: [
        .executable(name: "SotoLambdaExample", targets: ["SotoExample"])
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0"),
        
        // dependency on swift-aws-lambda-runtime is added dynamically below
        // .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main")
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "SotoExample",
            dependencies: [
                .product(name: "SotoS3", package: "soto"),
                .product(name: "AWSLambdaRuntime",package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents",package: "swift-aws-lambda-events"),
            ]
        )
    ]
)

if let localDepsPath = ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"],
    localDepsPath != "",
    let v = try? URL(fileURLWithPath: localDepsPath).resourceValues(forKeys: [.isDirectoryKey]),
    let _ = v.isDirectory
{
    print("[INFO] Compiling against swift-aws-lambda-runtime located at \(localDepsPath)")
    package.dependencies += [
        .package(name: "swift-aws-lambda-runtime", path: localDepsPath)
    ]

} else {
    print("[INFO] LAMBDA_USE_LOCAL_DEPS is not pointing to your local swift-aws-lambda-runtime code")
    print("[INFO] This project will compile against the main branch of the Lambda Runtime on GitHub")
    package.dependencies += [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main")
    ]
}