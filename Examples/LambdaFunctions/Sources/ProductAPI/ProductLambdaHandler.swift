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
            
            switch operation {
            case .create:
                let create = CreateLambdaHandler(service: service).handle(context: context, event: event)
                    .flatMap { response -> EventLoopFuture<APIGateway.V2.Response> in
                        switch response {
                        case .success(let result):
                            let value = APIGateway.V2.Response(with: result, statusCode: .created)
                            return context.eventLoop.makeSucceededFuture(value)
                        case .failure(let error):
                            let value = APIGateway.V2.Response(with: error, statusCode: .forbidden)
                            return context.eventLoop.makeSucceededFuture(value)
                        }
                }
                return create
            case .read:
                let read = ReadLambdaHandler(service: service).handle(context: context, event: event)
                    .flatMap { response -> EventLoopFuture<APIGateway.V2.Response> in
                        switch response {
                        case .success(let result):
                            let value = APIGateway.V2.Response(with: result, statusCode: .ok)
                            return context.eventLoop.makeSucceededFuture(value)
                        case .failure(let error):
                            let value = APIGateway.V2.Response(with: error, statusCode: .notFound)
                            return context.eventLoop.makeSucceededFuture(value)
                        }
                }
                return read
            case .update:
                let update = UpdateLambdaHandler(service: service).handle(context: context, event: event)
                    .flatMap { response -> EventLoopFuture<APIGateway.V2.Response> in
                        switch response {
                        case .success(let result):
                            let value = APIGateway.V2.Response(with: result, statusCode: .ok)
                            return context.eventLoop.makeSucceededFuture(value)
                        case .failure(let error):
                            let value = APIGateway.V2.Response(with: error, statusCode: .notFound)
                            return context.eventLoop.makeSucceededFuture(value)
                        }
                }
                return update
            case .delete:
                let delete = DeleteUpdateLambdaHandler(service: service).handle(
                    context: context, event: event
                )
                    .flatMap { response -> EventLoopFuture<APIGateway.V2.Response> in
                        switch response {
                        case .success(let result):
                            let value = APIGateway.V2.Response(with: result, statusCode: .ok)
                            return context.eventLoop.makeSucceededFuture(value)
                        case .failure(let error):
                            let value = APIGateway.V2.Response(with: error, statusCode: .notFound)
                            return context.eventLoop.makeSucceededFuture(value)
                        }
                }
                return delete
            case .list:
                let list = ListUpdateLambdaHandler(service: service).handle(context: context, event: event)
                    .flatMap { response -> EventLoopFuture<APIGateway.V2.Response> in
                        switch response {
                        case .success(let result):
                            let value = APIGateway.V2.Response(with: result, statusCode: .ok)
                            return context.eventLoop.makeSucceededFuture(value)
                        case .failure(let error):
                            let value = APIGateway.V2.Response(with: error, statusCode: .forbidden)
                            return context.eventLoop.makeSucceededFuture(value)
                        }
                }
                return list
            }
    }
    
    struct CreateLambdaHandler {
        
        let service: ProductService
        
        init(service: ProductService) {
            self.service = service
        }
        
        func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<Result<Product, Error>> {
                
                guard let product: Product = try? event.object() else {
                    let error = APIError.invalidRequest
                    return context.eventLoop.makeFailedFuture(error)
                }
                let future = service.createItem(product: product)
                    .flatMapThrowing { item -> Result<Product, Error> in
                        return Result.success(product)
                }
                return future
        }
    }
    
    struct ReadLambdaHandler {
        
        let service: ProductService
        
        init(service: ProductService) {
            self.service = service
        }
        
        func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<Result<Product, Error>> {
                
                guard let sku = event.pathParameters?["sku"] else {
                    let error = APIError.invalidRequest
                    return context.eventLoop.makeFailedFuture(error)
                }
                let future = service.readItem(key: sku)
                    .flatMapThrowing { data -> Result<Product, Error> in
                        let product = try Product(dictionary: data.item ?? [:])
                        return Result.success(product)
                }
                return future
        }
    }
    
    struct UpdateLambdaHandler {
        
        let service: ProductService
        
        init(service: ProductService) {
            self.service = service
        }
        
        func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<Result<Product, Error>> {
                
                guard let product: Product = try? event.object() else {
                    let error = APIError.invalidRequest
                    return context.eventLoop.makeFailedFuture(error)
                }
                let future = service.updateItem(product: product)
                    .flatMapThrowing { (data) -> Result<Product, Error> in
                        return Result.success(product)
                }
                return future
        }
    }
    
    struct DeleteUpdateLambdaHandler {
        
        let service: ProductService
        
        init(service: ProductService) {
            self.service = service
        }
        
        func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<Result<EmptyResponse, Error>> {
                
                guard let sku = event.pathParameters?["sku"] else {
                    let error = APIError.invalidRequest
                    return context.eventLoop.makeFailedFuture(error)
                }
                let future = service.deleteItem(key: sku)
                    .flatMapThrowing { (data) -> Result<EmptyResponse, Error> in
                        return Result.success(EmptyResponse())
                }
                return future
        }
    }
    
    struct ListUpdateLambdaHandler {
        
        let service: ProductService
        
        init(service: ProductService) {
            self.service = service
        }
        
        func handle(context: Lambda.Context, event: APIGateway.V2.Request) -> EventLoopFuture<Result<[Product], Error>> {
                
                let future = service.listItems()
                    .flatMapThrowing { data -> Result<[Product], Error> in
                        let products: [Product]? = try data.items?.compactMap { (item) -> Product in
                            return try Product(dictionary: item)
                        }
                        let object = products ?? []
                        return Result.success(object)
                }
                return future
        }
    }
}
