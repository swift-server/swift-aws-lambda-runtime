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
import AWSDynamoDB

public struct ProductField {
    static let sku = "sku"
    static let name = "name"
    static let description = "description"
    static let createdAt = "createdAt"
    static let updatedAt = "updatedAt"
}

public extension Product {
    var dynamoDictionary: [String : DynamoDB.AttributeValue] {
        var dictionary = [ProductField.sku: DynamoDB.AttributeValue(s:sku),
                          ProductField.name: DynamoDB.AttributeValue(s:name),
                          ProductField.description: DynamoDB.AttributeValue(s:description)]
        if let createdAt = createdAt {
            dictionary[ProductField.createdAt] = DynamoDB.AttributeValue(s:createdAt)
        }
        
        if let updatedAt = updatedAt {
            dictionary[ProductField.updatedAt] = DynamoDB.AttributeValue(s:updatedAt)
        }
        return dictionary
    }
    
    init(dictionary: [String: DynamoDB.AttributeValue]) throws {
        guard let name = dictionary[ProductField.name]?.s,
            let sku = dictionary[ProductField.sku]?.s,
            let description = dictionary[ProductField.description]?.s else {
                throw APIError.invalidItem
        }
        self.name = name
        self.sku = sku
        self.description = description
        self.createdAt = dictionary[ProductField.createdAt]?.s
        self.updatedAt = dictionary[ProductField.updatedAt]?.s
    }
}
