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

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import struct Foundation.Date
import class Foundation.DateFormatter
import class Foundation.ISO8601DateFormatter
import struct Foundation.Locale

@propertyWrapper
public struct ISO8601Coding: Decodable {
    public let wrappedValue: Date

    public init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        guard let date = Self.decodeDate(from: dateString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription:
                "Expected date to be in ISO8601 date format, but `\(dateString)` is not in the correct format")
        }
        self.wrappedValue = date
    }

    private static func decodeDate(from string: String) -> Date? {
        #if os(Linux)
        return Self.dateFormatter.date(from: string)
        #elseif os(macOS)
        if #available(macOS 10.12, *) {
            return Self.dateFormatter.date(from: string)
        } else {
            return self.decodeISO8601Date(from: string).flatMap(Date.init(timeIntervalSince1970:))
        }
        #endif
    }

    @available(macOS 10.12, *)
    private static let dateFormatter = ISO8601DateFormatter()

    // strptime not avail on through Glibc
    #if os(macOS)
    // 1970-01-01T00:00:00Z
    internal static func decodeISO8601Date(from string: String) -> Double? {
        if string.last != "Z" {
            return nil
        }
        var parsedTime = tm()
        _ = string.withCString { cstr in
            strptime(cstr, "%Y-%m-%dT%H:%M:%S", &parsedTime)
        }
        let time = timegm(&parsedTime)
        if time == -1 {
            return nil
        }
        return Double(time)
    }
    #endif
}

@propertyWrapper
public struct ISO8601WithFractionalSecondsCoding: Decodable {
    public let wrappedValue: Date

    public init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        guard let date = Self.decodeDate(from: dateString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription:
                "Expected date to be in ISO8601 date format with fractional seconds, but `\(dateString)` is not in the correct format")
        }
        self.wrappedValue = date
    }

    private static func decodeDate(from string: String) -> Date? {
        #if os(Linux)
        return Self.dateFormatter.date(from: string)
        #elseif os(macOS)
        if #available(macOS 10.13, *) {
            return self.dateFormatter.date(from: string)
        } else {
            return self.decodeISO8601Date(from: string).flatMap(Date.init(timeIntervalSince1970:))
        }
        #endif
    }

    @available(macOS 10.13, *)
    private static let dateFormatter: ISO8601DateFormatter = Self.createDateFormatter()

    @available(macOS 10.13, *)
    private static func createDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone,
            .withFractionalSeconds,
        ]
        return formatter
    }

    // strptime not avail on through Glibc
    #if os(macOS)
    // 1970-01-01T00:00:00.00Z
    internal static func decodeISO8601Date(from string: String) -> Double? {
        guard let msIndex = string.lastIndex(of: ".") else {
            return nil
        }
        guard let endIndex = string.lastIndex(of: "Z") else {
            return nil
        }
        if endIndex <= msIndex {
            return nil
        }
        let msString = string[msIndex ..< endIndex]
        guard let ms = Double(msString) else {
            return nil
        }

        return ISO8601Coding.decodeISO8601Date(from: string)?.advanced(by: ms)
    }
    #endif
}

@propertyWrapper
public struct RFC5322DateTimeCoding: Decodable {
    public let wrappedValue: Date

    public init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var string = try container.decode(String.self)
        // RFC5322 dates sometimes have the alphabetic version of the timezone in brackets after the numeric version. The date formatter
        // fails to parse this so we need to remove this before parsing.
        if let bracket = string.firstIndex(of: "(") {
            string = String(string[string.startIndex ..< bracket].trimmingCharacters(in: .whitespaces))
        }
        guard let date = Self.dateFormatter.date(from: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription:
                "Expected date to be in RFC5322 date-time format with fractional seconds, but `\(string)` is not in the correct format")
        }
        self.wrappedValue = date
    }

    private static let dateFormatter: DateFormatter = Self.createDateFormatter()
    private static func createDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM yyy HH:mm:ss z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
