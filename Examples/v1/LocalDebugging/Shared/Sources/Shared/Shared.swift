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

public struct Request: Codable, CustomStringConvertible {
    public let name: String
    public let password: String

    public init(name: String, password: String) {
        self.name = name
        self.password = password
    }

    public var description: String {
        "name: \(self.name), password: ***"
    }
}

public struct Response: Codable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}
