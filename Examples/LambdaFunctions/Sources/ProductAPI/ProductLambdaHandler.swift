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

import AWSLambdaEvents
import AWSLambdaRuntime
import Logging
import NIO

struct ProductLambdaHandler: EventLoopLambdaHandler {
    
    typealias In = APIGateway.V2.Request
    typealias Out = APIGateway.V2.Response
    
    let service: ProductService
    let operation: Operation
    
    func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        
        switch self.operation {
        case .create:
            return createLambdaHandler(context: context, event: event)
        case .read:
            return readLambdaHandler(context: context, event: event)
        case .update:
            return updateLambdaHandler(context: context, event: event)
        case .delete:
            return deleteUpdateLambdaHandler(context: context, event: event)
        case .list:
            return listUpdateLambdaHandler(context: context, event: event)
        }
    }
    
    func createLambdaHandler(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        guard let product: Product = try? event.object() else {
            let error = APIError.invalidRequest
            return context.eventLoop.makeFailedFuture(error)
        }
        return service.createItem(product: product)
            .map { result -> (APIGateway.V2.Response) in
                return APIGateway.V2.Response(with: result, statusCode: .created)
        }.flatMapError { (error) -> EventLoopFuture<APIGateway.V2.Response> in
            let value = APIGateway.V2.Response(with: error, statusCode: .forbidden)
            return context.eventLoop.makeSucceededFuture(value)
        }
    }
    
    func readLambdaHandler(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        guard let sku = event.pathParameters?["sku"] else {
            let error = APIError.invalidRequest
            return context.eventLoop.makeFailedFuture(error)
        }
        return service.readItem(key: sku)
            .flatMapThrowing { result -> APIGateway.V2.Response in
                return APIGateway.V2.Response(with: result, statusCode: .ok)
        }.flatMapError { (error) -> EventLoopFuture<APIGateway.V2.Response> in
            let value = APIGateway.V2.Response(with: error, statusCode: .notFound)
            return context.eventLoop.makeSucceededFuture(value)
        }
    }
    
    func updateLambdaHandler(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        guard let product: Product = try? event.object() else {
            let error = APIError.invalidRequest
            return context.eventLoop.makeFailedFuture(error)
        }
        return service.updateItem(product: product)
            .map { result -> (APIGateway.V2.Response) in
                return APIGateway.V2.Response(with: result, statusCode: .ok)
        }.flatMapError { (error) -> EventLoopFuture<APIGateway.V2.Response> in
            let value = APIGateway.V2.Response(with: error, statusCode: .notFound)
            return context.eventLoop.makeSucceededFuture(value)
        }
    }
    
    func deleteUpdateLambdaHandler(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        guard let sku = event.pathParameters?["sku"] else {
            let error = APIError.invalidRequest
            return context.eventLoop.makeFailedFuture(error)
        }
        return service.deleteItem(key: sku)
            .map { _ -> (APIGateway.V2.Response) in
                return APIGateway.V2.Response(with: EmptyResponse(), statusCode: .ok)
        }.flatMapError { (error) -> EventLoopFuture<APIGateway.V2.Response> in
            let value = APIGateway.V2.Response(with: error, statusCode: .notFound)
            return context.eventLoop.makeSucceededFuture(value)
        }
    }
    
    func listUpdateLambdaHandler(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<APIGateway.V2.Response> {
        return service.listItems()
            .flatMapThrowing { result -> APIGateway.V2.Response in
                return APIGateway.V2.Response(with: result, statusCode: .ok)
        }.flatMapError { (error) -> EventLoopFuture<APIGateway.V2.Response> in
            let value = APIGateway.V2.Response(with: error, statusCode: .forbidden)
            return context.eventLoop.makeSucceededFuture(value)
        }
    }
}
