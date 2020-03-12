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
import struct Foundation.TimeInterval

/// https://github.com/aws/aws-lambda-go/blob/master/events/dynamodb.go
public enum DynamoDB {
    public struct Event: Decodable {
        public let records: [EventRecord]

        public enum CodingKeys: String, CodingKey {
            case records = "Records"
        }
    }

    public enum KeyType: String, Codable {
        case hash = "HASH"
        case range = "RANGE"
    }

    public enum OperationType: String, Codable {
        case insert = "INSERT"
        case modify = "MODIFY"
        case remove = "REMOVE"
    }

    public enum SharedIteratorType: String, Codable {
        case trimHorizon = "TRIM_HORIZON"
        case latest = "LATEST"
        case atSequenceNumber = "AT_SEQUENCE_NUMBER"
        case afterSequenceNumber = "AFTER_SEQUENCE_NUMBER"
    }

    public enum StreamStatus: String, Codable {
        case enabling = "ENABLING"
        case enabled = "ENABLED"
        case disabling = "DISABLING"
        case disabled = "DISABLED"
    }

    public enum StreamViewType: String, Codable {
    /// the entire item, as it appeared after it was modified.
        case newImage = "NEW_IMAGE"
    /// the entire item, as it appeared before it was modified.
        case oldImage = "OLD_IMAGE"
    /// both the new and the old item images of the item.
        case newAndOldImages = "NEW_AND_OLD_IMAGES"
    /// only the key attributes of the modified item.
        case keysOnly = "KEYS_ONLY"
    }

    public struct EventRecord: Decodable {
        /// The region in which the GetRecords request was received.
        public let awsRegion: String

        /// The main body of the stream record, containing all of the DynamoDB-specific
        /// fields.
        public let change: StreamRecord

        /// A globally unique identifier for the event that was recorded in this stream
        /// record.
        public let eventId: String

        /// The type of data modification that was performed on the DynamoDB table:
        ///  * INSERT - a new item was added to the table.
        ///  * MODIFY - one or more of an existing item's attributes were modified.
        ///  * REMOVE - the item was deleted from the table
        public let eventName: OperationType

        /// The AWS service from which the stream record originated. For DynamoDB Streams,
        /// this is aws:dynamodb.
        public let eventSource: String

        /// The version number of the stream record format. This number is updated whenever
        /// the structure of Record is modified.
        ///
        /// Client applications must not assume that eventVersion will remain at a particular
        /// value, as this number is subject to change at any time. In general, eventVersion
        /// will only increase as the low-level DynamoDB Streams API evolves.
        public let eventVersion: String

        /// The event source ARN of DynamoDB
        public let eventSourceArn: String

        /// Items that are deleted by the Time to Live process after expiration have
        /// the following fields:
        ///  * Records[].userIdentity.type
        ///
        /// "Service"
        ///  * Records[].userIdentity.principalId
        ///
        /// "dynamodb.amazonaws.com"
        public let userIdentity: UserIdentity?

        public enum CodingKeys: String, CodingKey {
            case awsRegion
            case change = "dynamodb"
            case eventId = "eventID"
            case eventName
            case eventSource
            case eventVersion
            case eventSourceArn = "eventSourceARN"
            case userIdentity
        }
    }

    public struct StreamRecord {
        /// The approximate date and time when the stream record was created, in UNIX
        /// epoch time (http://www.epochconverter.com/) format.
        public let approximateCreationDateTime: Date?

        /// The primary key attribute(s) for the DynamoDB item that was modified.
        public let keys: [String: AttributeValue]

        /// The item in the DynamoDB table as it appeared after it was modified.
        public let newImage: [String: AttributeValue]?

        /// The item in the DynamoDB table as it appeared before it was modified.
        public let oldImage: [String: AttributeValue]?

        /// The sequence number of the stream record.
        public let sequenceNumber: String

        /// The size of the stream record, in bytes.
        public let sizeBytes: Int64

        /// The type of data from the modified DynamoDB item that was captured in this
        /// stream record.
        public let streamViewType: StreamViewType
    }

    public struct UserIdentity: Codable {
        public let type: String
        public let principalId: String
    }
}

extension DynamoDB.StreamRecord: Decodable {
    enum CodingKeys: String, CodingKey {
        case approximateCreationDateTime = "ApproximateCreationDateTime"
        case keys = "Keys"
        case newImage = "NewImage"
        case oldImage = "OldImage"
        case sequenceNumber = "SequenceNumber"
        case sizeBytes = "SizeBytes"
        case streamViewType = "StreamViewType"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.keys = try container.decode(
            [String: DynamoDB.AttributeValue].self,
            forKey: .keys
        )

        self.newImage = try container.decodeIfPresent(
            [String: DynamoDB.AttributeValue].self,
            forKey: .newImage
        )
        self.oldImage = try container.decodeIfPresent(
            [String: DynamoDB.AttributeValue].self,
            forKey: .oldImage
        )

        self.sequenceNumber = try container.decode(String.self, forKey: .sequenceNumber)
        self.sizeBytes = try container.decode(Int64.self, forKey: .sizeBytes)
        self.streamViewType = try container.decode(DynamoDB.StreamViewType.self, forKey: .streamViewType)

        if let timestamp = try container.decodeIfPresent(TimeInterval.self, forKey: .approximateCreationDateTime) {
            self.approximateCreationDateTime = Date(timeIntervalSince1970: timestamp)
        } else {
            self.approximateCreationDateTime = nil
        }
    }
}
