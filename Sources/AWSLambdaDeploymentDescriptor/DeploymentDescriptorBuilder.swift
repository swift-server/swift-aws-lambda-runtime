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
import Yams

// global state for serialization
// This is required because `atexit` can not capture self
private var __deploymentDescriptor: SAMDeploymentDescriptor?

// a top level DeploymentDescriptor DSL
@resultBuilder
public struct DeploymentDescriptor {

  // MARK: Generation of the SAM Deployment Descriptor

  private init(
    description: String,
    resources: [Resource<ResourceType>]
  ) {

    // create SAM deployment descriptor and register it for serialization
    __deploymentDescriptor = SAMDeploymentDescriptor(
      description: description,
      resources: resources)

    // at exit of this process,
    // we flush a YAML representation of the deployment descriptor to stdout
    atexit {
      try! DeploymentDescriptorSerializer.serialize(__deploymentDescriptor!, format: .yaml)
    }
  }

  // MARK: resultBuilder specific code

  // this initializer allows to declare a top level `DeploymentDescriptor { }``
  @discardableResult
  public init(@DeploymentDescriptor _ builder: () -> DeploymentDescriptor) {
    self = builder()
  }
  public static func buildBlock(_ description: String, _ resources: [Resource<ResourceType>]...)
    -> (String, [Resource<ResourceType>])
  {
    return (description, resources.flatMap { $0 })
  }
  @available(
    *, unavailable,
    message: "The first statement of DeploymentDescriptor must be its description String"
  )
  public static func buildBlock(_ resources: [Resource<ResourceType>]...) -> (
    String, [Resource<ResourceType>]
  ) {
    fatalError()
  }
  public static func buildFinalResult(_ function: (String, [Resource<ResourceType>]))
    -> DeploymentDescriptor
  {
    return DeploymentDescriptor(description: function.0, resources: function.1)
  }
  public static func buildExpression(_ expression: String) -> String {
    return expression
  }
  public static func buildExpression(_ expression: Function) -> [Resource<ResourceType>] {
    return expression.resources()
  }
  public static func buildExpression(_ expression: Queue) -> [Resource<ResourceType>] {
    return [expression.resource()]
  }
  public static func buildExpression(_ expression: Table) -> [Resource<ResourceType>] {
    return [expression.resource()]
  }
  public static func buildExpression(_ expression: Resource<ResourceType>) -> [Resource<
    ResourceType
  >] {
    return [expression]
  }
}

// MARK: Function resource

public struct Function {
  let name: String
  let architecture: Architectures
  let eventSources: [Resource<EventSourceType>]
  let environment: [String: String]

  private init(
    name: String,
    architecture: Architectures = Architectures.defaultArchitecture(),
    eventSources: [Resource<EventSourceType>] = [],
    environment: [String: String] = [:]
  ) {
    self.name = name
    self.architecture = architecture
    self.eventSources = eventSources
    self.environment = environment
  }
  public init(
    name: String,
    architecture: Architectures = Architectures.defaultArchitecture(),
    @FunctionBuilder _ builder: () -> (EventSources, [String: String])
  ) {

    let (eventSources, environmentVariables) = builder()
    let samEventSource: [Resource<EventSourceType>] = eventSources.samEventSources()
    self.init(
      name: name,
      architecture: architecture,
      eventSources: samEventSource,
      environment: environmentVariables)
  }

  internal func resources() -> [Resource<ResourceType>] {

    let functionResource = [
      Resource<ResourceType>.serverlessFunction(
        name: self.name,
        architecture: self.architecture,
        codeUri: packagePath(),
        eventSources: self.eventSources,
        environment: SAMEnvironmentVariable(self.environment))
    ]
    let additionalQueueResources = collectQueueResources()

    return functionResource + additionalQueueResources
  }

  // compute the path for the lambda archive
  private func packagePath() -> String {

    // propose a default path unless the --archive-path argument was used
    // --archive-path argument value must match the value given to the archive plugin --output-path argument
    var lambdaPackage =
      ".build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/\(self.name)/\(self.name).zip"
    if let optIdx = CommandLine.arguments.firstIndex(of: "--archive-path") {
      if CommandLine.arguments.count >= optIdx + 1 {
        let archiveArg = CommandLine.arguments[optIdx + 1]
        lambdaPackage = "\(archiveArg)/\(self.name)/\(self.name).zip"
      }
    }

    // check the ZIP file exists
    if !FileManager.default.fileExists(atPath: lambdaPackage) {
      // TODO: add support for fatalError() in unit tests
      fatalError("Error: package does not exist at path: \(lambdaPackage)")
    }

    return lambdaPackage
  }

  // When SQS event source is specified, the Lambda function developer
  // might give a queue name, a queue Arn, or a queue resource.
  // When developer gives a queue Arn there is nothing to do here
  // When developer gives a queue name or a queue resource,
  // the event source automatically creates the queue Resource and returns a reference to the Resource it has created
  // This function collects all queue resources created by SQS event sources or passed by Lambda function developer
  // to add them to the list of resources to synthesize
  private func collectQueueResources() -> [Resource<ResourceType>] {

    return self.eventSources
      // first filter on event sources of type SQS where the `queue` property is defined (not nil)
      .filter { lambdaEventSource in
        lambdaEventSource.type == .sqs
          && (lambdaEventSource.properties as? SQSEventProperties)?.queue != nil
      }
      // next extract the queue resource part of the sqsEventSource
      .compactMap {
        sqsEventSource in (sqsEventSource.properties as? SQSEventProperties)?.queue
      }
  }

  // MARK: Function DSL code
  @resultBuilder
  public enum FunctionBuilder {
    public static func buildBlock(_ events: EventSources, _ variables: EnvironmentVariables) -> (
      EventSources, [String: String]
    ) {
      return (events, variables.environmentVariables)
    }
    public static func buildBlock(_ variables: EnvironmentVariables, _ events: EventSources) -> (
      EventSources, [String: String]
    ) {
      return (events, variables.environmentVariables)
    }
    @available(*, unavailable, message: "Only one EnvironmentVariables block is allowed")
    public static func buildBlock(_ events: EventSources, _ components: EnvironmentVariables...)
      -> (EventSources, [String: String])
    {
      fatalError()
    }
  }

}

// MARK: Event Source
public struct EventSources {
  private let eventSources: [Resource<EventSourceType>]
  public init(@EventSourceBuilder _ builder: () -> [Resource<EventSourceType>]) {
    self.eventSources = builder()
  }
  internal func samEventSources() -> [Resource<EventSourceType>] {
    return self.eventSources
  }
  // MARK: EventSources DSL code
  @resultBuilder
  public enum EventSourceBuilder {
    public static func buildBlock(_ source: Resource<EventSourceType>...) -> [Resource<
      EventSourceType
    >] {
      return source.compactMap { $0 }
    }
    public static func buildExpression(_ expression: HttpApi) -> Resource<EventSourceType> {
      return expression.resource()
    }
    public static func buildExpression(_ expression: Sqs) -> Resource<EventSourceType> {
      return expression.resource()
    }
  }
}

// MARK: HttpApi event source
public struct HttpApi {
  private let method: HttpVerb?
  private let path: String?
  public init(
    method: HttpVerb? = nil,
    path: String? = nil
  ) {
    self.method = method
    self.path = path
  }
  internal func resource() -> Resource<EventSourceType> {
    return Resource<EventSourceType>.httpApi(method: self.method, path: self.path)
  }
}

// MARK: SQS Event Source
public struct Sqs {
  private let name: String
  private var queueRef: String? = nil
  private var queue: Queue? = nil
  public init(name: String = "SQSEvent") {
    self.name = name
  }
  public init(name: String = "SQSEvent", _ queue: String) {
    self.name = name
    self.queueRef = queue
  }
  public init(name: String = "SQSEvent", _ queue: Queue) {
    self.name = name
    self.queue = queue
  }
  public func queue(logicalName: String, physicalName: String) -> Sqs {
    let queue = Queue(logicalName: logicalName, physicalName: physicalName)
    return Sqs(name: self.name, queue)
  }
  internal func resource() -> Resource<EventSourceType> {
    if self.queue != nil {
      return Resource<EventSourceType>.sqs(name: self.name, queue: self.queue!.resource())
    } else if self.queueRef != nil {
      return Resource<EventSourceType>.sqs(name: self.name, queue: self.queueRef!)
    } else {
      fatalError("Either queue or queueRef muts have a value")
    }
  }
}

// MARK: Environment Variable
public struct EnvironmentVariables {

  internal let environmentVariables: [String: String]

  // MARK: EnvironmentVariable DSL code
  public init(@EnvironmentVariablesBuilder _ builder: () -> [String: String]) {
    self.environmentVariables = builder()
  }

  @resultBuilder
  public enum EnvironmentVariablesBuilder {
    public static func buildBlock(_ variables: [String: String]...) -> [String: String] {

      // merge an array of dictionaries into a single dictionary.
      // existing values are preserved
      var mergedDictKeepCurrent: [String: String] = [:]
      variables.forEach { dict in
        mergedDictKeepCurrent = mergedDictKeepCurrent.merging(dict) { (current, _) in current }
      }
      return mergedDictKeepCurrent
    }
  }
}

// MARK: Queue top level resource
public struct Queue {
  let logicalName: String
  let physicalName: String
  public init(logicalName: String, physicalName: String) {
    self.logicalName = logicalName
    self.physicalName = physicalName
  }
  internal func resource() -> Resource<ResourceType> {
    return Resource<ResourceType>.queue(
      logicalName: self.logicalName,
      physicalName: self.physicalName)
  }
}

// MARK: Table top level resource
public struct Table {
  let logicalName: String
  let physicalName: String
  let primaryKeyName: String
  let primaryKeyType: String
  public init(
    logicalName: String,
    physicalName: String,
    primaryKeyName: String,
    primaryKeyType: String
  ) {

    self.logicalName = logicalName
    self.physicalName = physicalName
    self.primaryKeyName = primaryKeyName
    self.primaryKeyType = primaryKeyType
  }
  internal func resource() -> Resource<ResourceType> {
    return Resource<ResourceType>.table(
      logicalName: self.logicalName,
      physicalName: self.physicalName,
      primaryKeyName: self.primaryKeyName,
      primaryKeyType: self.primaryKeyType)
  }
}

// MARK: Serialization code

extension SAMDeploymentDescriptor {

  fileprivate func toJSON(pretty: Bool = true) -> String {
    let encoder = JSONEncoder()
    if pretty {
      encoder.outputFormatting = .prettyPrinted
    }
    let jsonData = try! encoder.encode(self)
    return String(data: jsonData, encoding: .utf8)!
  }

  fileprivate func toYAML() -> String {
    let yaml = try! YAMLEncoder().encode(self)
    return yaml
  }
}

private struct DeploymentDescriptorSerializer {

  enum SerializeFormat {
    case json
    case yaml
  }

  // dump the JSON representation of the deployment descriptor to the given file descriptor
  // by default, it outputs on fileDesc = 1, which is stdout
  static func serialize(
    _ deploymentDescriptor: SAMDeploymentDescriptor, format: SerializeFormat, to fileDesc: Int32 = 1
  ) throws {
    guard let fd = fdopen(fileDesc, "w") else { return }
    switch format {
    case .json: fputs(deploymentDescriptor.toJSON(), fd)
    case .yaml: fputs(deploymentDescriptor.toYAML(), fd)
    }

    fclose(fd)
  }
}
