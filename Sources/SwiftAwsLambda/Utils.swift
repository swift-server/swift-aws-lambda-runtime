//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAwsLambda open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAwsLambda project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAwsLambda project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import NIO

internal enum Defaults {
    static let host = "127.0.0.1"
    static let port = 8080
}

internal enum Consts {
    static let hostPortEnvVariableName = "AWS_LAMBDA_RUNTIME_API"

    private static let apiPrefix = "/2018-06-01"
    static let invokationURLPrefix = "\(apiPrefix)/runtime/invocation"
    static let requestWorkURLSuffix = "/next"
    static let postResponseURLSuffix = "/response"
    static let postErrorURLSuffix = "/error"
}

/// AWS Lambda HTTP Headers, used to populate the `LambdaContext` object.
internal enum AmazonHeaders {
    static let requestID = "Lambda-Runtime-Aws-Request-Id"
    static let traceID = "Lambda-Runtime-Trace-Id"
    static let clientContext = "X-Amz-Client-Context"
    static let cognitoIdentity = "X-Amz-Cognito-Identity"
    static let deadline = "Lambda-Runtime-Deadline-Ms"
    static let invokedFunctionARN = "Lambda-Runtime-Invoked-Function-Arn"
}

/// Utility to read environment variables
internal enum Environment {
    static func string(name: String, defaultValue: String) -> String {
        return self.string(name) ?? defaultValue
    }

    static func string(_ name: String) -> String? {
        guard let value = getenv(name) else {
            return nil
        }
        return String(validatingUTF8: value)
    }

    static func int(name: String, defaultValue: Int) -> Int {
        return self.int(name) ?? defaultValue
    }

    static func int(_ name: String) -> Int? {
        guard let value = string(name) else {
            return nil
        }
        return Int(value)
    }
}

/// Helper function to trap signals
internal func trap(signal sig: Signal, handler: @escaping (Signal) -> Void) -> DispatchSourceSignal {
    let signalSource = DispatchSource.makeSignalSource(signal: sig.rawValue, queue: DispatchQueue.global())
    signal(sig.rawValue, SIG_IGN)
    signalSource.setEventHandler(handler: {
        signalSource.cancel()
        handler(sig)
    })
    signalSource.resume()
    return signalSource
}

internal enum Signal: Int32 {
    case HUP = 1
    case INT = 2
    case QUIT = 3
    case ABRT = 6
    case KILL = 9
    case ALRM = 14
    case TERM = 15
}
