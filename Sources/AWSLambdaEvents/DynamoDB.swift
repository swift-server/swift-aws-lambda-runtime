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

// https://docs.aws.amazon.com/lambda/latest/dg/with-ddb.html
public struct DynamoDBEvent: Decodable {
    public let records: [EventRecord]

    public enum CodingKeys: String, CodingKey {
        case records = "Records"
    }

    public enum KeyType: String, Codable {
        case hash = "HASH"
        case range = "RANGE"
    }

    public enum OperationType: String, Codable {
        case insert = "INSERT"
        case modify = "MODIFY"
        case remove = "REMOVE"
    }

    public enum SharedIteratorType: String, Codable {
        case trimHorizon = "TRIM_HORIZON"
        case latest = "LATEST"
        case atSequenceNumber = "AT_SEQUENCE_NUMBER"
        case afterSequenceNumber = "AFTER_SEQUENCE_NUMBER"
    }

    public enum StreamStatus: String, Codable {
        case enabling = "ENABLING"
        case enabled = "ENABLED"
        case disabling = "DISABLING"
        case disabled = "DISABLED"
    }

    public enum StreamViewType: String, Codable {
        /// the entire item, as it appeared after it was modified.
        case newImage = "NEW_IMAGE"
        /// the entire item, as it appeared before it was modified.
        case oldImage = "OLD_IMAGE"
        /// both the new and the old item images of the item.
        case newAndOldImages = "NEW_AND_OLD_IMAGES"
        /// only the key attributes of the modified item.
        case keysOnly = "KEYS_ONLY"
    }

    public struct EventRecord: Decodable {
        /// The region in which the GetRecords request was received.
        public let awsRegion: AWSRegion

        /// The main body of the stream record, containing all of the DynamoDB-specific
        /// fields.
        public let change: StreamRecord

        /// A globally unique identifier for the event that was recorded in this stream
        /// record.
        public let eventId: String

        /// The type of data modification that was performed on the DynamoDB table:
        ///  * INSERT - a new item was added to the table.
        ///  * MODIFY - one or more of an existing item's attributes were modified.
        ///  * REMOVE - the item was deleted from the table
        public let eventName: OperationType

        /// The AWS service from which the stream record originated. For DynamoDB Streams,
        /// this is aws:dynamodb.
        public let eventSource: String

        /// The version number of the stream record format. This number is updated whenever
        /// the structure of Record is modified.
        ///
        /// Client applications must not assume that eventVersion will remain at a particular
        /// value, as this number is subject to change at any time. In general, eventVersion
        /// will only increase as the low-level DynamoDB Streams API evolves.
        public let eventVersion: String

        /// The event source ARN of DynamoDB
        public let eventSourceArn: String

        /// Items that are deleted by the Time to Live process after expiration have
        /// the following fields:
        ///  * Records[].userIdentity.type
        ///
        /// "Service"
        ///  * Records[].userIdentity.principalId
        ///
        /// "dynamodb.amazonaws.com"
        public let userIdentity: UserIdentity?

        public enum CodingKeys: String, CodingKey {
            case awsRegion
            case change = "dynamodb"
            case eventId = "eventID"
            case eventName
            case eventSource
            case eventVersion
            case eventSourceArn = "eventSourceARN"
            case userIdentity
        }
    }

    public struct StreamRecord {
        /// The approximate date and time when the stream record was created, in UNIX
        /// epoch time (http://www.epochconverter.com/) format.
        public let approximateCreationDateTime: Date?

        /// The primary key attribute(s) for the DynamoDB item that was modified.
        public let keys: [String: AttributeValue]

        /// The item in the DynamoDB table as it appeared after it was modified.
        public let newImage: [String: AttributeValue]?

        /// The item in the DynamoDB table as it appeared before it was modified.
        public let oldImage: [String: AttributeValue]?

        /// The sequence number of the stream record.
        public let sequenceNumber: String

        /// The size of the stream record, in bytes.
        public let sizeBytes: Int64

        /// The type of data from the modified DynamoDB item that was captured in this
        /// stream record.
        public let streamViewType: StreamViewType
    }

    public struct UserIdentity: Codable {
        public let type: String
        public let principalId: String
    }
}

extension DynamoDBEvent.StreamRecord: Decodable {
    enum CodingKeys: String, CodingKey {
        case approximateCreationDateTime = "ApproximateCreationDateTime"
        case keys = "Keys"
        case newImage = "NewImage"
        case oldImage = "OldImage"
        case sequenceNumber = "SequenceNumber"
        case sizeBytes = "SizeBytes"
        case streamViewType = "StreamViewType"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.keys = try container.decode(
            [String: DynamoDBEvent.AttributeValue].self,
            forKey: .keys
        )

        self.newImage = try container.decodeIfPresent(
            [String: DynamoDBEvent.AttributeValue].self,
            forKey: .newImage
        )
        self.oldImage = try container.decodeIfPresent(
            [String: DynamoDBEvent.AttributeValue].self,
            forKey: .oldImage
        )

        self.sequenceNumber = try container.decode(String.self, forKey: .sequenceNumber)
        self.sizeBytes = try container.decode(Int64.self, forKey: .sizeBytes)
        self.streamViewType = try container.decode(DynamoDBEvent.StreamViewType.self, forKey: .streamViewType)

        if let timestamp = try container.decodeIfPresent(Double.self, forKey: .approximateCreationDateTime) {
            self.approximateCreationDateTime = Date(timeIntervalSince1970: timestamp)
        } else {
            self.approximateCreationDateTime = nil
        }
    }
}

// MARK: - AttributeValue -

extension DynamoDBEvent {
    public enum AttributeValue {
        case boolean(Bool)
        case binary([UInt8])
        case binarySet([[UInt8]])
        case string(String)
        case stringSet([String])
        case null
        case number(String)
        case numberSet([String])

        case list([AttributeValue])
        case map([String: AttributeValue])
    }
}

extension DynamoDBEvent.AttributeValue: Decodable {
    enum CodingKeys: String, CodingKey {
        case binary = "B"
        case bool = "BOOL"
        case binarySet = "BS"
        case list = "L"
        case map = "M"
        case number = "N"
        case numberSet = "NS"
        case null = "NULL"
        case string = "S"
        case stringSet = "SS"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            let context = DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Expected exactly one key, but got \(container.allKeys.count)"
            )
            throw DecodingError.dataCorrupted(context)
        }

        switch key {
        case .binary:
            let encoded = try container.decode(String.self, forKey: .binary)
            self = .binary(try encoded.base64decoded())

        case .bool:
            let value = try container.decode(Bool.self, forKey: .bool)
            self = .boolean(value)

        case .binarySet:
            let values = try container.decode([String].self, forKey: .binarySet)
            let buffers = try values.map { try $0.base64decoded() }
            self = .binarySet(buffers)

        case .list:
            let values = try container.decode([DynamoDBEvent.AttributeValue].self, forKey: .list)
            self = .list(values)

        case .map:
            let value = try container.decode([String: DynamoDBEvent.AttributeValue].self, forKey: .map)
            self = .map(value)

        case .number:
            let value = try container.decode(String.self, forKey: .number)
            self = .number(value)

        case .numberSet:
            let values = try container.decode([String].self, forKey: .numberSet)
            self = .numberSet(values)

        case .null:
            self = .null

        case .string:
            let value = try container.decode(String.self, forKey: .string)
            self = .string(value)

        case .stringSet:
            let values = try container.decode([String].self, forKey: .stringSet)
            self = .stringSet(values)
        }
    }
}

extension DynamoDBEvent.AttributeValue: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.boolean(let lhs), .boolean(let rhs)):
            return lhs == rhs
        case (.binary(let lhs), .binary(let rhs)):
            return lhs == rhs
        case (.binarySet(let lhs), .binarySet(let rhs)):
            return lhs == rhs
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.stringSet(let lhs), .stringSet(let rhs)):
            return lhs == rhs
        case (.null, .null):
            return true
        case (.number(let lhs), .number(let rhs)):
            return lhs == rhs
        case (.numberSet(let lhs), .numberSet(let rhs)):
            return lhs == rhs
        case (.list(let lhs), .list(let rhs)):
            return lhs == rhs
        case (.map(let lhs), .map(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

// MARK: DynamoDB AttributeValue Decoding

extension DynamoDBEvent {
    public struct Decoder {
        @usableFromInline var userInfo: [CodingUserInfoKey: Any] = [:]

        public init() {}

        @inlinable public func decode<T: Decodable>(_ type: T.Type, from image: [String: AttributeValue])
            throws -> T {
            try self.decode(type, from: .map(image))
        }

        @inlinable public func decode<T: Decodable>(_ type: T.Type, from value: AttributeValue)
            throws -> T {
            let decoder = _DecoderImpl(userInfo: userInfo, from: value, codingPath: [])
            return try decoder.decode(T.self)
        }
    }

    @usableFromInline internal struct _DecoderImpl: Swift.Decoder {
        @usableFromInline let codingPath: [CodingKey]
        @usableFromInline let userInfo: [CodingUserInfoKey: Any]

        @usableFromInline let value: AttributeValue

        @inlinable init(userInfo: [CodingUserInfoKey: Any], from value: AttributeValue, codingPath: [CodingKey]) {
            self.userInfo = userInfo
            self.codingPath = codingPath
            self.value = value
        }

        @inlinable public func decode<T: Decodable>(_: T.Type) throws -> T {
            try T(from: self)
        }

        @usableFromInline func container<Key>(keyedBy type: Key.Type) throws ->
            KeyedDecodingContainer<Key> where Key: CodingKey {
            guard case .map(let dictionary) = self.value else {
                throw DecodingError.typeMismatch([String: AttributeValue].self, DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Expected to decode \([String: AttributeValue].self) but found \(self.value.debugDataTypeDescription) instead."
                ))
            }

            let container = _KeyedDecodingContainer<Key>(
                impl: self,
                codingPath: self.codingPath,
                dictionary: dictionary
            )
            return KeyedDecodingContainer(container)
        }

        @usableFromInline func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            guard case .list(let array) = self.value else {
                throw DecodingError.typeMismatch([AttributeValue].self, DecodingError.Context(
                    codingPath: self.codingPath,
                    debugDescription: "Expected to decode \([AttributeValue].self) but found \(self.value.debugDataTypeDescription) instead."
                ))
            }

            return _UnkeyedDecodingContainer(
                impl: self,
                codingPath: self.codingPath,
                array: array
            )
        }

        @usableFromInline func singleValueContainer() throws -> SingleValueDecodingContainer {
            _SingleValueDecodingContainter(
                impl: self,
                codingPath: self.codingPath,
                value: self.value
            )
        }
    }

    struct ArrayKey: CodingKey, Equatable {
        init(index: Int) {
            self.intValue = index
        }

        init?(stringValue _: String) {
            preconditionFailure("Did not expect to be initialized with a string")
        }

        init?(intValue: Int) {
            self.intValue = intValue
        }

        var intValue: Int?

        var stringValue: String {
            "Index \(self.intValue!)"
        }

        static func == (lhs: ArrayKey, rhs: ArrayKey) -> Bool {
            precondition(lhs.intValue != nil)
            precondition(rhs.intValue != nil)
            return lhs.intValue == rhs.intValue
        }
    }

    struct _KeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
        typealias Key = K

        let impl: _DecoderImpl
        let codingPath: [CodingKey]
        let dictionary: [String: AttributeValue]

        init(impl: _DecoderImpl, codingPath: [CodingKey], dictionary: [String: AttributeValue]) {
            self.impl = impl
            self.codingPath = codingPath
            self.dictionary = dictionary
        }

        var allKeys: [K] {
            self.dictionary.keys.compactMap { K(stringValue: $0) }
        }

        func contains(_ key: K) -> Bool {
            if let _ = self.dictionary[key.stringValue] {
                return true
            }
            return false
        }

        func decodeNil(forKey key: K) throws -> Bool {
            let value = try getValue(forKey: key)
            return value == .null
        }

        func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
            let value = try getValue(forKey: key)

            guard case .boolean(let bool) = value else {
                throw self.createTypeMismatchError(type: type, forKey: key, value: value)
            }

            return bool
        }

        func decode(_ type: String.Type, forKey key: K) throws -> String {
            let value = try getValue(forKey: key)

            guard case .string(let string) = value else {
                throw self.createTypeMismatchError(type: type, forKey: key, value: value)
            }

            return string
        }

        func decode(_ type: Double.Type, forKey key: K) throws -> Double {
            try self.decodeLosslessStringConvertible(key: key)
        }

        func decode(_ type: Float.Type, forKey key: K) throws -> Float {
            try self.decodeLosslessStringConvertible(key: key)
        }

        func decode(_ type: Int.Type, forKey key: K) throws -> Int {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
            try self.decodeFixedWidthInteger(key: key)
        }

        func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
            let decoder = try self.decoderForKey(key)
            return try T(from: decoder)
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            try self.decoderForKey(key).container(keyedBy: type)
        }

        func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
            try self.decoderForKey(key).unkeyedContainer()
        }

        func superDecoder() throws -> Swift.Decoder {
            self.impl
        }

        func superDecoder(forKey key: K) throws -> Swift.Decoder {
            self.impl
        }

        private func decoderForKey(_ key: K) throws -> _DecoderImpl {
            let value = try getValue(forKey: key)
            var newPath = self.codingPath
            newPath.append(key)

            return _DecoderImpl(
                userInfo: self.impl.userInfo,
                from: value,
                codingPath: newPath
            )
        }

        @inline(__always) private func getValue(forKey key: K) throws -> AttributeValue {
            guard let value = self.dictionary[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(
                    codingPath: self.codingPath,
                    debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
                ))
            }

            return value
        }

        @inline(__always) private func createTypeMismatchError(type: Any.Type, forKey key: K, value: AttributeValue) -> DecodingError {
            let codingPath = self.codingPath + [key]
            return DecodingError.typeMismatch(type, .init(
                codingPath: codingPath, debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
            ))
        }

        @inline(__always) private func decodeFixedWidthInteger<T: FixedWidthInteger>(key: Self.Key)
            throws -> T {
            let value = try getValue(forKey: key)

            guard case .number(let number) = value else {
                throw self.createTypeMismatchError(type: T.self, forKey: key, value: value)
            }

            guard let integer = T(number) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: self,
                    debugDescription: "Parsed JSON number <\(number)> does not fit in \(T.self)."
                )
            }

            return integer
        }

        @inline(__always) private func decodeLosslessStringConvertible<T: LosslessStringConvertible>(
            key: Self.Key) throws -> T {
            let value = try getValue(forKey: key)

            guard case .number(let number) = value else {
                throw self.createTypeMismatchError(type: T.self, forKey: key, value: value)
            }

            guard let floatingPoint = T(number) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: self,
                    debugDescription: "Parsed JSON number <\(number)> does not fit in \(T.self)."
                )
            }

            return floatingPoint
        }
    }

    struct _SingleValueDecodingContainter: SingleValueDecodingContainer {
        let impl: _DecoderImpl
        let value: AttributeValue
        let codingPath: [CodingKey]

        init(impl: _DecoderImpl, codingPath: [CodingKey], value: AttributeValue) {
            self.impl = impl
            self.codingPath = codingPath
            self.value = value
        }

        func decodeNil() -> Bool {
            self.value == .null
        }

        func decode(_: Bool.Type) throws -> Bool {
            guard case .boolean(let bool) = self.value else {
                throw self.createTypeMismatchError(type: Bool.self, value: self.value)
            }

            return bool
        }

        func decode(_: String.Type) throws -> String {
            guard case .string(let string) = self.value else {
                throw self.createTypeMismatchError(type: String.self, value: self.value)
            }

            return string
        }

        func decode(_: Double.Type) throws -> Double {
            try self.decodeLosslessStringConvertible()
        }

        func decode(_: Float.Type) throws -> Float {
            try self.decodeLosslessStringConvertible()
        }

        func decode(_: Int.Type) throws -> Int {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: Int8.Type) throws -> Int8 {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: Int16.Type) throws -> Int16 {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: Int32.Type) throws -> Int32 {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: Int64.Type) throws -> Int64 {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: UInt.Type) throws -> UInt {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: UInt8.Type) throws -> UInt8 {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: UInt16.Type) throws -> UInt16 {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: UInt32.Type) throws -> UInt32 {
            try self.decodeFixedWidthInteger()
        }

        func decode(_: UInt64.Type) throws -> UInt64 {
            try self.decodeFixedWidthInteger()
        }

        func decode<T>(_: T.Type) throws -> T where T: Decodable {
            try T(from: self.impl)
        }

        @inline(__always) private func createTypeMismatchError(type: Any.Type, value: AttributeValue) -> DecodingError {
            DecodingError.typeMismatch(type, .init(
                codingPath: self.codingPath,
                debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
            ))
        }

        @inline(__always) private func decodeFixedWidthInteger<T: FixedWidthInteger>() throws
            -> T {
            guard case .number(let number) = self.value else {
                throw self.createTypeMismatchError(type: T.self, value: self.value)
            }

            guard let integer = T(number) else {
                throw DecodingError.dataCorruptedError(
                    in: self,
                    debugDescription: "Parsed JSON number <\(number)> does not fit in \(T.self)."
                )
            }

            return integer
        }

        @inline(__always) private func decodeLosslessStringConvertible<T: LosslessStringConvertible>()
            throws -> T {
            guard case .number(let number) = self.value else {
                throw self.createTypeMismatchError(type: T.self, value: self.value)
            }

            guard let floatingPoint = T(number) else {
                throw DecodingError.dataCorruptedError(
                    in: self,
                    debugDescription: "Parsed JSON number <\(number)> does not fit in \(T.self)."
                )
            }

            return floatingPoint
        }
    }

    struct _UnkeyedDecodingContainer: UnkeyedDecodingContainer {
        let impl: _DecoderImpl
        let codingPath: [CodingKey]
        let array: [AttributeValue]

        let count: Int? // protocol requirement to be optional
        var isAtEnd = false
        var currentIndex = 0

        init(impl: _DecoderImpl, codingPath: [CodingKey], array: [AttributeValue]) {
            self.impl = impl
            self.codingPath = codingPath
            self.array = array
            self.count = array.count
        }

        mutating func decodeNil() throws -> Bool {
            if self.array[self.currentIndex] == .null {
                defer {
                    currentIndex += 1
                    if currentIndex == count {
                        isAtEnd = true
                    }
                }
                return true
            }

            // The protocol states:
            //   If the value is not null, does not increment currentIndex.
            return false
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            defer {
                currentIndex += 1
                if currentIndex == count {
                    isAtEnd = true
                }
            }

            guard case .boolean(let bool) = self.array[self.currentIndex] else {
                throw self.createTypeMismatchError(type: type, value: self.array[self.currentIndex])
            }

            return bool
        }

        mutating func decode(_ type: String.Type) throws -> String {
            defer {
                currentIndex += 1
                if currentIndex == count {
                    isAtEnd = true
                }
            }

            guard case .string(let string) = self.array[self.currentIndex] else {
                throw self.createTypeMismatchError(type: type, value: self.array[self.currentIndex])
            }

            return string
        }

        mutating func decode(_: Double.Type) throws -> Double {
            try self.decodeLosslessStringConvertible()
        }

        mutating func decode(_: Float.Type) throws -> Float {
            try self.decodeLosslessStringConvertible()
        }

        mutating func decode(_: Int.Type) throws -> Int {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: Int8.Type) throws -> Int8 {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: Int16.Type) throws -> Int16 {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: Int32.Type) throws -> Int32 {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: Int64.Type) throws -> Int64 {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: UInt.Type) throws -> UInt {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: UInt8.Type) throws -> UInt8 {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: UInt16.Type) throws -> UInt16 {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: UInt32.Type) throws -> UInt32 {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode(_: UInt64.Type) throws -> UInt64 {
            try self.decodeFixedWidthInteger()
        }

        mutating func decode<T>(_: T.Type) throws -> T where T: Decodable {
            defer {
                currentIndex += 1
                if currentIndex == count {
                    isAtEnd = true
                }
            }

            let json = self.array[self.currentIndex]
            var newPath = self.codingPath
            newPath.append(ArrayKey(index: self.currentIndex))
            let decoder = _DecoderImpl(userInfo: impl.userInfo, from: json, codingPath: newPath)

            return try T(from: decoder)
        }

        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            try self.impl.container(keyedBy: type)
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            try self.impl.unkeyedContainer()
        }

        mutating func superDecoder() throws -> Swift.Decoder {
            self.impl
        }

        @inline(__always) private func createTypeMismatchError(type: Any.Type, value: AttributeValue) -> DecodingError {
            let codingPath = self.codingPath + [ArrayKey(index: self.currentIndex)]
            return DecodingError.typeMismatch(type, .init(
                codingPath: codingPath, debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
            ))
        }

        @inline(__always) private mutating func decodeFixedWidthInteger<T: FixedWidthInteger>() throws
            -> T {
            defer {
                currentIndex += 1
                if currentIndex == count {
                    isAtEnd = true
                }
            }

            guard case .number(let number) = self.array[self.currentIndex] else {
                throw self.createTypeMismatchError(type: T.self, value: self.array[self.currentIndex])
            }

            guard let integer = T(number) else {
                throw DecodingError.dataCorruptedError(in: self,
                                                       debugDescription: "Parsed JSON number <\(number)> does not fit in \(T.self).")
            }

            return integer
        }

        @inline(__always) private mutating func decodeLosslessStringConvertible<T: LosslessStringConvertible>()
            throws -> T {
            defer {
                currentIndex += 1
                if currentIndex == count {
                    isAtEnd = true
                }
            }

            guard case .number(let number) = self.array[self.currentIndex] else {
                throw self.createTypeMismatchError(type: T.self, value: self.array[self.currentIndex])
            }

            guard let float = T(number) else {
                throw DecodingError.dataCorruptedError(in: self,
                                                       debugDescription: "Parsed JSON number <\(number)> does not fit in \(T.self).")
            }

            return float
        }
    }
}

extension DynamoDBEvent.AttributeValue {
    fileprivate var debugDataTypeDescription: String {
        switch self {
        case .list:
            return "a list"
        case .boolean:
            return "boolean"
        case .number:
            return "a number"
        case .string:
            return "a string"
        case .map:
            return "a map"
        case .null:
            return "null"
        case .binary:
            return "bytes"
        case .binarySet:
            return "a set of bytes"
        case .stringSet:
            return "a set of strings"
        case .numberSet:
            return "a set of numbers"
        }
    }
}
