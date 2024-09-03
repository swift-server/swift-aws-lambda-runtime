//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

package protocol LambdaRuntimeClientResponseStreamWriter: LambdaResponseStreamWriter {
    mutating func write(_ buffer: ByteBuffer) async throws
    func finish() async throws
    func writeAndFinish(_ buffer: ByteBuffer) async throws
    func reportError(_ error: any Error) async throws
}

package protocol LambdaRuntimeClientProtocol {
    associatedtype Writer: LambdaRuntimeClientResponseStreamWriter

    func nextInvocation() async throws -> (Invocation, Writer)
}

package struct Invocation {
    package var metadata: InvocationMetadata
    package var event: ByteBuffer

    package init(metadata: InvocationMetadata, event: ByteBuffer) {
        self.metadata = metadata
        self.event = event
    }
}
