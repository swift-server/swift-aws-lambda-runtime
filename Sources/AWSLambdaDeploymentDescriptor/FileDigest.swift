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

import Foundation
import CryptoKit

class FileDigest {
    
    public static func hex(from filePath: String?) -> String? {
        guard let fp = filePath else {
            return nil
        }
        
        return try? FileDigest().update(path: fp).finalize()
    }
    
    enum InputStreamError: Error {
        case createFailed(String)
        case readFailed
    }
    
    private var digest = SHA256()
    
    func update(path: String) throws -> FileDigest  {
        guard let inputStream = InputStream(fileAtPath: path) else {
            throw InputStreamError.createFailed(path)
        }
        return try update(inputStream: inputStream)
    }
    
    private func update(inputStream: InputStream) throws -> FileDigest {
        inputStream.open()
        defer {
            inputStream.close()
        }
        
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        var bytesRead = inputStream.read(buffer, maxLength: bufferSize)
        while bytesRead > 0 {
            self.update(bytes: buffer, length: bytesRead)
            bytesRead = inputStream.read(buffer, maxLength: bufferSize)
        }
        if bytesRead < 0 {
            // Stream error occured
            throw (inputStream.streamError ?? InputStreamError.readFailed)
        }
        return self
    }
    
    private func update(bytes: UnsafeMutablePointer<UInt8>, length: Int) {
        let data = Data(bytes: bytes, count: length)
        digest.update(data: data)
    }
    
    func finalize() -> String {
        let digest = digest.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
}
