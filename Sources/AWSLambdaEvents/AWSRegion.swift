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
        Self.ap_northeast_1,
        Self.ap_northeast_2,
        Self.ap_east_1,
        Self.ap_southeast_1,
        Self.ap_southeast_2,
        Self.ap_south_1,
        Self.cn_north_1,
        Self.cn_northwest_1,
        Self.eu_north_1,
        Self.eu_west_1,
        Self.eu_west_2,
        Self.eu_west_3,
        Self.eu_central_1,
        Self.us_east_1,
        Self.us_east_2,
        Self.us_west_1,
        Self.us_west_2,
        Self.us_gov_east_1,
        Self.us_gov_west_1,
        Self.ca_central_1,
        Self.sa_east_1,
        Self.me_south_1,
    ]

    public static var ap_northeast_1: Self { AWSRegion(rawValue: "ap-northeast-1")! }
    public static var ap_northeast_2: Self { AWSRegion(rawValue: "ap-northeast-2")! }
    public static var ap_east_1: Self { AWSRegion(rawValue: "ap-east-1")! }
    public static var ap_southeast_1: Self { AWSRegion(rawValue: "ap-southeast-1")! }
    public static var ap_southeast_2: Self { AWSRegion(rawValue: "ap-southeast-2")! }
    public static var ap_south_1: Self { AWSRegion(rawValue: "ap-south-1")! }

    public static var cn_north_1: Self { AWSRegion(rawValue: "cn-north-1")! }
    public static var cn_northwest_1: Self { AWSRegion(rawValue: "cn-northwest-1")! }

    public static var eu_north_1: Self { AWSRegion(rawValue: "eu-north-1")! }
    public static var eu_west_1: Self { AWSRegion(rawValue: "eu-west-1")! }
    public static var eu_west_2: Self { AWSRegion(rawValue: "eu-west-2")! }
    public static var eu_west_3: Self { AWSRegion(rawValue: "eu-west-3")! }
    public static var eu_central_1: Self { AWSRegion(rawValue: "eu-central-1")! }

    public static var us_east_1: Self { AWSRegion(rawValue: "us-east-1")! }
    public static var us_east_2: Self { AWSRegion(rawValue: "us-east-2")! }
    public static var us_west_1: Self { AWSRegion(rawValue: "us-west-1")! }
    public static var us_west_2: Self { AWSRegion(rawValue: "us-west-2")! }
    public static var us_gov_east_1: Self { AWSRegion(rawValue: "us-gov-east-1")! }
    public static var us_gov_west_1: Self { AWSRegion(rawValue: "us-gov-west-1")! }

    public static var ca_central_1: Self { AWSRegion(rawValue: "ca-central-1")! }
    public static var sa_east_1: Self { AWSRegion(rawValue: "sa-east-1")! }
    public static var me_south_1: Self { AWSRegion(rawValue: "me-south-1")! }
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
