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

import SotoDynamoDB
import Foundation
import NIO

public enum APIError: Error {
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
}

extension DateFormatter {
    static var iso8061: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

extension Date {
    var iso8601: String {
        let formatter = DateFormatter.iso8061
        return formatter.string(from: self)
    }
}

extension String {
    var iso8601: Date? {
        let formatter = DateFormatter.iso8061
        return formatter.date(from: self)
    }
    
    var timeIntervalSince1970String: String? {
        guard let timeInterval = self.iso8601?.timeIntervalSince1970 else {
            return nil
        }
        return "\(timeInterval)"
    }
}

public class ProductService {
    
    enum ProductError: Error {
        case notFound
    }
    
    let db: DynamoDB
    let tableName: String
    
    public init(db: DynamoDB, tableName: String) {
        self.db = db
        self.tableName = tableName
    }
    
    public func createItem(product: Product) -> EventLoopFuture<Product> {
        
        var product = product
        let date = Date()
        product.createdAt = date.iso8601
        product.updatedAt = date.iso8601
        
        let input = DynamoDB.PutItemCodableInput(item: product, tableName: tableName)
        return db.putItem(input).flatMap { _ -> EventLoopFuture<Product> in
            return self.readItem(key: product.sku)
        }
    }
    
    public func readItem(key: String) -> EventLoopFuture<Product> {
        
        let input = DynamoDB.GetItemInput(
            key: [Product.Field.sku: DynamoDB.AttributeValue.s(key)],
            tableName: tableName
        )
        return db.getItem(input, type: Product.self).flatMapThrowing { data -> Product in
            guard let product = data.item else {
                throw ProductError.notFound
            }
            return product
        }
    }
    
    public func updateItem(product: Product) -> EventLoopFuture<Product> {
        var product = product
        let date = Date()
        let updatedAt = date.iso8601
        product.updatedAt = date.iso8601
        
        let input = DynamoDB.UpdateItemInput(
            conditionExpression: "attribute_exists(#createdAt)",
            expressionAttributeNames: [
                "#name": Product.Field.name,
                "#description": Product.Field.description,
                "#updatedAt": Product.Field.updatedAt,
                "#createdAt": Product.Field.createdAt
            ],
            expressionAttributeValues: [
                ":name": DynamoDB.AttributeValue.s(product.name),
                ":description": DynamoDB.AttributeValue.s(product.description),
                ":updatedAt": DynamoDB.AttributeValue.s(updatedAt)
            ],
            key: [Product.Field.sku: DynamoDB.AttributeValue.s(product.sku)],
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
            key: [Product.Field.sku: DynamoDB.AttributeValue.s(key)],
            tableName: tableName
        )
        return db.deleteItem(input).map { _ in Void() }
    }
    
    public func listItems() -> EventLoopFuture<[Product]> {
        let input = DynamoDB.ScanInput(tableName: tableName)
        return db.scan(input, type: Product.self).flatMapThrowing { data -> [Product] in
            return data.items ?? []

        }
    }
}
