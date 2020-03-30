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

/// https://github.com/aws/aws-lambda-go/blob/master/events/sqs.go
public enum SQS {
    public struct Event: Decodable {
        public let records: [Message]

        enum CodingKeys: String, CodingKey {
            case records = "Records"
        }
    }

    public struct Message {
        /// https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_MessageAttributeValue.html
        public enum Attribute {
            case string(String)
            case binary([UInt8])
            case number(AWSNumber)
        }

        public let messageId: String
        public let receiptHandle: String
        public let body: String?
        public let md5OfBody: String
        public let md5OfMessageAttributes: String?
        public let attributes: [String: String]
        public let messageAttributes: [String: Attribute]
        public let eventSourceArn: String
        public let eventSource: String
        public let awsRegion: AWSRegion
    }
}

extension SQS.Message: Decodable {
    enum CodingKeys: String, CodingKey {
        case messageId
        case receiptHandle
        case body
        case md5OfBody
        case md5OfMessageAttributes
        case attributes
        case messageAttributes
        case eventSourceArn = "eventSourceARN"
        case eventSource
        case awsRegion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.messageId = try container.decode(String.self, forKey: .messageId)
        self.receiptHandle = try container.decode(String.self, forKey: .receiptHandle)
        self.md5OfBody = try container.decode(String.self, forKey: .md5OfBody)
        self.md5OfMessageAttributes = try container.decodeIfPresent(String.self, forKey: .md5OfMessageAttributes)
        self.attributes = try container.decode([String: String].self, forKey: .attributes)
        self.messageAttributes = try container.decode([String: Attribute].self, forKey: .messageAttributes)
        self.eventSourceArn = try container.decode(String.self, forKey: .eventSourceArn)
        self.eventSource = try container.decode(String.self, forKey: .eventSource)
        self.awsRegion = try container.decode(AWSRegion.self, forKey: .awsRegion)

        let body = try container.decode(String?.self, forKey: .body)
        self.body = body != "" ? body : nil
    }
}

extension SQS.Message.Attribute: Equatable {}

extension SQS.Message.Attribute: Decodable {
    enum CodingKeys: String, CodingKey {
        case dataType
        case stringValue
        case binaryValue

        // BinaryListValue and StringListValue are unimplemented since
        // they are not implemented as discussed here:
        // https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_MessageAttributeValue.html
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dataType = try container.decode(String.self, forKey: .dataType)
        switch dataType {
        case "String":
            let value = try container.decode(String.self, forKey: .stringValue)
            self = .string(value)
        case "Number":
            let value = try container.decode(AWSNumber.self, forKey: .stringValue)
            self = .number(value)
        case "Binary":
            let base64encoded = try container.decode(String.self, forKey: .binaryValue)
            let bytes = try base64encoded.base64decoded()
            self = .binary(bytes)
        default:
            throw DecodingError.dataCorruptedError(forKey: .dataType, in: container, debugDescription: """
            Unexpected value \"\(dataType)\" for key \(CodingKeys.dataType).
            Expected `String`, `Binary` or `Number`.
            """)
        }
    }
}
