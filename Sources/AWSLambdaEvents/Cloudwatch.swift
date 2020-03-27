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
    public struct Event: Decodable {
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
            let time = try container.decode(ISO8601Coding.self, forKey: .time)
            self.time = time.wrappedValue
            self.region = try container.decode(AWSRegion.self, forKey: .region)
            self.resources = try container.decode([String].self, forKey: .resources)

            self.detail = try Detail(from: decoder)
        }

        public enum Detail: Decodable {
            case scheduled
            case ec2InstanceStateChangeNotification(EC2.InstanceStateChangeNotification)
            case ec2SpotInstanceInterruptionWarning(EC2.SpotInstanceInterruptionNotice)
            case custom(label: String, detail: Decodable)

            enum CodingKeys: String, CodingKey {
                case detailType = "detail-type"
                case detail
            }

            // FIXME: make thread safe
            static var registry = [String: (Decoder) throws -> Decodable]()
            public static func register<T: Decodable>(label: String, type: T.Type) {
                registry[label] = type.init
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let detailType = try container.decode(String.self, forKey: .detailType)
                switch detailType {
                case "Scheduled Event":
                    self = .scheduled
                case "EC2 Instance State-change Notification":
                    self = .ec2InstanceStateChangeNotification(
                        try container.decode(EC2.InstanceStateChangeNotification.self, forKey: .detail))
                case "EC2 Spot Instance Interruption Warning":
                    self = .ec2SpotInstanceInterruptionWarning(
                        try container.decode(EC2.SpotInstanceInterruptionNotice.self, forKey: .detail))
                default:
                    guard let factory = Detail.registry[detailType] else {
                        throw UnknownPayload()
                    }
                    let detailsDecoder = try container.superDecoder(forKey: .detail)
                    self = .custom(label: detailType, detail: try factory(detailsDecoder))
                }
            }
        }
    }

    public struct CodePipelineStateChange: Decodable {
        let foo: String
    }

    public enum EC2 {
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

    struct UnknownPayload: Error {}
}
