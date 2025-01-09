//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported import AWSLambdaRuntime

import ServiceLifecycle


///
/// Encapsulate a LambdaRuntime+Codable to offer the same API but this time exposed as a Swift Service
/// This allows to avoid the Service extra payload for Lambda functions that doesn't need it
///
public class LambdaRuntimeService<Handler>: Service, @unchecked Sendable where Handler: StreamingLambdaHandler  {

    let runtime: LambdaRuntime<Handler>

    public func run() async throws {
        try await cancelWhenGracefulShutdown {
            try await self.runtime.run()
        }
    }

    init(handler: sending Handler) {
        self.runtime = LambdaRuntime(handler: handler)
    }
}