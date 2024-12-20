//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import Testing

@testable import AWSLambdaRuntimeCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("LambdaRequestID tests")
struct LambdaRequestIDTest {
    @Test
    func testInitFromStringSuccess() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        var buffer = ByteBuffer(string: string)

        let requestID = buffer.readRequestID()
        #expect(buffer.readerIndex == 36)
        #expect(buffer.readableBytes == 0)
        #expect(requestID?.uuidString == UUID(uuidString: string)?.uuidString)
        #expect(requestID?.uppercased == string)
    }

    @Test
    func testInitFromLowercaseStringSuccess() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".lowercased()
        var originalBuffer = ByteBuffer(string: string)

        let requestID = originalBuffer.readRequestID()
        #expect(originalBuffer.readerIndex == 36)
        #expect(originalBuffer.readableBytes == 0)
        #expect(requestID?.uuidString == UUID(uuidString: string)?.uuidString)
        #expect(requestID?.lowercased == string)

        var newBuffer = ByteBuffer()
        originalBuffer.moveReaderIndex(to: 0)
        #expect(throws: Never.self) { try newBuffer.writeRequestID(#require(requestID)) }
        #expect(newBuffer == originalBuffer)
    }

    @Test
    func testInitFromStringMissingCharacterAtEnd() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5"
        var buffer = ByteBuffer(string: string)

        let readableBeforeRead = buffer.readableBytes
        let requestID = buffer.readRequestID()
        #expect(requestID == nil)
        #expect(buffer.readerIndex == 0)
        #expect(buffer.readableBytes == readableBeforeRead)
    }

    @Test
    func testInitFromStringInvalidCharacterAtEnd() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5H"
        var buffer = ByteBuffer(string: string)

        let readableBeforeRead = buffer.readableBytes
        let requestID = buffer.readRequestID()
        #expect(requestID == nil)
        #expect(buffer.readerIndex == 0)
        #expect(buffer.readableBytes == readableBeforeRead)
    }

    @Test(
        "Init from String with invalid separator character",
        arguments: [
            // with _ instead of -
            "E621E1F8-C36C-495A-93FC_0C247A3E6E5F",
            "E621E1F8-C36C-495A_93FC-0C247A3E6E5F",
            "E621E1F8-C36C_495A-93FC-0C247A3E6E5F",
            "E621E1F8_C36C-495A-93FC-0C247A3E6E5F",

            // with 0 instead of -
            "E621E1F8-C36C-495A-93FC00C247A3E6E5F",
            "E621E1F8-C36C-495A093FC-0C247A3E6E5F",
            "E621E1F8-C36C0495A-93FC-0C247A3E6E5F",
            "E621E1F80C36C-495A-93FC-0C247A3E6E5F",
        ]
    )
    func testInitFromStringInvalidSeparatorCharacter(_ input: String) {

        var buffer = ByteBuffer(string: input)

        let readableBeforeRead = buffer.readableBytes
        let requestID = buffer.readRequestID()
        #expect(requestID == nil)
        #expect(buffer.readerIndex == 0)
        #expect(buffer.readableBytes == readableBeforeRead)
    }

    #if os(macOS)
    @Test
    func testInitFromNSStringSuccess() {
        let nsString = NSMutableString(capacity: 16)
        nsString.append("E621E1F8")
        nsString.append("-")
        nsString.append("C36C")
        nsString.append("-")
        nsString.append("495A")
        nsString.append("-")
        nsString.append("93FC")
        nsString.append("-")
        nsString.append("0C247A3E6E5F")

        // TODO: I would love to enforce that the nsstring is not contiguous
        //       here to enforce a special code path. I have no idea how to
        //       achieve this though at the moment
        // XCTAssertFalse((nsString as String).isContiguousUTF8)
        let requestID = LambdaRequestID(uuidString: nsString as String)
        #expect(requestID?.uuidString == LambdaRequestID(uuidString: nsString as String)?.uuidString)
        #expect(requestID?.uppercased == nsString as String)
    }
    #endif

    @Test
    func testUnparse() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        let requestID = LambdaRequestID(uuidString: string)
        #expect(string.lowercased() == requestID?.lowercased)
    }

    @Test
    func testDescription() {
        let requestID = LambdaRequestID()
        let fduuid = UUID(uuid: requestID.uuid)

        #expect(fduuid.description == requestID.description)
        #expect(fduuid.debugDescription == requestID.debugDescription)
    }

    @Test
    func testFoundationInteropFromFoundation() {
        let fduuid = UUID()
        let requestID = LambdaRequestID(uuid: fduuid.uuid)

        #expect(fduuid.uuid.0 == requestID.uuid.0)
        #expect(fduuid.uuid.1 == requestID.uuid.1)
        #expect(fduuid.uuid.2 == requestID.uuid.2)
        #expect(fduuid.uuid.3 == requestID.uuid.3)
        #expect(fduuid.uuid.4 == requestID.uuid.4)
        #expect(fduuid.uuid.5 == requestID.uuid.5)
        #expect(fduuid.uuid.6 == requestID.uuid.6)
        #expect(fduuid.uuid.7 == requestID.uuid.7)
        #expect(fduuid.uuid.8 == requestID.uuid.8)
        #expect(fduuid.uuid.9 == requestID.uuid.9)
        #expect(fduuid.uuid.10 == requestID.uuid.10)
        #expect(fduuid.uuid.11 == requestID.uuid.11)
        #expect(fduuid.uuid.12 == requestID.uuid.12)
        #expect(fduuid.uuid.13 == requestID.uuid.13)
        #expect(fduuid.uuid.14 == requestID.uuid.14)
        #expect(fduuid.uuid.15 == requestID.uuid.15)
    }

    @Test
    func testFoundationInteropToFoundation() {
        let requestID = LambdaRequestID()
        let fduuid = UUID(uuid: requestID.uuid)

        #expect(fduuid.uuid.0 == requestID.uuid.0)
        #expect(fduuid.uuid.1 == requestID.uuid.1)
        #expect(fduuid.uuid.2 == requestID.uuid.2)
        #expect(fduuid.uuid.3 == requestID.uuid.3)
        #expect(fduuid.uuid.4 == requestID.uuid.4)
        #expect(fduuid.uuid.5 == requestID.uuid.5)
        #expect(fduuid.uuid.6 == requestID.uuid.6)
        #expect(fduuid.uuid.7 == requestID.uuid.7)
        #expect(fduuid.uuid.8 == requestID.uuid.8)
        #expect(fduuid.uuid.9 == requestID.uuid.9)
        #expect(fduuid.uuid.10 == requestID.uuid.10)
        #expect(fduuid.uuid.11 == requestID.uuid.11)
        #expect(fduuid.uuid.12 == requestID.uuid.12)
        #expect(fduuid.uuid.13 == requestID.uuid.13)
        #expect(fduuid.uuid.14 == requestID.uuid.14)
        #expect(fduuid.uuid.15 == requestID.uuid.15)
    }

    @Test
    func testHashing() {
        let requestID = LambdaRequestID()
        let fduuid = UUID(uuid: requestID.uuid)
        #expect(fduuid.hashValue == requestID.hashValue)

        var _uuid = requestID.uuid
        _uuid.0 = _uuid.0 > 0 ? _uuid.0 - 1 : 1
        #expect(UUID(uuid: _uuid).hashValue != requestID.hashValue)
    }

    @Test
    func testEncoding() throws {
        struct Test: Codable {
            let requestID: LambdaRequestID
        }
        let requestID = LambdaRequestID()
        let test = Test(requestID: requestID)

        var data: Data?
        #expect(throws: Never.self) { data = try JSONEncoder().encode(test) }
        #expect(
            try String(decoding: #require(data), as: Unicode.UTF8.self) == #"{"requestID":"\#(requestID.uuidString)"}"#
        )
    }

    @Test
    func testDecodingSuccess() {
        struct Test: Codable {
            let requestID: LambdaRequestID
        }
        let requestID = LambdaRequestID()
        let data = #"{"requestID":"\#(requestID.uuidString)"}"#.data(using: .utf8)

        var result: Test?
        #expect(throws: Never.self) { result = try JSONDecoder().decode(Test.self, from: #require(data)) }
        #expect(result?.requestID == requestID)
    }

    @Test
    func testDecodingFailure() {
        struct Test: Codable {
            let requestID: LambdaRequestID
        }
        let requestID = LambdaRequestID()
        var requestIDString = requestID.uuidString
        _ = requestIDString.removeLast()
        let data = #"{"requestID":"\#(requestIDString)"}"#.data(using: .utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Test.self, from: #require(data))
        }
    }

    @Test
    func testStructSize() {
        #expect(MemoryLayout<LambdaRequestID>.size == 16)
    }
}
