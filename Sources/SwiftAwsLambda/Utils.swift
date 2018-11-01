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

internal final class Consts {
    static let HostPortEnvVariableName = "AWS_LAMBDA_RUNTIME_API"

    static let InvokationUrlPrefix = "/RUNTIME/INVOCATION"
    static let RequestWorkUrlSuffix = "/NEXT"
    static let PostResponseUrlSuffix = "/RESPONSE"
    static let PostErrorUrlSuffix = "/ERROR"
}

internal final class AmazonHeaders {
    static let RequestId = "X-Amz-Aws-Request-Id"
    static let TraceId = "X-Amz-Trace-Id"
    static let ClientContext = "X-Amz-Client-Context"
    static let CognitoIdentity = "X-Amz-Cognito-Identity"
    static let DeadlineNs = "X-Amz-Deadline-Ns"
    static let InvokedFunctionArn = "X-Amz-Invoked-Function-Arn"
}

internal final class Defaults {
    static let Host = "127.0.0.1"
    static let Port = 8080
}

internal final class Environment {
    class func getString(name: String, defaultValue: String) -> String {
        return getString(name) ?? defaultValue
    }

    class func getString(_ name: String) -> String? {
        guard let value = getenv(name) else {
            return nil
        }
        return String(validatingUTF8: value)
    }

    class func getInt(name: String, defaultValue: Int) -> Int {
        return getInt(name) ?? defaultValue
    }

    class func getInt(_ name: String) -> Int? {
        guard let value = getString(name) else {
            return nil
        }
        return Int(value)
    }
}

internal extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
