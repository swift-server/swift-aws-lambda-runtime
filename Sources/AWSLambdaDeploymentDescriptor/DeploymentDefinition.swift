// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import Foundation

public protocol DeploymentDefinition: Encodable {}

// maybe this file might be generated entirely or partially automatically from
// https://github.com/aws/serverless-application-model/blob/develop/samtranslator/validator/sam_schema/schema.json

// a Swift definition of a SAM deployment decsriptor.
// currently limited to the properties I needed for the examples.
// A immediate TODO if this code is accepted is to add more properties and more classes
public struct SAMDeployment: DeploymentDefinition {
    
    let awsTemplateFormatVersion: String
    let transform: String
    let description: String
    var resources: [String: Resource]
    
    public init(
        templateVersion: String = "2010-09-09",
        transform: String = "AWS::Serverless-2016-10-31",
        description: String = "A SAM template to deploy a Swift Lambda function",
        resources: [Resource] = []
    ) {
        
        self.awsTemplateFormatVersion = templateVersion
        self.transform = transform
        self.description = description
        self.resources = [String: Resource]()
        
        for res in resources {
            self.resources[res.resourceLogicalName()] = res
        }
    }
    
    // allows to add more resource. It returns a new SAMDeploymentDescription with the updated list of resources
    public func addResource(_ resource: Resource) -> SAMDeployment {
        
        var existingResources: [Resource] = self.resources.values.compactMap{ $0 }
        existingResources.append(resource)
        
        return SAMDeployment(templateVersion: self.awsTemplateFormatVersion,
                             transform: self.transform,
                             description: self.description,
                             resources: existingResources)
    }

    
    enum CodingKeys: String, CodingKey {
        case awsTemplateFormatVersion = "AWSTemplateFormatVersion"
        case transform = "Transform"
        case description = "Description"
        case resources = "Resources"
    }
}

public enum Resource: Encodable {
    
    case function(_ name: String, _ function: ServerlessFunctionResource)
    case simpleTable(_ name: String, _ table: SimpleTableResource)
    case queue(_ name: String, _ queue: SQSResource)
    
    // a resource provides it's own key for encoding
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .function(_, let function):
            try? container.encode(function)
        case .simpleTable(_, let table):
            try? container.encode(table)
        case .queue(_, let queue):
            try? container.encode(queue)
        }
    }
    public func resourceLogicalName() -> String {
        switch self {
        case .function(let name, _): return name
        case .simpleTable(let name, _): return name
        case .queue(let name, _): return name
        }
    }
}

//MARK: Lambda Function resource definition
/*---------------------------------------------------------------------------------------
 Lambda Function
 
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-function.html
-----------------------------------------------------------------------------------------*/

public struct ServerlessFunctionResource: Encodable {
    
    let type: String = "AWS::Serverless::Function"
    let properties: ServerlessFunctionProperties
    
    public init(codeUri: String,
                eventSources: [EventSource] = [],
                environment: EnvironmentVariable = EnvironmentVariable.none()) {
        
        self.properties = ServerlessFunctionProperties(codeUri: codeUri,
                                                       eventSources: eventSources,
                                                       environment: environment)
    }
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
}

public struct ServerlessFunctionProperties: Encodable {
    public enum Architectures: String, Encodable {
        case x64 = "x86_64"
        case arm64 = "arm64"
    }
    let architectures: [Architectures]
    let handler: String
    let runtime: String
    let codeUri: String
    let autoPublishAlias: String
    var eventSources: [String: EventSource]
    var environment: EnvironmentVariable
    
    public init(codeUri: String,
                eventSources: [EventSource] = [],
                environment: EnvironmentVariable = EnvironmentVariable.none()) {
        
        #if arch(arm64) //when we build on Arm, we deploy on Arm
        self.architectures = [.arm64]
        #else
        self.architectures = [.x64]
        #endif
        self.handler = "Provided"
        self.runtime = "provided.al2" // Amazon Linux 2 supports both arm64 and x64
        self.autoPublishAlias = "Live"
        self.codeUri = codeUri
        self.eventSources = [String: EventSource]()
        self.environment = environment
        
        for es in eventSources {
            self.eventSources[es.eventLogicalName()] = es
        }
    }
    
    // custom encoding to not provide Environment variables when there is none
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.architectures, forKey: .architectures)
        try container.encode(self.handler, forKey: .handler)
        try container.encode(self.runtime, forKey: .runtime)
        try container.encode(self.codeUri, forKey: .codeUri)
        try container.encode(self.autoPublishAlias, forKey: .autoPublishAlias)
        try container.encode(self.eventSources, forKey: .eventSources)
        if !environment.isEmpty() {
            try container.encode(self.environment, forKey: .environment)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case architectures = "Architectures"
        case handler = "Handler"
        case runtime = "Runtime"
        case codeUri = "CodeUri"
        case autoPublishAlias = "AutoPublishAlias"
        case eventSources = "Events"
        case environment = "Environment"
    }
}

/*
 Environment:
   Variables:
     LOG_LEVEL: debug
 */
public struct EnvironmentVariable: Codable {
    public let variables: [String:String]
    public init(_ variables: [String:String]) {
        self.variables = variables
    }
    public static func none() -> EnvironmentVariable { return EnvironmentVariable([:]) }
    public func isEmpty() -> Bool { return variables.count == 0 }
    enum CodingKeys: String, CodingKey {
        case variables = "Variables"
    }
}

//MARK: Lambda Function event source
public enum EventSource: Encodable, Equatable {
    
    // I put name as last parameters to allow unnamed default values
    case httpApiEvent(_ httpApi: HttpApiEvent, _ name: String = "HttpApiEvent")
    case sqsEvent(_ sqs: SQSEvent, _ name: String = "SQSEvent")
    
    // each source provide it's own top-level key
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
    
        switch self {
        case .httpApiEvent(let httpApi, _):
            try? container.encode(httpApi)
        case .sqsEvent(let sqs, _):
            try? container.encode(sqs)
        }
    }
    
    public func eventLogicalName() -> String {
        switch self {
            case .httpApiEvent(_, let name): return name
            case .sqsEvent(_, let name): return name
        }
    }
}

//MARK: HTTP API Event definition
/*---------------------------------------------------------------------------------------
 HTTP API Event (API Gateway v2)
 
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-httpapi.html
-----------------------------------------------------------------------------------------*/

public struct HttpApiEvent: Encodable, Equatable {
    let type: String = "HttpApi"
    let properties: HttpApiProperties?
    public init(method: HttpVerb? = nil, path: String? = nil) {
        if method != nil || path != nil {
            self.properties = .init(method: method, path: path)
        } else {
            self.properties = nil
        }
    }
    
    // Properties is option, HttpApi without properties forwards all requests to the lambda function
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: HttpApiEventKeys.self)
        try container.encode(self.type, forKey: .type)
        if let properties = self.properties {
            try container.encode(properties, forKey: .properties)
        }
    }
    enum HttpApiEventKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
}
struct HttpApiProperties: Encodable, Equatable {
    init(method: HttpVerb? = nil, path: String? = nil) {
        self.method = method
        self.path = path
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: HttpApiKeys.self)
        if let method = self.method {
            try container.encode(method, forKey: .method)
        }
        if let path = self.path {
            try container.encode(path, forKey: .path)
        }
    }
    let method: HttpVerb?
    let path: String?
    
    enum HttpApiKeys: String, CodingKey {
        case method = "Method"
        case path = "Path"
    }
}

public enum HttpVerb: String, Encodable {
    case GET
    case POST
}

//MARK: SQS event definition
/*---------------------------------------------------------------------------------------
 SQS Event
 
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-sqs.html
-----------------------------------------------------------------------------------------*/
public struct SQSEvent: Encodable, Equatable {
    var type: String = "SQS"
    public let properties: SQSProperties
    public init(queue: String) {
        self.properties = .init(queue: queue)
    }
    public init(queueArn: String) {
        //FIXME: check for Arn Format
        self.properties = .init(queue: queueArn)
    }
    public init(queueRef: String) {
        self.properties = .init(queue: "!GetAtt \(queueRef).Arn")
    }
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
}

/**
   Represents SQS queue properties.
   When `queue` name  is a shorthand YAML reference to another resource, like `!GetAtt`, it splits the shorthand into proper YAML to make the parser happy
 */
public struct SQSProperties: Codable, Equatable {
    
    private var _queue: String = ""

    // Change encoding when queueName starts with !GetAtt - it should be
    // Fn::GetAtt: [ logicalNameOfResource, attributeName ]
    // doc : https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/intrinsic-function-reference-getatt.html
    public var queue: String {
        get {
            return _queue
        }
        set(newQueue) {
            if newQueue.starts(with: "!") {
                let elements = newQueue.split(separator: " ")
                guard elements.count == 2 else {
                    fatalError("Invalid intrisic function: \(newQueue), only one space allowed")
                }
                let key = String(elements[0]).replacingOccurrences(of: "!", with: "Fn::")
                self.intrisicFunction[key] = elements[1].split(separator: ".").map{ String($0) }
            } else {
                self._queue = newQueue
            }
        }
    }
    var intrisicFunction: [String:[String]] = [:]
    
    
    public init(queue: String) {
        self.queue = queue
    }
    enum CodingKeys: String, CodingKey {
        case _queue = "Queue"
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if  intrisicFunction.isEmpty {
            try container.encode(self.queue, forKey: ._queue)
        } else {
            try container.encode(intrisicFunction, forKey: ._queue)
        }
    }
    
}

//MARK: SQS queue resource definition
/*---------------------------------------------------------------------------------------
 SQS Queue Resource
 
 Documentation
 https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-sqs-queue.html
-----------------------------------------------------------------------------------------*/
public struct SQSResource: Encodable {
    
    let type: String = "AWS::SQS::Queue"
    public let properties: SQSResourceProperties
    
    public init(properties: SQSResourceProperties) {
        self.properties = properties
    }
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
}

public struct SQSResourceProperties: Encodable {
    public let queueName: String
    enum CodingKeys: String, CodingKey {
        case queueName = "QueueName"
    }
}

//MARK: Simple DynamoDB table resource definition
/*---------------------------------------------------------------------------------------
 Simple DynamoDB Table Resource
 
 Documentation
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-simpletable.html
-----------------------------------------------------------------------------------------*/

public struct SimpleTableResource: Encodable {
    
    let type: String = "AWS::Serverless::SimpleTable"
    let properties: SimpleTableProperties
    
    public init(properties: SimpleTableProperties) {
        self.properties = properties
    }
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
}

public struct SimpleTableProperties: Encodable {
    let primaryKey: PrimaryKey
    let tableName: String
    let provisionedThroughput: ProvisionedThroughput?
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let provisionedThroughput = self.provisionedThroughput {
            try container.encode(provisionedThroughput, forKey: .provisionedThroughput)
        }
    }
    enum CodingKeys: String, CodingKey {
        case primaryKey = "PrimaryKey"
        case tableName = "TableName"
        case provisionedThroughput = "ProvisionedThroughput"
    }
    struct PrimaryKey: Codable {
        let name: String
        let type: String
        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case type = "Type"
        }
    }
    struct ProvisionedThroughput: Codable {
        let readCapacityUnits: Int
        let writeCapacityUnits: Int
        enum CodingKeys: String, CodingKey {
            case readCapacityUnits = "ReadCapacityUnits"
            case writeCapacityUnits = "WriteCapacityUnits"
        }
    }
}

public enum DeploymentEncodingError: Error {
    case yamlError(causedBy: Error)
    case jsonError(causedBy: Error)
    case stringError(causedBy: Data)
}
