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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AWSLambdaRuntime
import AWSDynamoDB
import NIO
import Logging
import AsyncHTTPClient
import AWSLambdaEvents

enum Operation: String {
    case create
    case read
    case update
    case delete
    case list
    case unknown
}

struct EmptyResponse: Codable {
    
}

struct ProductLambda: LambdaHandler {
    
    //typealias In = APIGateway.SimpleRequest
    typealias In = APIGateway.V2.Request
    typealias Out = APIGateway.V2.Response
    
    let dbTimeout:Int64 = 30
    
    let region: Region
    let db: AWSDynamoDB.DynamoDB
    let service: ProductService
    let tableName: String
    let operation: Operation

    var httpClient: HTTPClient
    
    static func currentRegion() -> Region {
        
        if let awsRegion = ProcessInfo.processInfo.environment["AWS_REGION"] {
            let value = Region(rawValue: awsRegion)
            return value
            
        } else {
            //Default configuration
            return .useast1
        }
    }
    
    static func tableName() throws -> String {
        guard let tableName = ProcessInfo.processInfo.environment["PRODUCTS_TABLE_NAME"] else {
            throw APIError.tableNameNotFound
        }
        return tableName
    }
    
    init(eventLoop: EventLoop) {
        
        let handler = Lambda.env("_HANDLER") ?? ""
        self.operation = Operation(rawValue: handler) ?? .unknown
        
        self.region = Self.currentRegion()
        logger.info("\(Self.currentRegion())")

        let lambdaRuntimeTimeout: TimeAmount = .seconds(dbTimeout)
        let timeout = HTTPClient.Configuration.Timeout(connect: lambdaRuntimeTimeout,
                                                           read: lambdaRuntimeTimeout)
        let configuration = HTTPClient.Configuration(timeout: timeout)
        self.httpClient = HTTPClient(eventLoopGroupProvider: .createNew, configuration: configuration)
    
        self.db = AWSDynamoDB.DynamoDB(region: region, httpClientProvider: .shared(self.httpClient))
        logger.info("DynamoDB")
        
        self.tableName = (try? Self.tableName()) ?? ""
        
        self.service = ProductService(
            db: db,
            tableName: tableName
        )
        logger.info("ProductService")
    }

    func handle(context: Lambda.Context, event: APIGateway.V2.Request, callback: @escaping (Result<APIGateway.V2.Response, Error>) -> Void) {
        let _ = ProductLambdaHandler(service: service, operation: operation).handle(context: context, event: event)
            .always { (result) in
                callback(result)
        }
    }
}
