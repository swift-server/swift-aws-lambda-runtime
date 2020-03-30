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
public enum AWSRegion: String, Codable {
    case ap_northeast_1 = "ap-northeast-1"
    case ap_northeast_2 = "ap-northeast-2"
    case ap_east_1 = "ap-east-1"
    case ap_southeast_1 = "ap-southeast-1"
    case ap_southeast_2 = "ap-southeast-2"
    case ap_south_1 = "ap-south-1"

    case cn_north_1 = "cn-north-1"
    case cn_northwest_1 = "cn-northwest-1"

    case eu_north_1 = "eu-north-1"
    case eu_west_1 = "eu-west-1"
    case eu_west_2 = "eu-west-2"
    case eu_west_3 = "eu-west-3"
    case eu_central_1 = "eu-central-1"

    case us_east_1 = "us-east-1"
    case us_east_2 = "us-east-2"
    case us_west_1 = "us-west-1"
    case us_west_2 = "us-west-2"
    case us_gov_east_1 = "us-gov-east-1"
    case us_gov_west_1 = "us-gov-west-1"

    case ca_central_1 = "ca-central-1"
    case sa_east_1 = "sa-east-1"
    case me_south_1 = "me-south-1"
}
