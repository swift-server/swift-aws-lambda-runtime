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
import SmokeDynamoDB
import AWSLambdaRuntime
import AsyncHTTPClient
import SmokeAWSCredentials
import SmokeAWSCore
import NIO
import Logging

// MARK: - Run Lambda

Lambda.run(DynamoDBPutBackendHandler.init)

// MARK: - Custom Context handler

struct DynamoDBPutBackendContextHandler {
    
    /**
     The context to be passed to invocations of the DynamoDBPutBackend function.
     */
    public struct Context {
        public let dynamodbTable: DynamoDBCompositePrimaryKeyTable
        public let idGenerator: () -> String
        public let timestampGenerator: () -> String
        public let logger: Logger
        
        static let itemsPartitionKey = ["swift", "aws", "lambda", "runtime", "samples", "items"].dynamodbKey
        static let itemPrefix = ["swift", "aws", "lambda", "runtime", "samples", "item"]
        
        public init(dynamodbTable: DynamoDBCompositePrimaryKeyTable,
                    idGenerator: @escaping () -> String,
                    timestampGenerator: @escaping () -> String,
                    logger: Logger) {
            self.dynamodbTable = dynamodbTable
            self.idGenerator = idGenerator
            self.timestampGenerator = timestampGenerator
            self.logger = logger
        }
    }
    
    struct Request: Codable {
        let value: String

        public init(value: String) {
            self.value = value
        }
    }

    struct Response: Codable {
        let keyId: String

        public init(keyId: String) {
            self.keyId = keyId
        }
    }
  
    func handle(context: Context, payload: Request, callback: @escaping (Result<Response, Error>) -> Void) {
        
        let itemIdPostfix = "\(context.timestampGenerator()).\(context.idGenerator())"
        let itemId = (Context.itemPrefix + [itemIdPostfix]).dynamodbKey
        
        let itemKey = StandardCompositePrimaryKey(partitionKey: Context.itemsPartitionKey,
                                                  sortKey: itemId)
        let itemDatabaseItem = StandardTypedDatabaseItem.newItem(withKey: itemKey,
                                                                 andValue: payload)
        
        do {
            try context.dynamodbTable.insertItemAsync(itemDatabaseItem) { error in
                if let error = error {
                    callback(.failure(error))
                } else {
                    callback(.success(Response(keyId: itemId)))
                }
            }
        } catch {
            callback(.failure(error))
        }
    }
}

// MARK: - LambdaHandler implementation

enum DynamoDBPutBackendError: Swift.Error {
    case unableToObtainCredentialsFromLambdaEnvironment
    case missingEnvironmentVariable(reason: String)
    case invalidEnvironmentVariable(reason: String)
}

struct DynamoDBPutBackendHandler: LambdaHandler {
    
    typealias In = DynamoDBPutBackendContextHandler.Request
    typealias Out = DynamoDBPutBackendContextHandler.Response
    
    let dynamodbTableGenerator: AWSDynamoDBCompositePrimaryKeyTableGenerator
    let handler: DynamoDBPutBackendContextHandler

    // run once at cold start
    init(eventLoop: EventLoop) throws {
        let environment = EnvironmentVariables.getEnvironment()
        
        // use the internal LambdaEventLoop as the EventLoopGroup
        let clientEventLoopProvider = HTTPClient.EventLoopGroupProvider.shared(eventLoop)
        
        guard let credentialsProvider = AwsContainerRotatingCredentialsProvider.get(
                fromEnvironment: environment,
                eventLoopProvider: clientEventLoopProvider) else {
            throw DynamoDBPutBackendError.unableToObtainCredentialsFromLambdaEnvironment
        }
        
        let region = try environment.getRegion()

        self.dynamodbTableGenerator = try Self.initializeDynamoDBTableGeneratorFromEnvironment(
            environment: environment,
            credentialsProvider: credentialsProvider,
            region: region,
            clientEventLoopProvider: clientEventLoopProvider)
        self.handler = DynamoDBPutBackendContextHandler()
    }
    
    func timestampGenerator() -> String {
        "\(Date().timeIntervalSinceReferenceDate)"
    }

    func idGenerator() -> String {
        UUID().uuidString
    }

    private static func initializeDynamoDBTableGeneratorFromEnvironment(
        environment: [String: String],
        credentialsProvider: CredentialsProvider,
        region: AWSRegion,
        clientEventLoopProvider: HTTPClient.EventLoopGroupProvider) throws -> AWSDynamoDBCompositePrimaryKeyTableGenerator {
        let dynamoEndpointHostName = try environment.get(EnvironmentVariables.dynamoEndpointHostName)
        let dynamoTableName = try environment.get(EnvironmentVariables.dynamoTableName)

        return AWSDynamoDBCompositePrimaryKeyTableGenerator(
            credentialsProvider: credentialsProvider,
            region: region, endpointHostName: dynamoEndpointHostName,
            tableName: dynamoTableName,
            eventLoopProvider: clientEventLoopProvider)
    }
    
    func getContext(context: Lambda.Context) -> DynamoDBPutBackendContextHandler.Context {
        let dynamodbTable = dynamodbTableGenerator.with(logger: context.logger,
                                                        internalRequestId: context.requestId)
        
        return DynamoDBPutBackendContextHandler.Context(dynamodbTable: dynamodbTable,
                                         idGenerator: idGenerator,
                                         timestampGenerator: timestampGenerator,
                                         logger: context.logger)
    }
    
    func handle(context: Lambda.Context, payload: In, callback: @escaping (Result<Out, Error>) -> Void) {
        let dynamoDBPutBackendContext = getContext(context: context)
        
        handler.handle(context: dynamoDBPutBackendContext, payload: payload, callback: callback)
    }
}

// MARK: - Convenience extensions

private struct EnvironmentVariables {
    static let dynamoEndpointHostName = "DYNAMO_ENDPOINT_HOST_NAME"
    static let dynamoTableName = "DYNAMO_TABLE_NAME"
    static let region = "AWS_REGION"
    
    static func getEnvironment() -> [String: String] {
        return ProcessInfo.processInfo.environment
    }
}

private extension Dictionary where Key == String, Value == String {
    func get(_ key: String) throws -> String {
        guard let value = self[key] else {
            throw DynamoDBPutBackendError.missingEnvironmentVariable(reason:
                "'\(key)' environment variable not specified.")
        }
        
        return value
    }
    
    func getRegion() throws -> AWSRegion {
        let regionString = try get(EnvironmentVariables.region)
        
        guard let region = AWSRegion(rawValue: regionString) else {
            throw DynamoDBPutBackendError.invalidEnvironmentVariable(reason:
                "Specified '\(EnvironmentVariables.region)' environment variable '\(regionString)' not a valid region.")
        }
        
        return region
    }
}
