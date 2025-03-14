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

import Foundation
import Logging
import NIOCore
import Synchronization
import Testing

@testable import AWSLambdaRuntime

@Suite("LambdaRuntimeTests")
final class LambdaRuntimeTests {

    @Test("LambdaRuntime can only be initialized once")
    func testLambdaRuntimeInitializationFatalError() throws {

        // First initialization should succeed
        try _ = LambdaRuntime(handler: MockHandler(), eventLoop: Lambda.defaultEventLoop, logger: Logger(label: "Test"))

        // Second initialization should trigger LambdaRuntimeError
        #expect(throws: LambdaRuntimeError.self) {
            try _ = LambdaRuntime(
                handler: MockHandler(),
                eventLoop: Lambda.defaultEventLoop,
                logger: Logger(label: "Test")
            )
        }

    }
}

struct MockHandler: StreamingLambdaHandler {
    mutating func handle(
        _ event: NIOCore.ByteBuffer,
        responseWriter: some AWSLambdaRuntime.LambdaResponseStreamWriter,
        context: AWSLambdaRuntime.LambdaContext
    ) async throws {

    }
}
