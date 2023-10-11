// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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
    description: String,
    resources: [Resource<ResourceType>] = []
  ) {
    self.description = description

    // extract resources names for serialization
    for res in resources {
      self.resources[res.name] = res
    }
  }

  enum CodingKeys: String, CodingKey {
    case templateVersion = "AWSTemplateFormatVersion"
    case transform
    case description
    case resources
  }
}

public protocol SAMResource: Encodable {}
public protocol SAMResourceType: Encodable, Equatable {}
public protocol SAMResourceProperties: Encodable {}

public enum ResourceType: SAMResourceType {

  case type(_ name: String)

  static var serverlessFunction: Self { .type("AWS::Serverless::Function") }
  static var queue: Self { .type("AWS::SQS::Queue") }
  static var table: Self { .type("AWS::Serverless::SimpleTable") }

  public func encode(to encoder: Encoder) throws {
    if case let .type(value) = self {
      var container = encoder.singleValueContainer()
      try? container.encode(value)
    }
  }
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

  enum CodingKeys: CodingKey {
    case type
    case properties
  }

  // this is to make the compiler happy : Resource now conforms to Encodable
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.type, forKey: .type)
    if let properties = self.properties {
      try container.encode(properties, forKey: .properties)
    }
  }
}

// MARK: Lambda Function resource definition

/*---------------------------------------------------------------------------------------
 Lambda Function

 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-function.html
 -----------------------------------------------------------------------------------------*/

public struct ServerlessFunctionProperties: SAMResourceProperties {

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

  // https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-lambda-function-ephemeralstorage.html
  public struct EphemeralStorage: Encodable {
    private let validValues = 512...10240
    let size: Int
    init?(_ size: Int) {
      if validValues.contains(size) {
        self.size = size
      } else {
        return nil
      }
    }
    enum CodingKeys: String, CodingKey {
      case size = "Size"
    }
  }

  public struct EventInvokeConfiguration: Encodable {
    public enum EventInvokeDestinationType: String, Encodable {
      case sqs = "SQS"
      case sns = "SNS"
      case lambda = "Lambda"
      case eventBridge = "EventBridge"

      public static func destinationType(from arn: Arn?) -> EventInvokeDestinationType? {
        guard let service = arn?.service() else {
          return nil
        }
        switch service.lowercased() {
        case "sqs":
          return .sqs
        case "sns":
          return .sns
        case "lambda":
          return .lambda
        case "eventbridge":
          return .eventBridge
        default:
          return nil
        }
      }
      public static func destinationType(from resource: Resource<ResourceType>?)
        -> EventInvokeDestinationType?
      {
        guard let res = resource else {
          return nil
        }
        switch res.type {
        case .queue:
          return .sqs
        case .serverlessFunction:
          return .lambda
        default:
          return nil
        }
      }
    }
    public struct EventInvokeDestination: Encodable {
      let destination: Reference?
      let type: EventInvokeDestinationType?
    }
    public struct EventInvokeDestinationConfiguration: Encodable {
      let onSuccess: EventInvokeDestination?
      let onFailure: EventInvokeDestination?
    }
    let destinationConfig: EventInvokeDestinationConfiguration?
    let maximumEventAgeInSeconds: Int?
    let maximumRetryAttempts: Int?
  }

  //TODO: add support for reference to other resources of type elasticfilesystem or mountpoint
  public struct FileSystemConfig: Encodable {

    // regex from
    // https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-lambda-function-filesystemconfig.html
    let validMountPathRegex = #"^/mnt/[a-zA-Z0-9-_.]+$"#
    let validArnRegex =
      #"arn:aws[a-zA-Z-]*:elasticfilesystem:[a-z]{2}((-gov)|(-iso(b?)))?-[a-z]+-\d{1}:\d{12}:access-point/fsap-[a-f0-9]{17}"#
    let reference: Reference
    let localMountPath: String

    public init?(arn: String, localMountPath: String) {

      guard arn.range(of: validArnRegex, options: .regularExpression) != nil,
        localMountPath.range(of: validMountPathRegex, options: .regularExpression) != nil
      else {
        return nil
      }

      self.reference = .arn(Arn(arn)!)
      self.localMountPath = localMountPath
    }
    enum CodingKeys: String, CodingKey {
      case reference = "Arn"
      case localMountPath
    }
  }

  public struct URLConfig: Encodable {
    public enum AuthType: String, Encodable {
      case iam = "AWS_IAM"
      case none = "None"
    }
    public enum InvokeMode: String, Encodable {
      case responseStream = "RESPONSE_STREAM"
      case buffered = "BUFFERED"
    }
    public struct Cors: Encodable {
      let allowCredentials: Bool?
      let allowHeaders: [String]?
      let allowMethods: [String]?
      let allowOrigins: [String]?
      let exposeHeaders: [String]?
      let maxAge: Int?
    }
    let authType: AuthType
    let cors: Cors?
    let invokeMode: InvokeMode?
  }

  let architectures: [Architectures]
  let handler: String
  let runtime: String
  let codeUri: String?
  var autoPublishAlias: String?
  var autoPublishAliasAllProperties: Bool?
  var autoPublishCodeSha256: String?
  var events: [String: Resource<EventSourceType>]?
  var environment: SAMEnvironmentVariable?
  var description: String?
  var ephemeralStorage: EphemeralStorage?
  var eventInvokeConfig: EventInvokeConfiguration?
  var fileSystemConfigs: [FileSystemConfig]?
  var functionUrlConfig: URLConfig?

  public init(
    codeUri: String?,
    architecture: Architectures,
    eventSources: [Resource<EventSourceType>] = [],
    environment: SAMEnvironmentVariable? = nil
  ) {

    self.architectures = [architecture]
    self.handler = "Provided"
    self.runtime = "provided.al2"  // Amazon Linux 2 supports both arm64 and x64
    self.codeUri = codeUri
    self.environment = environment

    if !eventSources.isEmpty {
      self.events = [:]
      for es in eventSources {
        self.events![es.name] = es
      }
    }
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

  enum CodingKeys: CodingKey {
    case variables
  }

  public func encode(to encoder: Encoder) throws {

    guard !self.isEmpty() else {
      return
    }

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
}

internal struct AnyStringKey: CodingKey, Hashable, ExpressibleByStringLiteral {
  var stringValue: String
  init(stringValue: String) { self.stringValue = stringValue }
  init(_ stringValue: String) { self.init(stringValue: stringValue) }
  var intValue: Int?
  init?(intValue: Int) { return nil }
  init(stringLiteral value: String) { self.init(value) }
}

// MARK: HTTP API Event definition
/*---------------------------------------------------------------------------------------
 HTTP API Event (API Gateway v2)

 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-httpapi.html
 -----------------------------------------------------------------------------------------*/

struct HttpApiProperties: SAMResourceProperties, Equatable {
  init(method: HttpVerb? = nil, path: String? = nil) {
    self.method = method
    self.path = path
  }
  let method: HttpVerb?
  let path: String?
}

public enum HttpVerb: String, Encodable {
  case GET
  case POST
  case PUT
  case DELETE
  case OPTION
}

// MARK: SQS event definition
/*---------------------------------------------------------------------------------------
 SQS Event

 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-sqs.html
 -----------------------------------------------------------------------------------------*/

/// Represents SQS queue properties.
/// When `queue` name  is a shorthand YAML reference to another resource, like `!GetAtt`, it splits the shorthand into proper YAML to make the parser happy
public struct SQSEventProperties: SAMResourceProperties, Equatable {

  public var reference: Reference
  public var batchSize: Int
  public var enabled: Bool

  init(
    byRef ref: String,
    batchSize: Int,
    enabled: Bool
  ) {

    // when the ref is an ARN, leave it as it, otherwise, create a queue resource and pass a reference to it
    if let arn = Arn(ref) {
      self.reference = .arn(arn)
    } else {
      let logicalName = Resource<EventSourceType>.logicalName(
        resourceType: "Queue",
        resourceName: ref)
      let queue = Resource<ResourceType>(
        type: .queue,
        properties: SQSResourceProperties(queueName: ref),
        name: logicalName)
      self.reference = .resource(queue)
    }
    self.batchSize = batchSize
    self.enabled = enabled
  }

  init(
    _ queue: Resource<ResourceType>,
    batchSize: Int,
    enabled: Bool
  ) {

    self.reference = .resource(queue)
    self.batchSize = batchSize
    self.enabled = enabled
  }

  enum CodingKeys: String, CodingKey {
    case reference = "Queue"
    case batchSize
    case enabled
  }
}

// MARK: SQS queue resource definition
/*---------------------------------------------------------------------------------------
 SQS Queue Resource

 Documentation
 https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-sqs-queue.html
 -----------------------------------------------------------------------------------------*/

public struct SQSResourceProperties: SAMResourceProperties {
  public let queueName: String
}

// MARK: Simple DynamoDB table resource definition
/*---------------------------------------------------------------------------------------
 Simple DynamoDB Table Resource

 Documentation
 https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-simpletable.html
 -----------------------------------------------------------------------------------------*/

public struct SimpleTableProperties: SAMResourceProperties {
  let primaryKey: PrimaryKey
  let tableName: String
  var provisionedThroughput: ProvisionedThroughput? = nil
  struct PrimaryKey: Codable {
    let name: String
    let type: String
  }
  struct ProvisionedThroughput: Codable {
    let readCapacityUnits: Int
    let writeCapacityUnits: Int
  }
}

// MARK: Utils

public struct Arn: Encodable {
  public let arn: String

  // Arn regex from https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-eventsourcemapping.html#cfn-lambda-eventsourcemapping-eventsourcearn
  private let arnRegex =
    #"arn:(aws[a-zA-Z0-9-]*):([a-zA-Z0-9\-]+):([a-z]{2}(-gov)?-[a-z]+-\d{1})?:(\d{12})?:(.*)"#

  public init?(_ arn: String) {
    if arn.range(of: arnRegex, options: .regularExpression) != nil {
      self.arn = arn
    } else {
      return nil
    }
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.arn)
  }
  public func service() -> String? {
    var result: String? = nil

    if #available(macOS 13, *) {
      let regex = try! Regex(arnRegex)
      if let matches = try? regex.wholeMatch(in: self.arn),
        matches.count > 3,
        let substring = matches[2].substring
      {
        result = "\(substring)"
      }
    } else {
      let split = self.arn.split(separator: ":")
      if split.count > 3 {
        result = "\(split[2])"
      }
    }

    return result
  }
}

public enum Reference: Encodable, Equatable {
  case arn(Arn)
  case resource(Resource<ResourceType>)

  // if we have an Arn, return the Arn, otherwise pass a reference with GetAtt
  // https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-sqs.html#sam-function-sqs-queue
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .arn(let arn):
      try container.encode(arn)
    case .resource(let resource):
      var getAttIntrinsicFunction: [String: [String]] = [:]
      getAttIntrinsicFunction["Fn::GetAtt"] = [resource.name, "Arn"]
      try container.encode(getAttIntrinsicFunction)
    }
  }

  public static func == (lhs: Reference, rhs: Reference) -> Bool {
    switch lhs {
    case .arn(let lArn):
      if case let .arn(rArn) = rhs {
        return lArn.arn == rArn.arn
      } else {
        return false
      }
    case .resource(let lResource):
      if case let .resource(rResource) = lhs {
        return lResource == rResource
      } else {
        return false
      }
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
