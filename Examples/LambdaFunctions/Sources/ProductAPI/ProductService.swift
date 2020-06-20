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
import NIO

public enum APIError: Error {
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
}

extension Date {
    var iso8601: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}

public class ProductService {
    
    let db: DynamoDB
    let tableName: String
    
    public init(db: DynamoDB, tableName: String) {
        self.db = db
        self.tableName = tableName
    }
    
    public func createItem(product: Product) -> EventLoopFuture<DynamoDB.PutItemOutput> {
        
        var product = product
        let date = Date().iso8601
        product.createdAt = date
        product.updatedAt = date
        
        let input = DynamoDB.PutItemInput(
            item: product.dynamoDictionary,
            tableName: tableName
        )
        return db.putItem(input)
    }
    
    public func readItem(key: String) -> EventLoopFuture<DynamoDB.GetItemOutput> {
        let input = DynamoDB.GetItemInput(
            key: [ProductField.sku: DynamoDB.AttributeValue(s: key)],
            tableName: tableName
        )
        return db.getItem(input)
    }
    
    public func updateItem(product: Product) -> EventLoopFuture<DynamoDB.UpdateItemOutput> {
        
        var product = product
        let date = Date().iso8601
        product.updatedAt = date
        
        let input = DynamoDB.UpdateItemInput(
            expressionAttributeNames: [
                "#name": ProductField.name,
                "#description": ProductField.description,
                "#updatedAt": ProductField.updatedAt,
            ],
            expressionAttributeValues: [
                ":name": DynamoDB.AttributeValue(s: product.name),
                ":description": DynamoDB.AttributeValue(s: product.description),
                ":updatedAt": DynamoDB.AttributeValue(s: product.updatedAt),
            ],
            key: [ProductField.sku: DynamoDB.AttributeValue(s: product.sku)],
            returnValues: DynamoDB.ReturnValue.allNew,
            tableName: tableName,
            updateExpression: "SET #name = :name, #description = :description, #updatedAt = :updatedAt"
        )
        return db.updateItem(input)
    }
    
    public func deleteItem(key: String) -> EventLoopFuture<DynamoDB.DeleteItemOutput> {
        let input = DynamoDB.DeleteItemInput(
            key: [ProductField.sku: DynamoDB.AttributeValue(s: key)],
            tableName: tableName
        )
        return db.deleteItem(input)
    }
    
    public func listItems() -> EventLoopFuture<DynamoDB.ScanOutput> {
        let input = DynamoDB.ScanInput(tableName: tableName)
        return db.scan(input)
    }
}
