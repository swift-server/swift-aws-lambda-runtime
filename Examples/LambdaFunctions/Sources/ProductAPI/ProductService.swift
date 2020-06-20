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
    
    public func createItem(product: Product) -> EventLoopFuture<Product> {
        
        var product = product
        let date = Date().iso8601
        product.createdAt = date
        product.updatedAt = date
        
        let input = DynamoDB.PutItemInput(
            item: product.dynamoDictionary,
            tableName: tableName
        )
        return db.putItem(input).flatMap { _ -> EventLoopFuture<Product> in
            return self.readItem(key: product.sku)
        }
    }
    
    public func readItem(key: String) -> EventLoopFuture<Product> {
        let input = DynamoDB.GetItemInput(
            key: [ProductField.sku: DynamoDB.AttributeValue(s: key)],
            tableName: tableName
        )
        return db.getItem(input).flatMapThrowing { data -> Product in
            return try Product(dictionary: data.item ?? [:])
        }
    }
    
    public func updateItem(product: Product) -> EventLoopFuture<Product> {
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
        return db.updateItem(input).flatMap { _ -> EventLoopFuture<Product> in
            return self.readItem(key: product.sku)
        }
    }
    
    public func deleteItem(key: String) -> EventLoopFuture<Void> {
        let input = DynamoDB.DeleteItemInput(
            key: [ProductField.sku: DynamoDB.AttributeValue(s: key)],
            tableName: tableName
        )
        return db.deleteItem(input).map { _ in Void() }
    }
    
    public func listItems() -> EventLoopFuture<[Product]> {
        let input = DynamoDB.ScanInput(tableName: tableName)
        return db.scan(input)
            .flatMapThrowing { data -> [Product] in
                let products: [Product]? = try data.items?.compactMap { (item) -> Product in
                    return try Product(dictionary: item)
                }
                return products ?? []
        }
    }
}
