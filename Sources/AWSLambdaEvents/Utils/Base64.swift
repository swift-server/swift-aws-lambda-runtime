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

//===----------------------------------------------------------------------===//
// This is a vendored version from:
// https://github.com/fabianfett/swift-base64-kit

struct Base64 {}

// MARK: - Decode -

extension Base64 {
    struct DecodingOptions: OptionSet {
        let rawValue: UInt
        init(rawValue: UInt) { self.rawValue = rawValue }

        static let base64UrlAlphabet = DecodingOptions(rawValue: UInt(1 << 0))
    }

    enum DecodingError: Error, Equatable {
        case invalidLength
        case invalidCharacter(UInt8)
        case unexpectedPaddingCharacter
        case unexpectedEnd
    }

    @inlinable
    static func decode<Buffer: Collection>(encoded: Buffer, options: DecodingOptions = [])
        throws -> [UInt8] where Buffer.Element == UInt8 {
        let alphabet = options.contains(.base64UrlAlphabet)
            ? Base64.decodeBase64Url
            : Base64.decodeBase64

        // In Base64 4 encoded bytes, become 3 decoded bytes. We pad to the
        // nearest multiple of three.
        let inputLength = encoded.count
        guard inputLength > 0 else { return [] }
        guard inputLength % 4 == 0 else {
            throw DecodingError.invalidLength
        }

        let inputBlocks = (inputLength + 3) / 4
        let fullQualified = inputBlocks - 1
        let outputLength = ((encoded.count + 3) / 4) * 3
        var iterator = encoded.makeIterator()
        var outputBytes = [UInt8]()
        outputBytes.reserveCapacity(outputLength)

        // fast loop. we don't expect any padding in here.
        for _ in 0 ..< fullQualified {
            let firstValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
            let secondValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
            let thirdValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
            let forthValue: UInt8 = try iterator.nextValue(alphabet: alphabet)

            outputBytes.append((firstValue << 2) | (secondValue >> 4))
            outputBytes.append((secondValue << 4) | (thirdValue >> 2))
            outputBytes.append((thirdValue << 6) | forthValue)
        }

        // last 4 bytes. we expect padding characters in three and four
        let firstValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
        let secondValue: UInt8 = try iterator.nextValue(alphabet: alphabet)
        let thirdValue: UInt8? = try iterator.nextValueOrEmpty(alphabet: alphabet)
        let forthValue: UInt8? = try iterator.nextValueOrEmpty(alphabet: alphabet)

        outputBytes.append((firstValue << 2) | (secondValue >> 4))
        if let thirdValue = thirdValue {
            outputBytes.append((secondValue << 4) | (thirdValue >> 2))

            if let forthValue = forthValue {
                outputBytes.append((thirdValue << 6) | forthValue)
            }
        }

        return outputBytes
    }

    @inlinable
    static func decode(encoded: String, options: DecodingOptions = []) throws -> [UInt8] {
        // A string can be backed by a contiguous storage (pure swift string)
        // or a nsstring (bridged string from objc). We only get a pointer
        // to the contiguous storage, if the input string is a swift string.
        // Therefore to transform the nsstring backed input into a swift
        // string we concat the input with nothing, causing a copy on write
        // into a swift string.
        let decoded = try encoded.utf8.withContiguousStorageIfAvailable { pointer in
            try self.decode(encoded: pointer, options: options)
        }

        if decoded != nil {
            return decoded!
        }

        return try self.decode(encoded: encoded + "", options: options)
    }

    // MARK: Internal

    @usableFromInline
    static let decodeBase64: [UInt8] = [
        //     0    1    2    3    4    5    6    7    8    9
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, //  0
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, //  1
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, //  2
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, //  3
        255, 255, 255, 62, 255, 255, 255, 63, 52, 53, //  4
        54, 55, 56, 57, 58, 59, 60, 61, 255, 255, //  5
        255, 254, 255, 255, 255, 0, 1, 2, 3, 4, //  6
        5, 6, 7, 8, 9, 10, 11, 12, 13, 14, //  7
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, //  8
        25, 255, 255, 255, 255, 255, 255, 26, 27, 28, //  9
        29, 30, 31, 32, 33, 34, 35, 36, 37, 38, // 10
        39, 40, 41, 42, 43, 44, 45, 46, 47, 48, // 11
        49, 50, 51, 255, 255, 255, 255, 255, 255, 255, // 12
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 13
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 14
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 15
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 16
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 17
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 18
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 19
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 20
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 21
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 22
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 23
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 24
        255, 255, 255, 255, 255, // 25
    ]

    @usableFromInline
    static let decodeBase64Url: [UInt8] = [
        //     0    1    2    3    4    5    6    7    8    9
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, //  0
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, //  1
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, //  2
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, //  3
        255, 255, 255, 255, 255, 62, 255, 255, 52, 53, //  4
        54, 55, 56, 57, 58, 59, 60, 61, 255, 255, //  5
        255, 254, 255, 255, 255, 0, 1, 2, 3, 4, //  6
        5, 6, 7, 8, 9, 10, 11, 12, 13, 14, //  7
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, //  8
        25, 255, 255, 255, 255, 63, 255, 26, 27, 28, //  9
        29, 30, 31, 32, 33, 34, 35, 36, 37, 38, // 10
        39, 40, 41, 42, 43, 44, 45, 46, 47, 48, // 11
        49, 50, 51, 255, 255, 255, 255, 255, 255, 255, // 12
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 13
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 14
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 15
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 16
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 17
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 18
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 19
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 20
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 21
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 22
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 23
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, // 24
        255, 255, 255, 255, 255, // 25
    ]

    @usableFromInline
    static let paddingCharacter: UInt8 = 254
}

extension IteratorProtocol where Self.Element == UInt8 {
    mutating func nextValue(alphabet: [UInt8]) throws -> UInt8 {
        let ascii = self.next()!

        let value = alphabet[Int(ascii)]

        if value < 64 {
            return value
        }

        if value == Base64.paddingCharacter {
            throw Base64.DecodingError.unexpectedPaddingCharacter
        }

        throw Base64.DecodingError.invalidCharacter(ascii)
    }

    mutating func nextValueOrEmpty(alphabet: [UInt8]) throws -> UInt8? {
        let ascii = self.next()!

        let value = alphabet[Int(ascii)]

        if value < 64 {
            return value
        }

        if value == Base64.paddingCharacter {
            return nil
        }

        throw Base64.DecodingError.invalidCharacter(ascii)
    }
}

// MARK: - Extensions -

extension String {
    func base64decoded(options: Base64.DecodingOptions = []) throws -> [UInt8] {
        // In Base64, 3 bytes become 4 output characters, and we pad to the nearest multiple
        // of four.
        try Base64.decode(encoded: self, options: options)
    }
}
