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

import NIO

internal enum Consts {
    static let hostPortEnvVariableName = "AWS_LAMBDA_RUNTIME_API"

    static let invokationURLPrefix = "/RUNTIME/INVOCATION"
    static let requestWorkURLSuffix = "/NEXT"
    static let postResponseURLSuffix = "/RESPONSE"
    static let postErrorURLSuffix = "/ERROR"
}

internal enum AmazonHeaders {
    static let requestID = "X-Amz-Aws-Request-Id"
    static let traceID = "X-Amz-Trace-Id"
    static let clientContext = "X-Amz-Client-Context"
    static let cognitoIdentity = "X-Amz-Cognito-Identity"
    static let deadlineNS = "X-Amz-Deadline-Ns"
    static let invokedFunctionARN = "X-Amz-Invoked-Function-Arn"
}

internal enum Defaults {
    static let host = "127.0.0.1"
    static let port = 8080
}

internal enum Environment {
    static func string(name: String, defaultValue: String) -> String {
        return string(name) ?? defaultValue
    }

    static func string(_ name: String) -> String? {
        guard let value = getenv(name) else {
            return nil
        }
        return String(validatingUTF8: value)
    }

    static func int(name: String, defaultValue: Int) -> Int {
        return int(name) ?? defaultValue
    }

    static func int(_ name: String) -> Int? {
        guard let value = string(name) else {
            return nil
        }
        return Int(value)
    }
}
