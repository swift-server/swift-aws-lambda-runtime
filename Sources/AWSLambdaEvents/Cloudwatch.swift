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

public enum Cloudwatch {
    public struct Event<Detail: Decodable>: Decodable {
        public let id: String
        public let detailType: String
        public let source: String
        public let accountId: String

        @ISO8601Coding
        public var time: Date
        public let region: String
        public let resources: [String]
        public let detail: Detail

        enum CodingKeys: String, CodingKey {
            case id
            case detailType = "detail-type"
            case source
            case accountId = "account"
            case time
            case region
            case resources
            case detail
        }
    }

    public struct ScheduledEvent: Codable {}
}
