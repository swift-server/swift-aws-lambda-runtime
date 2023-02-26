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

// maybe this file might be generated entirely or partially automatically from
// https://github.com/aws/serverless-application-model/blob/develop/samtranslator/validator/sam_schema/schema.json

// a Swift definition of a SAM deployment descriptor.
// currently limited to the properties I needed for the examples.
// An immediate TODO if this code is accepted is to add more properties and more struct
public struct SAMDeploymentDescriptor: Encodable {

  let templateVersion: String = "2010-09-09"
  let transform: String = "AWS::Serverless-2016-10-31"
  let description: String
  var resources: [String: Resource<ResourceType>] = [:]

  public init(
    description: String = "A SAM template to deploy a Swift Lambda function",
    resources: [Resource<ResourceType>] = []
  ) {
    self.description = description
    for res in resources {
      self.resources[res.name] = res
    }
  }

  enum CodingKeys: String, CodingKey {
    case templateVersion = "AWSTemplateFormatVersion"
    case transform = "Transform"
    case description = "Description"
    case resources = "Resources"
  }
}

public protocol SAMResource: Encodable {}
public protocol SAMResourceType: Encodable, Equatable {}
public protocol SAMResourceProperties: Encodable {}

public enum ResourceType: String, SAMResourceType {
  case serverlessFunction = "AWS::Serverless::Function"
  case queue = "AWS::SQS::Queue"
  case table = "AWS::Serverless::SimpleTable"
}
public enum EventSourceType: String, SAMResourceType {
  case httpApi = "HttpApi"
  case sqs = "SQS"
}

// generic type to represent either a top-level resource or an event source
public struct Resource<T: SAMResourceType>: SAMResource, Equatable {

  let type: T
  let properties: SAMResourceProperties?
  let name: String

  public static func == (lhs: Resource<T>, rhs: Resource<T>) -> Bool {
    lhs.type == rhs.type && lhs.name == rhs.name
  }

  enum CodingKeys: String, CodingKey {
    case type = "Type"
    case properties = "Properties"
  }

  // this is to make the compiler happy : Resource now conforms to Encodable
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try? container.encode(self.type, forKey: .type)
    if let properties = self.properties {
      try? container.encode(properties, forKey: .properties)
    }
  }
}

//MARK: Lambda Function resource definition
/*---------------------------------------------------------------------------------------
 Lambda Function

 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-function.html
 -----------------------------------------------------------------------------------------*/

extension Resource {
  public static func serverlessFunction(
    name: String,
    architecture: Architectures,
    codeUri: String?,
    eventSources: [Resource<EventSourceType>] = [],
    environment: SAMEnvironmentVariable = .none
  ) -> Resource<ResourceType> {

    let properties = ServerlessFunctionProperties(
      codeUri: codeUri,
      architecture: architecture,
      eventSources: eventSources,
      environment: environment)
    return Resource<ResourceType>(
      type: .serverlessFunction,
      properties: properties,
      name: name)
  }
}

public enum Architectures: String, Encodable, CaseIterable {
  case x64 = "x86_64"
  case arm64 = "arm64"

  // the default value is the current architecture
  public static func defaultArchitecture() -> Architectures {
    #if arch(arm64)
      return .arm64
    #else  // I understand this #else will not always be true. Developers can overwrite the default in Deploy.swift
      return .x64
    #endif
  }

  // valid values for error and help message
  public static func validValues() -> String {
    return Architectures.allCases.map { $0.rawValue }.joined(separator: ", ")
  }
}

public struct ServerlessFunctionProperties: SAMResourceProperties {
  let architectures: [Architectures]
  let handler: String
  let runtime: String
  let codeUri: String?
  let autoPublishAlias: String
  var eventSources: [String: Resource<EventSourceType>]
  var environment: SAMEnvironmentVariable

  public init(
    codeUri: String?,
    architecture: Architectures,
    eventSources: [Resource<EventSourceType>] = [],
    environment: SAMEnvironmentVariable = .none
  ) {

    self.architectures = [architecture]
    self.handler = "Provided"
    self.runtime = "provided.al2"  // Amazon Linux 2 supports both arm64 and x64
    self.autoPublishAlias = "Live"
    self.codeUri = codeUri
    self.eventSources = [:]
    self.environment = environment

    for es in eventSources {
      self.eventSources[es.name] = es
    }
  }

  // custom encoding to not provide Environment variables when there is none
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.architectures, forKey: .architectures)
    try container.encode(self.handler, forKey: .handler)
    try container.encode(self.runtime, forKey: .runtime)
    if let codeUri = self.codeUri {
      try container.encode(codeUri, forKey: .codeUri)
    }
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
public struct SAMEnvironmentVariable: Encodable {

  public var variables: [String: SAMEnvironmentVariableValue] = [:]
  public init() {}
  public init(_ variables: [String: String]) {
    for key in variables.keys {
      self.variables[key] = .string(value: variables[key] ?? "")
    }
  }
  public static var none: SAMEnvironmentVariable { return SAMEnvironmentVariable([:]) }

  public static func variable(_ name: String, _ value: String) -> SAMEnvironmentVariable {
    return SAMEnvironmentVariable([name: value])
  }
  public static func variable(_ variables: [String: String]) -> SAMEnvironmentVariable {
    return SAMEnvironmentVariable(variables)
  }
  public static func variable(_ variables: [[String: String]]) -> SAMEnvironmentVariable {

    var mergedDictKeepCurrent: [String: String] = [:]
    variables.forEach { dict in
      // inspired by https://stackoverflow.com/a/43615143/663360
      mergedDictKeepCurrent = mergedDictKeepCurrent.merging(dict) { (current, _) in current }
    }

    return SAMEnvironmentVariable(mergedDictKeepCurrent)

  }
  public func isEmpty() -> Bool { return variables.count == 0 }

  public mutating func append(_ key: String, _ value: String) {
    variables[key] = .string(value: value)
  }
  public mutating func append(_ key: String, _ value: [String: String]) {
    variables[key] = .array(value: value)
  }
  public mutating func append(_ key: String, _ value: [String: [String]]) {
    variables[key] = .dictionary(value: value)
  }
  public mutating func append(_ key: String, _ value: Resource<ResourceType>) {
    variables[key] = .array(value: ["Ref": value.name])
  }

  enum CodingKeys: String, CodingKey {
    case variables = "Variables"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    var nestedContainer = container.nestedContainer(keyedBy: AnyStringKey.self, forKey: .variables)

    for key in variables.keys {
      switch variables[key] {
      case .string(let value):
        try? nestedContainer.encode(value, forKey: AnyStringKey(key))
      case .array(let value):
        try? nestedContainer.encode(value, forKey: AnyStringKey(key))
      case .dictionary(let value):
        try? nestedContainer.encode(value, forKey: AnyStringKey(key))
      case .none:
        break
      }
    }
  }

  public enum SAMEnvironmentVariableValue {
    // KEY: VALUE
    case string(value: String)

    // KEY:
    //    Ref: VALUE
    case array(value: [String: String])

    // KEY:
    //    Fn::GetAtt:
    //      - VALUE1
    //      - VALUE2
    case dictionary(value: [String: [String]])
  }

  private struct AnyStringKey: CodingKey, Hashable, ExpressibleByStringLiteral {
    var stringValue: String
    init(stringValue: String) { self.stringValue = stringValue }
    init(_ stringValue: String) { self.init(stringValue: stringValue) }
    var intValue: Int?
    init?(intValue: Int) { return nil }
    init(stringLiteral value: String) { self.init(value) }
  }
}

//MARK: HTTP API Event definition
/*---------------------------------------------------------------------------------------
 HTTP API Event (API Gateway v2)

 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-httpapi.html
 -----------------------------------------------------------------------------------------*/

extension Resource {
  public static func httpApi(
    name: String = "HttpApiEvent",
    method: HttpVerb? = nil,
    path: String? = nil
  ) -> Resource<EventSourceType> {

    var properties: SAMResourceProperties? = nil
    if method != nil || path != nil {
      properties = HttpApiProperties(method: method, path: path)
    }

    return Resource<EventSourceType>(
      type: .httpApi,
      properties: properties,
      name: name)
  }
}

struct HttpApiProperties: SAMResourceProperties, Equatable {
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

extension Resource {
  internal static func sqs(
    name: String = "SQSEvent",
    properties: SQSEventProperties
  ) -> Resource<EventSourceType> {

    return Resource<EventSourceType>(
      type: .sqs,
      properties: properties,
      name: name)
  }
  public static func sqs(
    name: String = "SQSEvent",
    queue queueRef: String
  ) -> Resource<EventSourceType> {

    let properties = SQSEventProperties(byRef: queueRef)
    return Resource<EventSourceType>.sqs(
      name: name,
      properties: properties)
  }

  public static func sqs(
    name: String = "SQSEvent",
    queue: Resource<ResourceType>
  ) -> Resource<EventSourceType> {

    let properties = SQSEventProperties(queue)
    return Resource<EventSourceType>.sqs(
      name: name,
      properties: properties)
  }
}

/// Represents SQS queue properties.
/// When `queue` name  is a shorthand YAML reference to another resource, like `!GetAtt`, it splits the shorthand into proper YAML to make the parser happy
public struct SQSEventProperties: SAMResourceProperties, Equatable {

  public var queueByArn: String? = nil
  public var queue: Resource<ResourceType>? = nil

  init(byRef ref: String) {

    // when the ref is an ARN, leave it as it, otherwise, create a queue resource and pass a reference to it
    if let arn = Arn(ref)?.arn {
      self.queueByArn = arn
    } else {
      let logicalName = Resource<EventSourceType>.logicalName(
        resourceType: "Queue",
        resourceName: ref)
      self.queue = Resource<ResourceType>.queue(
        name: logicalName,
        properties: SQSResourceProperties(queueName: ref))
    }

  }
  init(_ queue: Resource<ResourceType>) { self.queue = queue }

  enum CodingKeys: String, CodingKey {
    case queue = "Queue"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    // if we have an Arn, return the Arn, otherwise pass a reference with GetAtt
    // https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-sqs.html#sam-function-sqs-queue
    if let queueByArn {
      try container.encode(queueByArn, forKey: .queue)
    } else if let queue {
      var getAttIntrinsicFunction: [String: [String]] = [:]
      getAttIntrinsicFunction["Fn::GetAtt"] = [queue.name, "Arn"]
      try container.encode(getAttIntrinsicFunction, forKey: .queue)
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
  internal static func queue(
    name: String,
    properties: SQSResourceProperties
  ) -> Resource<ResourceType> {

    return Resource<ResourceType>(
      type: .queue,
      properties: properties,
      name: name)
  }

  public static func queue(
    logicalName: String,
    physicalName: String
  ) -> Resource<ResourceType> {

    let sqsProperties = SQSResourceProperties(queueName: physicalName)
    return queue(name: logicalName, properties: sqsProperties)
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
  internal static func table(
    name: String,
    properties: SimpleTableProperties
  ) -> Resource<ResourceType> {

    return Resource<ResourceType>(
      type: .table,
      properties: properties,
      name: name)
  }
  public static func table(
    logicalName: String,
    physicalName: String,
    primaryKeyName: String,
    primaryKeyType: String
  ) -> Resource<ResourceType> {
    let primaryKey = SimpleTableProperties.PrimaryKey(name: primaryKeyName, type: primaryKeyType)
    let properties = SimpleTableProperties(primaryKey: primaryKey, tableName: physicalName)
    return table(name: logicalName, properties: properties)
  }
}

public struct SimpleTableProperties: SAMResourceProperties {
  let primaryKey: PrimaryKey
  let tableName: String
  let provisionedThroughput: ProvisionedThroughput? = nil
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try? container.encode(tableName, forKey: .tableName)
    try? container.encode(primaryKey, forKey: .primaryKey)
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

//MARK: Utils

struct Arn {
  public let arn: String
  init?(_ arn: String) {
    // Arn regex from https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-eventsourcemapping.html#cfn-lambda-eventsourcemapping-eventsourcearn
    let arnRegex =
      #"arn:(aws[a-zA-Z0-9-]*):([a-zA-Z0-9\-])+:([a-z]{2}(-gov)?-[a-z]+-\d{1})?:(\d{12})?:(.*)"#
    if arn.range(of: arnRegex, options: .regularExpression) != nil {
      self.arn = arn
    } else {
      return nil
    }
  }
}

extension Resource {
  // Transform resourceName :
  // remove space
  // remove hyphen
  // camel case
  static func logicalName(resourceType: String, resourceName: String) -> String {
    let noSpaceName = resourceName.split(separator: " ").map { $0.capitalized }.joined(
      separator: "")
    let noHyphenName = noSpaceName.split(separator: "-").map { $0.capitalized }.joined(
      separator: "")
    return resourceType.capitalized + noHyphenName
  }
}
