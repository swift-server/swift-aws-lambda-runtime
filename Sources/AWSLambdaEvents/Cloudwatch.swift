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

/// EventBridge has the same events/notification types as CloudWatch
typealias EventBridge = Cloudwatch

public protocol CloudwatchDetail: Decodable {
    static var name: String { get }
}

public extension CloudwatchDetail {
    var detailType: String {
        Self.name
    }
}

public enum Cloudwatch {
    /// CloudWatch.Event is the outer structure of an event sent via CloudWatch Events.
    ///
    /// **NOTE**: For examples of events that come via CloudWatch Events, see
    /// https://docs.aws.amazon.com/lambda/latest/dg/services-cloudwatchevents.html
    /// https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/EventTypes.html
    /// https://docs.aws.amazon.com/eventbridge/latest/userguide/event-types.html
    public struct Event<Detail: CloudwatchDetail>: Decodable {
        public let id: String
        public let source: String
        public let accountId: String
        public let time: Date
        public let region: AWSRegion
        public let resources: [String]
        public let detail: Detail

        enum CodingKeys: String, CodingKey {
            case id
            case source
            case accountId = "account"
            case time
            case region
            case resources
            case detailType = "detail-type"
            case detail
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.id = try container.decode(String.self, forKey: .id)
            self.source = try container.decode(String.self, forKey: .source)
            self.accountId = try container.decode(String.self, forKey: .accountId)
            self.time = (try container.decode(ISO8601Coding.self, forKey: .time)).wrappedValue
            self.region = try container.decode(AWSRegion.self, forKey: .region)
            self.resources = try container.decode([String].self, forKey: .resources)

            let detailType = try container.decode(String.self, forKey: .detailType)
            guard detailType.lowercased() == Detail.name.lowercased() else {
                throw DetailTypeMismatch(name: detailType, type: Detail.self)
            }

            self.detail = try container.decode(Detail.self, forKey: .detail)
        }
    }

    // MARK: - Common Event Types

    public typealias ScheduledEvent = Event<Scheduled>
    public struct Scheduled: CloudwatchDetail {
        public static let name = "Scheduled Event"
    }

    public enum EC2 {
        public typealias InstanceStateChangeNotificationEvent = Event<InstanceStateChangeNotification>
        public struct InstanceStateChangeNotification: CloudwatchDetail {
            public static let name = "EC2 Instance State-change Notification"

            public enum State: String, Codable {
                case running
                case shuttingDown = "shutting-down"
                case stopped
                case stopping
                case terminated
            }

            public let instanceId: String
            public let state: State

            enum CodingKeys: String, CodingKey {
                case instanceId = "instance-id"
                case state
            }
        }

        public typealias SpotInstanceInterruptionNoticeEvent = Event<SpotInstanceInterruptionNotice>
        public struct SpotInstanceInterruptionNotice: CloudwatchDetail {
            public static let name = "EC2 Spot Instance Interruption Warning"

            public enum Action: String, Codable {
                case hibernate
                case stop
                case terminate
            }

            public let instanceId: String
            public let action: Action

            enum CodingKeys: String, CodingKey {
                case instanceId = "instance-id"
                case action = "instance-action"
            }
        }
    }

    struct DetailTypeMismatch: Error {
        let name: String
        let type: Any
    }
}
