//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public struct AWSNumber: Codable, Equatable {
    public let stringValue: String

    public var int: Int? {
        Int(self.stringValue)
    }

    public var double: Double? {
        Double(self.stringValue)
    }

    public init(int: Int) {
        self.stringValue = String(int)
    }

    public init(double: Double) {
        self.stringValue = String(double)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.stringValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }
}
