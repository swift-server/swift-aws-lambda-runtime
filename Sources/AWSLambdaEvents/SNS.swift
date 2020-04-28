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

import struct Foundation.Date

// https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html

public enum SNS {
    public struct Event: Decodable {
        public struct Record: Decodable {
            public let eventVersion: String
            public let eventSubscriptionArn: String
            public let eventSource: String
            public let sns: Message

            public enum CodingKeys: String, CodingKey {
                case eventVersion = "EventVersion"
                case eventSubscriptionArn = "EventSubscriptionArn"
                case eventSource = "EventSource"
                case sns = "Sns"
            }
        }

        public let records: [Record]

        public enum CodingKeys: String, CodingKey {
            case records = "Records"
        }
    }

    public struct Message {
        public enum Attribute {
            case string(String)
            case binary([UInt8])
        }

        public let signature: String
        public let messageId: String
        public let type: String
        public let topicArn: String
        public let messageAttributes: [String: Attribute]
        public let signatureVersion: String

        @ISO8601WithFractionalSecondsCoding
        public var timestamp: Date
        public let signingCertURL: String
        public let message: String
        public let unsubscribeUrl: String
        public let subject: String?
    }
}

extension SNS.Message: Decodable {
    enum CodingKeys: String, CodingKey {
        case signature = "Signature"
        case messageId = "MessageId"
        case type = "Type"
        case topicArn = "TopicArn"
        case messageAttributes = "MessageAttributes"
        case signatureVersion = "SignatureVersion"
        case timestamp = "Timestamp"
        case signingCertURL = "SigningCertUrl"
        case message = "Message"
        case unsubscribeUrl = "UnsubscribeUrl"
        case subject = "Subject"
    }
}

extension SNS.Message.Attribute: Equatable {}

extension SNS.Message.Attribute: Decodable {
    enum CodingKeys: String, CodingKey {
        case dataType = "Type"
        case dataValue = "Value"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dataType = try container.decode(String.self, forKey: .dataType)
        // https://docs.aws.amazon.com/sns/latest/dg/sns-message-attributes.html#SNSMessageAttributes.DataTypes
        switch dataType {
        case "String":
            let value = try container.decode(String.self, forKey: .dataValue)
            self = .string(value)
        case "Binary":
            let base64encoded = try container.decode(String.self, forKey: .dataValue)
            let bytes = try base64encoded.base64decoded()
            self = .binary(bytes)
        default:
            throw DecodingError.dataCorruptedError(forKey: .dataType, in: container, debugDescription: """
            Unexpected value \"\(dataType)\" for key \(CodingKeys.dataType).
            Expected `String` or `Binary`.
            """)
        }
    }
}
