//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

public struct Product: Codable {
    public let sku: String
    public let name: String
    public let description: String
    public var createdAt: String?
    public var updatedAt: String?
    
    public struct Field {
        static let sku = "sku"
        static let name = "name"
        static let description = "description"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }
}
