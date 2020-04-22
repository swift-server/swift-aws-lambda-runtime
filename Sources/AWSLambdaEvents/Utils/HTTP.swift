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

// MARK: HTTPMethod

public typealias HTTPHeaders = [String: String]
public typealias HTTPMultiValueHeaders = [String: [String]]

public struct HTTPMethod: RawRepresentable, Equatable {
    public var rawValue: String

    public init?(rawValue: String) {
        guard rawValue.isValidHTTPToken else {
            return nil
        }
        self.rawValue = rawValue
    }

    public static var GET: HTTPMethod { HTTPMethod(rawValue: "GET")! }
    public static var POST: HTTPMethod { HTTPMethod(rawValue: "POST")! }
    public static var PUT: HTTPMethod { HTTPMethod(rawValue: "PUT")! }
    public static var PATCH: HTTPMethod { HTTPMethod(rawValue: "PATCH")! }
    public static var DELETE: HTTPMethod { HTTPMethod(rawValue: "DELETE")! }
    public static var OPTIONS: HTTPMethod { HTTPMethod(rawValue: "OPTIONS")! }
    public static var HEAD: HTTPMethod { HTTPMethod(rawValue: "HEAD")! }

    public static func RAW(value: String) -> HTTPMethod? { HTTPMethod(rawValue: value) }
}

extension HTTPMethod: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawMethod = try container.decode(String.self)

        guard let method = HTTPMethod(rawValue: rawMethod) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: #"Method "\#(rawMethod)" does not conform to allowed http method syntax defined in RFC 7230 Section 3.2.6"#
            )
        }

        self = method
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: HTTPResponseStatus

public struct HTTPResponseStatus {
    public let code: UInt
    public let reasonPhrase: String?

    public init(code: UInt, reasonPhrase: String? = nil) {
        self.code = code
        self.reasonPhrase = reasonPhrase
    }

    public static var `continue`: HTTPResponseStatus { HTTPResponseStatus(code: 100) }
    public static var switchingProtocols: HTTPResponseStatus { HTTPResponseStatus(code: 101) }
    public static var processing: HTTPResponseStatus { HTTPResponseStatus(code: 102) }
    public static var earlyHints: HTTPResponseStatus { HTTPResponseStatus(code: 103) }

    public static var ok: HTTPResponseStatus { HTTPResponseStatus(code: 200) }
    public static var created: HTTPResponseStatus { HTTPResponseStatus(code: 201) }
    public static var accepted: HTTPResponseStatus { HTTPResponseStatus(code: 202) }
    public static var nonAuthoritativeInformation: HTTPResponseStatus { HTTPResponseStatus(code: 203) }
    public static var noContent: HTTPResponseStatus { HTTPResponseStatus(code: 204) }
    public static var resetContent: HTTPResponseStatus { HTTPResponseStatus(code: 205) }
    public static var partialContent: HTTPResponseStatus { HTTPResponseStatus(code: 206) }
    public static var multiStatus: HTTPResponseStatus { HTTPResponseStatus(code: 207) }
    public static var alreadyReported: HTTPResponseStatus { HTTPResponseStatus(code: 208) }
    public static var imUsed: HTTPResponseStatus { HTTPResponseStatus(code: 226) }

    public static var multipleChoices: HTTPResponseStatus { HTTPResponseStatus(code: 300) }
    public static var movedPermanently: HTTPResponseStatus { HTTPResponseStatus(code: 301) }
    public static var found: HTTPResponseStatus { HTTPResponseStatus(code: 302) }
    public static var seeOther: HTTPResponseStatus { HTTPResponseStatus(code: 303) }
    public static var notModified: HTTPResponseStatus { HTTPResponseStatus(code: 304) }
    public static var useProxy: HTTPResponseStatus { HTTPResponseStatus(code: 305) }
    public static var temporaryRedirect: HTTPResponseStatus { HTTPResponseStatus(code: 307) }
    public static var permanentRedirect: HTTPResponseStatus { HTTPResponseStatus(code: 308) }

    public static var badRequest: HTTPResponseStatus { HTTPResponseStatus(code: 400) }
    public static var unauthorized: HTTPResponseStatus { HTTPResponseStatus(code: 401) }
    public static var paymentRequired: HTTPResponseStatus { HTTPResponseStatus(code: 402) }
    public static var forbidden: HTTPResponseStatus { HTTPResponseStatus(code: 403) }
    public static var notFound: HTTPResponseStatus { HTTPResponseStatus(code: 404) }
    public static var methodNotAllowed: HTTPResponseStatus { HTTPResponseStatus(code: 405) }
    public static var notAcceptable: HTTPResponseStatus { HTTPResponseStatus(code: 406) }
    public static var proxyAuthenticationRequired: HTTPResponseStatus { HTTPResponseStatus(code: 407) }
    public static var requestTimeout: HTTPResponseStatus { HTTPResponseStatus(code: 408) }
    public static var conflict: HTTPResponseStatus { HTTPResponseStatus(code: 409) }
    public static var gone: HTTPResponseStatus { HTTPResponseStatus(code: 410) }
    public static var lengthRequired: HTTPResponseStatus { HTTPResponseStatus(code: 411) }
    public static var preconditionFailed: HTTPResponseStatus { HTTPResponseStatus(code: 412) }
    public static var payloadTooLarge: HTTPResponseStatus { HTTPResponseStatus(code: 413) }
    public static var uriTooLong: HTTPResponseStatus { HTTPResponseStatus(code: 414) }
    public static var unsupportedMediaType: HTTPResponseStatus { HTTPResponseStatus(code: 415) }
    public static var rangeNotSatisfiable: HTTPResponseStatus { HTTPResponseStatus(code: 416) }
    public static var expectationFailed: HTTPResponseStatus { HTTPResponseStatus(code: 417) }
    public static var imATeapot: HTTPResponseStatus { HTTPResponseStatus(code: 418) }
    public static var misdirectedRequest: HTTPResponseStatus { HTTPResponseStatus(code: 421) }
    public static var unprocessableEntity: HTTPResponseStatus { HTTPResponseStatus(code: 422) }
    public static var locked: HTTPResponseStatus { HTTPResponseStatus(code: 423) }
    public static var failedDependency: HTTPResponseStatus { HTTPResponseStatus(code: 424) }
    public static var upgradeRequired: HTTPResponseStatus { HTTPResponseStatus(code: 426) }
    public static var preconditionRequired: HTTPResponseStatus { HTTPResponseStatus(code: 428) }
    public static var tooManyRequests: HTTPResponseStatus { HTTPResponseStatus(code: 429) }
    public static var requestHeaderFieldsTooLarge: HTTPResponseStatus { HTTPResponseStatus(code: 431) }
    public static var unavailableForLegalReasons: HTTPResponseStatus { HTTPResponseStatus(code: 451) }

    public static var internalServerError: HTTPResponseStatus { HTTPResponseStatus(code: 500) }
    public static var notImplemented: HTTPResponseStatus { HTTPResponseStatus(code: 501) }
    public static var badGateway: HTTPResponseStatus { HTTPResponseStatus(code: 502) }
    public static var serviceUnavailable: HTTPResponseStatus { HTTPResponseStatus(code: 503) }
    public static var gatewayTimeout: HTTPResponseStatus { HTTPResponseStatus(code: 504) }
    public static var httpVersionNotSupported: HTTPResponseStatus { HTTPResponseStatus(code: 505) }
    public static var variantAlsoNegotiates: HTTPResponseStatus { HTTPResponseStatus(code: 506) }
    public static var insufficientStorage: HTTPResponseStatus { HTTPResponseStatus(code: 507) }
    public static var loopDetected: HTTPResponseStatus { HTTPResponseStatus(code: 508) }
    public static var notExtended: HTTPResponseStatus { HTTPResponseStatus(code: 510) }
    public static var networkAuthenticationRequired: HTTPResponseStatus { HTTPResponseStatus(code: 511) }
}

extension HTTPResponseStatus: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.code == rhs.code
    }
}

extension HTTPResponseStatus: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.code = try container.decode(UInt.self)
        self.reasonPhrase = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.code)
    }
}

extension String {
    internal var isValidHTTPToken: Bool {
        self.utf8.allSatisfy { (char) -> Bool in
            switch char {
            case UInt8(ascii: "a") ... UInt8(ascii: "z"),
                 UInt8(ascii: "A") ... UInt8(ascii: "Z"),
                 UInt8(ascii: "0") ... UInt8(ascii: "9"),
                 UInt8(ascii: "!"),
                 UInt8(ascii: "#"),
                 UInt8(ascii: "$"),
                 UInt8(ascii: "%"),
                 UInt8(ascii: "&"),
                 UInt8(ascii: "'"),
                 UInt8(ascii: "*"),
                 UInt8(ascii: "+"),
                 UInt8(ascii: "-"),
                 UInt8(ascii: "."),
                 UInt8(ascii: "^"),
                 UInt8(ascii: "_"),
                 UInt8(ascii: "`"),
                 UInt8(ascii: "|"),
                 UInt8(ascii: "~"):
                return true
            default:
                return false
            }
        }
    }
}
