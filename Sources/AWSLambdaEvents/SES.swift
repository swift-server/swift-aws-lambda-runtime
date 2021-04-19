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

// https://docs.aws.amazon.com/lambda/latest/dg/services-ses.html

public struct SESEvent: Decodable {
    public struct Record: Decodable {
        public let eventSource: String
        public let eventVersion: String
        public let ses: Message
    }

    public let records: [Record]

    public enum CodingKeys: String, CodingKey {
        case records = "Records"
    }

    public struct Message: Decodable {
        public let mail: Mail
        public let receipt: Receipt
    }

    public struct Mail: Decodable {
        public let commonHeaders: CommonHeaders
        public let destination: [String]
        public let headers: [Header]
        public let headersTruncated: Bool
        public let messageId: String
        public let source: String
        @ISO8601WithFractionalSecondsCoding public var timestamp: Date
    }

    public struct CommonHeaders: Decodable {
        public let bcc: [String]?
        public let cc: [String]?
        @RFC5322DateTimeCoding public var date: Date
        public let from: [String]
        public let messageId: String
        public let returnPath: String?
        public let subject: String?
        public let to: [String]?
    }

    public struct Header: Decodable {
        public let name: String
        public let value: String
    }

    public struct Receipt: Decodable {
        public let action: Action
        public let dmarcPolicy: DMARCPolicy?
        public let dmarcVerdict: Verdict?
        public let dkimVerdict: Verdict
        public let processingTimeMillis: Int
        public let recipients: [String]
        public let spamVerdict: Verdict
        public let spfVerdict: Verdict
        @ISO8601WithFractionalSecondsCoding public var timestamp: Date
        public let virusVerdict: Verdict
    }

    public struct Action: Decodable {
        public let functionArn: String
        public let invocationType: String
        public let type: String
    }

    public struct Verdict: Decodable {
        public let status: Status
    }

    public enum DMARCPolicy: String, Decodable {
        case none
        case quarantine
        case reject
    }

    public enum Status: String, Decodable {
        case pass = "PASS"
        case fail = "FAIL"
        case gray = "GRAY"
        case processingFailed = "PROCESSING_FAILED"
    }
}
