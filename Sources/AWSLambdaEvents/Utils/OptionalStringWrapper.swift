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

@propertyWrapper
public struct OptionalStringCoding: Decodable {
    public let wrappedValue: String?

    public init(wrappedValue: String?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var maybeString = try container.decode(String?.self)
        if let string = maybeString, string.count == 0 {
            maybeString = nil
        }
        self.wrappedValue = maybeString
    }
}

extension KeyedDecodingContainer {
    // This is used to override the default decoding behavior for OptionalStringCoding to allow a value to avoid a missing key Error
    public func decode(_ type: OptionalStringCoding.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> OptionalStringCoding {
        try decodeIfPresent(OptionalStringCoding.self, forKey: key) ?? OptionalStringCoding(wrappedValue: nil)
    }
}
