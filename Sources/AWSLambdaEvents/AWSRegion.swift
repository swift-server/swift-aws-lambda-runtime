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

// list all available regions using aws cli:
//   $ aws ssm get-parameters-by-path --path /aws/service/global-infrastructure/services/lambda/regions --output json

/// Enumeration of the AWS Regions.
public struct AWSRegion: RawRepresentable, Equatable {
    public typealias RawValue = String

    public let rawValue: String

    public init?(rawValue: String) {
        self.rawValue = rawValue
    }

    static var all: [AWSRegion] = [
        AWSRegion.ap_northeast_1,
        AWSRegion.ap_northeast_2,
        AWSRegion.ap_east_1,
        AWSRegion.ap_southeast_1,
        AWSRegion.ap_southeast_2,
        AWSRegion.ap_south_1,
        AWSRegion.cn_north_1,
        AWSRegion.cn_northwest_1,
        AWSRegion.eu_north_1,
        AWSRegion.eu_west_1,
        AWSRegion.eu_west_2,
        AWSRegion.eu_west_3,
        AWSRegion.eu_central_1,
        AWSRegion.us_east_1,
        AWSRegion.us_east_2,
        AWSRegion.us_west_1,
        AWSRegion.us_west_2,
        AWSRegion.us_gov_east_1,
        AWSRegion.us_gov_west_1,
        AWSRegion.ca_central_1,
        AWSRegion.sa_east_1,
        AWSRegion.me_south_1,
    ]

    public static var ap_northeast_1: AWSRegion { return AWSRegion(rawValue: "ap-northeast-1")! }
    public static var ap_northeast_2: AWSRegion { return AWSRegion(rawValue: "ap-northeast-2")! }
    public static var ap_east_1: AWSRegion { return AWSRegion(rawValue: "ap-east-1")! }
    public static var ap_southeast_1: AWSRegion { return AWSRegion(rawValue: "ap-southeast-1")! }
    public static var ap_southeast_2: AWSRegion { return AWSRegion(rawValue: "ap-southeast-2")! }
    public static var ap_south_1: AWSRegion { return AWSRegion(rawValue: "ap-south-1")! }

    public static var cn_north_1: AWSRegion { return AWSRegion(rawValue: "cn-north-1")! }
    public static var cn_northwest_1: AWSRegion { return AWSRegion(rawValue: "cn-northwest-1")! }

    public static var eu_north_1: AWSRegion { return AWSRegion(rawValue: "eu-north-1")! }
    public static var eu_west_1: AWSRegion { return AWSRegion(rawValue: "eu-west-1")! }
    public static var eu_west_2: AWSRegion { return AWSRegion(rawValue: "eu-west-2")! }
    public static var eu_west_3: AWSRegion { return AWSRegion(rawValue: "eu-west-3")! }
    public static var eu_central_1: AWSRegion { return AWSRegion(rawValue: "eu-central-1")! }

    public static var us_east_1: AWSRegion { return AWSRegion(rawValue: "us-east-1")! }
    public static var us_east_2: AWSRegion { return AWSRegion(rawValue: "us-east-2")! }
    public static var us_west_1: AWSRegion { return AWSRegion(rawValue: "us-west-1")! }
    public static var us_west_2: AWSRegion { return AWSRegion(rawValue: "us-west-2")! }
    public static var us_gov_east_1: AWSRegion { return AWSRegion(rawValue: "us-gov-east-1")! }
    public static var us_gov_west_1: AWSRegion { return AWSRegion(rawValue: "us-gov-west-1")! }

    public static var ca_central_1: AWSRegion { return AWSRegion(rawValue: "ca-central-1")! }
    public static var sa_east_1: AWSRegion { return AWSRegion(rawValue: "sa-east-1")! }
    public static var me_south_1: AWSRegion { return AWSRegion(rawValue: "me-south-1")! }
}

extension AWSRegion: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let region = try container.decode(String.self)
        self.init(rawValue: region)!
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
