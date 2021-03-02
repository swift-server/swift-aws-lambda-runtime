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

// https://docs.aws.amazon.com/appsync/latest/devguide/resolver-context-reference.html
public enum AppSync {
    public struct Event: Decodable {
        public let arguments: [String: ArgumentValue]

        public enum ArgumentValue: Codable {
            case string(String)
            case dictionary([String: String])

            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let strValue = try? container.decode(String.self) {
                    self = .string(strValue)
                } else if let dictionaryValue = try? container.decode([String: String].self) {
                    self = .dictionary(dictionaryValue)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: """
                    Unexpected AppSync argument.
                    Expected a String or a Dictionary.
                    """)
                }
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .dictionary(let array):
                    try container.encode(array)
                case .string(let str):
                    try container.encode(str)
                }
            }
        }

        public let request: Request
        public struct Request: Decodable {
            let headers: HTTPHeaders
        }

        public let source: [String: String]?
        public let stash: [String: String]?

        public let info: Info
        public struct Info: Codable {
            public var selectionSetList: [String]
            public var selectionSetGraphQL: String
            public var parentTypeName: String
            public var fieldName: String
            public var variables: [String: String]
        }

        public let identity: Identity?
        public enum Identity: Codable {
            case iam(IAMIdentity)
            case cognitoUserPools(CognitoUserPoolIdentity)

            public struct IAMIdentity: Codable {
                public let accountId: String
                public let cognitoIdentityPoolId: String
                public let cognitoIdentityId: String
                public let sourceIp: [String]
                public let username: String?
                public let userArn: String
                public let cognitoIdentityAuthType: String
                public let cognitoIdentityAuthProvider: String
            }

            public struct CognitoUserPoolIdentity: Codable {
                public let defaultAuthStrategy: String
                public let issuer: String
                public let sourceIp: [String]
                public let sub: String
                public let username: String?

                public struct Claims {
                    let sub: String
                    let emailVerified: Bool
                    let iss: String
                    let phoneNumberVerified: Bool
                    let cognitoUsername: String
                    let aud: String
                    let eventId: String
                    let tokenUse: String
                    let authTime: Int
                    let phoneNumber: String?
                    let exp: Int
                    let iat: Int
                    let email: String?

                    enum CodingKeys: String, CodingKey {
                        case sub
                        case emailVerified = "email_verified"
                        case iss
                        case phoneNumberVerified = "phone_number_verified"
                        case cognitoUsername = "cognito:username"
                        case aud
                        case eventId = "event_id"
                        case tokenUse = "token_use"
                        case authTime = "auth_time"
                        case phoneNumber = "phone_number"
                        case exp
                        case iat
                        case email
                    }
                }
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let iamIdentity = try? container.decode(IAMIdentity.self) {
                    self = .iam(iamIdentity)
                } else if let cognitoIdentity = try? container.decode(CognitoUserPoolIdentity.self) {
                    self = .cognitoUserPools(cognitoIdentity)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: """
                    Unexpected Identity argument.
                    Expected a IAM Identity or a Cognito User Pool Identity.
                    """)
                }
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .iam(let iamIdentity):
                    try container.encode(iamIdentity)
                case .cognitoUserPools(let cognitoUserPool):
                    try container.encode(cognitoUserPool)
                }
            }
        }
    }
}

public extension AppSync {
    enum Response<ResultType: Encodable>: Encodable {
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .array(let array):
                try container.encode(array)
            case .object(let object):
                try container.encode(object)
            case .dictionary(let dictionary):
                try container.encode(dictionary)
            }
        }

        case object(ResultType)
        case array([ResultType])
        case dictionary([String: ResultType])
    }

    typealias JSONStringResponse = Response<String>
}
