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

extension Product {
    
    public var dynamoDictionary: [String: DynamoDB.AttributeValue] {
        var dictionary = [
            Field.sku: DynamoDB.AttributeValue(s: sku),
            Field.name: DynamoDB.AttributeValue(s: name),
            Field.description: DynamoDB.AttributeValue(s: description),
        ]
        if let createdAt = createdAt {
            dictionary[Field.createdAt] = DynamoDB.AttributeValue(s: createdAt)
        }
        
        if let updatedAt = updatedAt {
            dictionary[Field.updatedAt] = DynamoDB.AttributeValue(s: updatedAt)
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
        self.createdAt = dictionary[Field.createdAt]?.s
        self.updatedAt = dictionary[Field.updatedAt]?.s
    }
}
