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

/// EventBridge has the same payloads/notification types as CloudWatch
typealias EventBridge = Cloudwatch

public enum Cloudwatch {
    /// CloudWatch.Event is the outer structure of an event sent via CloudWatch Events.
    ///
    /// **NOTE**: For examples of events that come via CloudWatch Events, see
    /// https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/EventTypes.html
    /// https://docs.aws.amazon.com/eventbridge/latest/userguide/event-types.html
    public struct Event<Detail: Decodable>: Decodable {
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
            self.detail = (try DetailCoding(from: decoder)).guts
        }

        private struct DetailCoding {
            public let guts: Detail

            internal enum CodingKeys: String, CodingKey {
                case detailType = "detail-type"
                case detail
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let detailType = try container.decode(String.self, forKey: .detailType)
                let detailFactory: (Decoder) throws -> Decodable
                switch detailType {
                case ScheduledEvent.name:
                    detailFactory = Empty.init
                case EC2.InstanceStateChangeNotificationEvent.name:
                    detailFactory = EC2.InstanceStateChangeNotification.init
                case EC2.SpotInstanceInterruptionNoticeEvent.name:
                    detailFactory = EC2.SpotInstanceInterruptionNotice.init
                default:
                    guard let factory = Cloudwatch.detailPayloadRegistry[detailType] else {
                        throw UnknownPayload(name: detailType)
                    }
                    detailFactory = factory
                }
                let detailsDecoder = try container.superDecoder(forKey: .detail)
                guard let detail = try detailFactory(detailsDecoder) as? Detail else {
                    throw PayloadTypeMismatch(name: detailType, type: Detail.self)
                }
                self.guts = detail
            }
        }
    }

    // MARK: - Detail Payload Registry

    // FIXME: make thread safe
    private static var detailPayloadRegistry = [String: (Decoder) throws -> Decodable]()

    public static func registerDetailPayload<T: Decodable>(label: String, type: T.Type) {
        detailPayloadRegistry[label] = type.init
    }

    // MARK: - Common Event Types

    public typealias ScheduledEvent = Event<Empty>

    public struct Empty: Decodable {}

    public enum EC2 {
        public typealias InstanceStateChangeNotificationEvent = Event<InstanceStateChangeNotification>
        public struct InstanceStateChangeNotification: Decodable {
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
        public struct SpotInstanceInterruptionNotice: Decodable {
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

    struct UnknownPayload: Error {
        let name: String
    }

    struct PayloadTypeMismatch: Error {
        let name: String
        let type: Any
    }
}

extension Cloudwatch.ScheduledEvent {
    static var name: String { "Scheduled Event" }
}

extension Cloudwatch.EC2.InstanceStateChangeNotificationEvent {
    static var name: String { "EC2 Instance State-change Notification" }
}

extension Cloudwatch.EC2.SpotInstanceInterruptionNoticeEvent {
    static var name: String { "EC2 Spot Instance Interruption Warning" }
}
