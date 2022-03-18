//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// Sendable bridging types

#if compiler(>=5.6)
@preconcurrency public protocol _ByteBufferLambdaHandlerSendable: Sendable {}
#else
public protocol _ByteBufferLambdaHandlerSendable {}
#endif

#if compiler(>=5.6)
public typealias _AWSLambdaSendable = Sendable
#else
public typealias _AWSLambdaSendable = Any
#endif
