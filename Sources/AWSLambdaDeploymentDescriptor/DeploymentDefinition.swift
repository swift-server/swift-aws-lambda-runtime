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
// An immediate TODO if this code is accepted is to add more properties and more classes
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
            self.resources[res.name()] = res
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

public protocol SAMResource: Encodable {}
public protocol SAMResourceProperties: Encodable {}

public struct Resource: SAMResource {
    
    let type: String
    let properties: SAMResourceProperties
    let _name: String
    
    public func name() -> String { return _name }
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
    
    // this is to make the compiler happy : Resource now confoms to Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(self.type, forKey: .type)
        try? container.encode(self.properties, forKey: .properties)
    }
    
}

//MARK: Lambda Function resource definition
/*---------------------------------------------------------------------------------------
 Lambda Function
 
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-function.html
-----------------------------------------------------------------------------------------*/

extension Resource {
    public static func serverlessFunction(name: String,
                                          codeUri: String,
                                          eventSources: [EventSource] = [],
                                          environment: EnvironmentVariable = EnvironmentVariable.none()) -> Resource {
        
        let properties = ServerlessFunctionProperties(codeUri: codeUri,
                                                       eventSources: eventSources,
                                                       environment: environment)
        return Resource(type: "AWS::Serverless::Function",
                        properties: properties,
                        _name: name)
    }

}

public struct ServerlessFunctionProperties: SAMResourceProperties {
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
            self.eventSources[es.name()] = es
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

public protocol SAMEvent : Encodable, Equatable {}
public protocol SAMEventProperties : Encodable {}

public struct EventSource: SAMEvent {

    let type: String
    let properties: SAMEventProperties?
    let _name: String
    
    public func name() -> String { return _name }
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case properties = "Properties"
    }
    
    public static func == (lhs: EventSource, rhs: EventSource) -> Bool {
        lhs.type == rhs.type && lhs.name() == rhs.name()
    }

    // this is to make the compiler happy : Resource now confoms to Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(self.type, forKey: .type)
        if let properties = self.properties {
            try? container.encode(properties, forKey: .properties)
        }
    }
}


//MARK: HTTP API Event definition
/*---------------------------------------------------------------------------------------
 HTTP API Event (API Gateway v2)
 
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-httpapi.html
-----------------------------------------------------------------------------------------*/

extension EventSource {
    public static func httpApi(name: String = "HttpApiEvent",
                               method: HttpVerb? = nil,
                               path: String? = nil) -> EventSource {
        
        var properties: SAMEventProperties? = nil
        if method != nil || path != nil {
            properties = HttpApiProperties(method: method, path: path)
        }
        
        return EventSource(type: "HttpApi",
                           properties: properties,
                           _name: name)
    }
}

struct HttpApiProperties: SAMEventProperties, Equatable {
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

extension EventSource {
    public static func sqs(name: String = "SQSEvent",
                           queue: String) -> EventSource {
        
        let properties = SQSEventProperties(queue)
        
        return EventSource(type: "SQS",
                           properties: properties,
                           _name: name)
    }
}

/**
   Represents SQS queue properties.
   When `queue` name  is a shorthand YAML reference to another resource, like `!GetAtt`, it splits the shorthand into proper YAML to make the parser happy
 */
public struct SQSEventProperties: SAMEventProperties, Equatable {
    
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
    
    public init(_ queue: String) {
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
extension Resource {
    public static func sqsQueue(name: String,
                                properties: SQSResourceProperties) -> Resource {
                                                
        return Resource(type: "AWS::SQS::Queue",
                        properties: properties,
                        _name: name)
    }

}

public struct SQSResourceProperties: SAMResourceProperties {
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

extension Resource {
    public static func simpleTable(name: String,
                                   properties: SimpleTableProperties) -> Resource {
                                                
        return Resource(type: "AWS::Serverless::SimpleTable",
                        properties: properties,
                        _name: name)
    }

}

public struct SimpleTableProperties: SAMResourceProperties {
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
