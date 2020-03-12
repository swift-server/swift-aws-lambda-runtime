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

extension DynamoDB {
    public enum AttributeValue {
        case boolean(Bool)
        case binary([UInt8])
        case binarySet([[UInt8]])
        case string(String)
        case stringSet([String])
        case null
        case number(AWSNumber)
        case numberSet([AWSNumber])

        case list([AttributeValue])
        case map([String: AttributeValue])
    }
}

extension DynamoDB.AttributeValue: Decodable {
    enum CodingKeys: String, CodingKey {
        case binary = "B"
        case bool = "BOOL"
        case binarySet = "BS"
        case list = "L"
        case map = "M"
        case number = "N"
        case numberSet = "NS"
        case null = "NULL"
        case string = "S"
        case stringSet = "SS"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            let context = DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Expected exactly one key, but got \(container.allKeys.count)"
            )
            throw DecodingError.dataCorrupted(context)
        }

        switch key {
        case .binary:
            let encoded = try container.decode(String.self, forKey: .binary)
            let bytes = try encoded.base64decoded()
            self = .binary(bytes)

        case .bool:
            let value = try container.decode(Bool.self, forKey: .bool)
            self = .boolean(value)

        case .binarySet:
            let values = try container.decode([String].self, forKey: .binarySet)
            let bytesArray = try values.map { try $0.base64decoded() }
            self = .binarySet(bytesArray)

        case .list:
            let values = try container.decode([DynamoDB.AttributeValue].self, forKey: .list)
            self = .list(values)

        case .map:
            let value = try container.decode([String: DynamoDB.AttributeValue].self, forKey: .map)
            self = .map(value)

        case .number:
            let value = try container.decode(AWSNumber.self, forKey: .number)
            self = .number(value)

        case .numberSet:
            let values = try container.decode([AWSNumber].self, forKey: .numberSet)
            self = .numberSet(values)

        case .null:
            self = .null

        case .string:
            let value = try container.decode(String.self, forKey: .string)
            self = .string(value)

        case .stringSet:
            let values = try container.decode([String].self, forKey: .stringSet)
            self = .stringSet(values)
        }
    }
}

extension DynamoDB.AttributeValue: Equatable {
    public static func == (lhs: DynamoDB.AttributeValue, rhs: DynamoDB.AttributeValue) -> Bool {
        switch (lhs, rhs) {
        case (.boolean(let lhs), .boolean(let rhs)):
            return lhs == rhs
        case (.binary(let lhs), .binary(let rhs)):
            return lhs == rhs
        case (.binarySet(let lhs), .binarySet(let rhs)):
            return lhs == rhs
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.stringSet(let lhs), .stringSet(let rhs)):
            return lhs == rhs
        case (.null, .null):
            return true
        case (.number(let lhs), .number(let rhs)):
            return lhs == rhs
        case (.numberSet(let lhs), .numberSet(let rhs)):
            return lhs == rhs
        case (.list(let lhs), .list(let rhs)):
            return lhs == rhs
        case (.map(let lhs), .map(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}
