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

import AWSDynamoDB
import Foundation

extension Product {
    
    public var dynamoDictionary: [String: DynamoDB.AttributeValue] {
        var dictionary = [
            Field.sku: DynamoDB.AttributeValue(s: sku),
            Field.name: DynamoDB.AttributeValue(s: name),
            Field.description: DynamoDB.AttributeValue(s: description),
        ]
        if let createdAt = createdAt?.timeIntervalSince1970String {
            dictionary[Field.createdAt] = DynamoDB.AttributeValue(n: createdAt)
        }
        
        if let updatedAt = updatedAt?.timeIntervalSince1970String {
            dictionary[Field.updatedAt] = DynamoDB.AttributeValue(n: updatedAt)
        }
        return dictionary
    }
    
    public init(dictionary: [String: DynamoDB.AttributeValue]) throws {
        guard let name = dictionary[Field.name]?.s,
            let sku = dictionary[Field.sku]?.s,
            let description = dictionary[Field.description]?.s
            else {
                throw APIError.invalidItem
        }
        self.name = name
        self.sku = sku
        self.description = description
        if let value = dictionary[Field.createdAt]?.n,
            let timeInterval = TimeInterval(value) {
            let date = Date(timeIntervalSince1970: timeInterval)
            self.createdAt = date.iso8601
        }
        if let value = dictionary[Field.updatedAt]?.n,
            let timeInterval = TimeInterval(value) {
            let date = Date(timeIntervalSince1970: timeInterval)
            self.updatedAt = date.iso8601
        }
    }
}
