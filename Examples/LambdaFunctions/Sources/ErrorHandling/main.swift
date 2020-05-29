//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntime

// MARK: - Run Lambda

// switch over the error type "requested" by the request, and trigger such error accordingly
Lambda.run { (context: Lambda.Context, request: Request, callback: (Result<Response, Error>) -> Void) in
    switch request.error {
    // no error here!
    case .none:
        callback(.success(Response(awsRequestID: context.requestID, requestID: request.requestID, status: .ok)))
    // trigger a "managed" error - domain specific business logic failure
    case .managed:
        callback(.success(Response(awsRequestID: context.requestID, requestID: request.requestID, status: .error)))
    // trigger an "unmanaged" error - an unexpected Swift Error triggered while processing the request
    case .unmanaged(let error):
        callback(.failure(UnmanagedError(description: error)))
    // trigger a "fatal" error - a panic type error which will crash the process
    case .fatal:
        fatalError("crash!")
    }
}

// MARK: - Request and Response

struct Request: Codable {
    let requestID: String
    let error: Error

    public init(requestID: String, error: Error? = nil) {
        self.requestID = requestID
        self.error = error ?? .none
    }

    public enum Error: Codable, RawRepresentable {
        case none
        case managed
        case unmanaged(String)
        case fatal

        public init?(rawValue: String) {
            switch rawValue {
            case "none":
                self = .none
            case "managed":
                self = .managed
            case "fatal":
                self = .fatal
            default:
                self = .unmanaged(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .none:
                return "none"
            case .managed:
                return "managed"
            case .fatal:
                return "fatal"
            case .unmanaged(let error):
                return error
            }
        }
    }
}

struct Response: Codable {
    let awsRequestID: String
    let requestID: String
    let status: Status

    public init(awsRequestID: String, requestID: String, status: Status) {
        self.awsRequestID = awsRequestID
        self.requestID = requestID
        self.status = status
    }

    public enum Status: Int, Codable {
        case ok
        case error
    }
}

struct UnmanagedError: Error {
    let description: String
}
