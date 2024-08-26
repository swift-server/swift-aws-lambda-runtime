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

@testable import AWSLambdaRuntimeCore
import NIOCore
import XCTest

final class LambdaRequestIDTest: XCTestCase {
    func testInitFromStringSuccess() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        var buffer = ByteBuffer(string: string)

        let requestID = buffer.readRequestID()
        XCTAssertEqual(buffer.readerIndex, 36)
        XCTAssertEqual(buffer.readableBytes, 0)
        XCTAssertEqual(requestID?.uuidString, UUID(uuidString: string)?.uuidString)
        XCTAssertEqual(requestID?.uppercased, string)
    }

    func testInitFromLowercaseStringSuccess() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".lowercased()
        var originalBuffer = ByteBuffer(string: string)

        let requestID = originalBuffer.readRequestID()
        XCTAssertEqual(originalBuffer.readerIndex, 36)
        XCTAssertEqual(originalBuffer.readableBytes, 0)
        XCTAssertEqual(requestID?.uuidString, UUID(uuidString: string)?.uuidString)
        XCTAssertEqual(requestID?.lowercased, string)

        var newBuffer = ByteBuffer()
        originalBuffer.moveReaderIndex(to: 0)
        XCTAssertNoThrow(try newBuffer.writeRequestID(XCTUnwrap(requestID)))
        XCTAssertEqual(newBuffer, originalBuffer)
    }

    func testInitFromStringMissingCharacterAtEnd() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5"
        var buffer = ByteBuffer(string: string)

        let readableBeforeRead = buffer.readableBytes
        let requestID = buffer.readRequestID()
        XCTAssertNil(requestID)
        XCTAssertEqual(buffer.readerIndex, 0)
        XCTAssertEqual(buffer.readableBytes, readableBeforeRead)
    }

    func testInitFromStringInvalidCharacterAtEnd() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5H"
        var buffer = ByteBuffer(string: string)

        let readableBeforeRead = buffer.readableBytes
        let requestID = buffer.readRequestID()
        XCTAssertNil(requestID)
        XCTAssertEqual(buffer.readerIndex, 0)
        XCTAssertEqual(buffer.readableBytes, readableBeforeRead)
    }

    func testInitFromStringInvalidSeparatorCharacter() {
        let invalid = [
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

        for string in invalid {
            var buffer = ByteBuffer(string: string)

            let readableBeforeRead = buffer.readableBytes
            let requestID = buffer.readRequestID()
            XCTAssertNil(requestID)
            XCTAssertEqual(buffer.readerIndex, 0)
            XCTAssertEqual(buffer.readableBytes, readableBeforeRead)
        }
    }

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
        XCTAssertEqual(requestID?.uuidString, LambdaRequestID(uuidString: nsString as String)?.uuidString)
        XCTAssertEqual(requestID?.uppercased, nsString as String)
    }

    func testUnparse() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        let requestID = LambdaRequestID(uuidString: string)
        XCTAssertEqual(string.lowercased(), requestID?.lowercased)
    }

    func testDescription() {
        let requestID = LambdaRequestID()
        let fduuid = UUID(uuid: requestID.uuid)

        XCTAssertEqual(fduuid.description, requestID.description)
        XCTAssertEqual(fduuid.debugDescription, requestID.debugDescription)
    }

    func testFoundationInteropFromFoundation() {
        let fduuid = UUID()
        let requestID = LambdaRequestID(uuid: fduuid.uuid)

        XCTAssertEqual(fduuid.uuid.0, requestID.uuid.0)
        XCTAssertEqual(fduuid.uuid.1, requestID.uuid.1)
        XCTAssertEqual(fduuid.uuid.2, requestID.uuid.2)
        XCTAssertEqual(fduuid.uuid.3, requestID.uuid.3)
        XCTAssertEqual(fduuid.uuid.4, requestID.uuid.4)
        XCTAssertEqual(fduuid.uuid.5, requestID.uuid.5)
        XCTAssertEqual(fduuid.uuid.6, requestID.uuid.6)
        XCTAssertEqual(fduuid.uuid.7, requestID.uuid.7)
        XCTAssertEqual(fduuid.uuid.8, requestID.uuid.8)
        XCTAssertEqual(fduuid.uuid.9, requestID.uuid.9)
        XCTAssertEqual(fduuid.uuid.10, requestID.uuid.10)
        XCTAssertEqual(fduuid.uuid.11, requestID.uuid.11)
        XCTAssertEqual(fduuid.uuid.12, requestID.uuid.12)
        XCTAssertEqual(fduuid.uuid.13, requestID.uuid.13)
        XCTAssertEqual(fduuid.uuid.14, requestID.uuid.14)
        XCTAssertEqual(fduuid.uuid.15, requestID.uuid.15)
    }

    func testFoundationInteropToFoundation() {
        let requestID = LambdaRequestID()
        let fduuid = UUID(uuid: requestID.uuid)

        XCTAssertEqual(fduuid.uuid.0, requestID.uuid.0)
        XCTAssertEqual(fduuid.uuid.1, requestID.uuid.1)
        XCTAssertEqual(fduuid.uuid.2, requestID.uuid.2)
        XCTAssertEqual(fduuid.uuid.3, requestID.uuid.3)
        XCTAssertEqual(fduuid.uuid.4, requestID.uuid.4)
        XCTAssertEqual(fduuid.uuid.5, requestID.uuid.5)
        XCTAssertEqual(fduuid.uuid.6, requestID.uuid.6)
        XCTAssertEqual(fduuid.uuid.7, requestID.uuid.7)
        XCTAssertEqual(fduuid.uuid.8, requestID.uuid.8)
        XCTAssertEqual(fduuid.uuid.9, requestID.uuid.9)
        XCTAssertEqual(fduuid.uuid.10, requestID.uuid.10)
        XCTAssertEqual(fduuid.uuid.11, requestID.uuid.11)
        XCTAssertEqual(fduuid.uuid.12, requestID.uuid.12)
        XCTAssertEqual(fduuid.uuid.13, requestID.uuid.13)
        XCTAssertEqual(fduuid.uuid.14, requestID.uuid.14)
        XCTAssertEqual(fduuid.uuid.15, requestID.uuid.15)
    }

    func testHashing() {
        let requestID = LambdaRequestID()
        let fduuid = UUID(uuid: requestID.uuid)
        XCTAssertEqual(fduuid.hashValue, requestID.hashValue)

        var _uuid = requestID.uuid
        _uuid.0 = _uuid.0 > 0 ? _uuid.0 - 1 : 1
        XCTAssertNotEqual(UUID(uuid: _uuid).hashValue, requestID.hashValue)
    }

    func testEncoding() {
        struct Test: Codable {
            let requestID: LambdaRequestID
        }
        let requestID = LambdaRequestID()
        let test = Test(requestID: requestID)

        var data: Data?
        XCTAssertNoThrow(data = try JSONEncoder().encode(test))
        XCTAssertEqual(try String(decoding: XCTUnwrap(data), as: Unicode.UTF8.self), #"{"requestID":"\#(requestID.uuidString)"}"#)
    }

    func testDecodingSuccess() {
        struct Test: Codable {
            let requestID: LambdaRequestID
        }
        let requestID = LambdaRequestID()
        let data = #"{"requestID":"\#(requestID.uuidString)"}"#.data(using: .utf8)

        var result: Test?
        XCTAssertNoThrow(result = try JSONDecoder().decode(Test.self, from: XCTUnwrap(data)))
        XCTAssertEqual(result?.requestID, requestID)
    }

    func testDecodingFailure() {
        struct Test: Codable {
            let requestID: LambdaRequestID
        }
        let requestID = LambdaRequestID()
        var requestIDString = requestID.uuidString
        _ = requestIDString.removeLast()
        let data = #"{"requestID":"\#(requestIDString)"}"#.data(using: .utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(Test.self, from: XCTUnwrap(data))) { error in
            XCTAssertNotNil(error as? DecodingError)
        }
    }

    func testStructSize() {
        XCTAssertEqual(MemoryLayout<LambdaRequestID>.size, 16)
    }
}
