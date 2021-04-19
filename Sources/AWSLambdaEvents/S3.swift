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

// https://docs.aws.amazon.com/lambda/latest/dg/with-s3.html

public struct S3Event: Decodable {
    public struct Record: Decodable {
        public let eventVersion: String
        public let eventSource: String
        public let awsRegion: AWSRegion

        @ISO8601WithFractionalSecondsCoding
        public var eventTime: Date
        public let eventName: String
        public let userIdentity: UserIdentity
        public let requestParameters: RequestParameters
        public let responseElements: [String: String]
        public let s3: Entity
    }

    public let records: [Record]

    public enum CodingKeys: String, CodingKey {
        case records = "Records"
    }

    public struct RequestParameters: Codable, Equatable {
        public let sourceIPAddress: String
    }

    public struct UserIdentity: Codable, Equatable {
        public let principalId: String
    }

    public struct Entity: Codable {
        public let configurationId: String
        public let schemaVersion: String
        public let bucket: Bucket
        public let object: Object

        enum CodingKeys: String, CodingKey {
            case configurationId
            case schemaVersion = "s3SchemaVersion"
            case bucket
            case object
        }
    }

    public struct Bucket: Codable {
        public let name: String
        public let ownerIdentity: UserIdentity
        public let arn: String
    }

    public struct Object: Codable {
        public let key: String
        /// The object's size in bytes.
        ///
        /// Note: This property is available for all event types except "ObjectRemoved:*"
        public let size: UInt64?
        public let urlDecodedKey: String?
        public let versionId: String?
        public let eTag: String
        public let sequencer: String
    }
}
