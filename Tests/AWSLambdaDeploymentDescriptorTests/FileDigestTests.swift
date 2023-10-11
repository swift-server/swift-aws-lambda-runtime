// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import XCTest
import CryptoKit
@testable import AWSLambdaDeploymentDescriptor

final class FileDigestTests: XCTestCase {


    func testFileDigest() throws {
        
        let expected = "4a5d82d7a7a76a1487fb12ae7f1c803208b6b5e1cfb9ae14afdc0916301e3415"
        let tempDir = FileManager.default.temporaryDirectory.path
        let tempFile = "\(tempDir)/temp.txt"
        let data = "Hello Digest World".data(using: .utf8)
        FileManager.default.createFile(atPath: tempFile, contents: data)
        defer {
            try? FileManager.default.removeItem(atPath: tempFile)
        }
        
        if let result = FileDigest.hex(from: tempFile) {
            XCTAssertEqual(result, expected)
        } else {
            XCTFail("digest is nil")
        }
    }

}
