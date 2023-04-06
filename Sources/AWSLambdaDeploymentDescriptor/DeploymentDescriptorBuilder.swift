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

// global state for serialization
// This is required because `atexit` can not capture self
private var _deploymentDescriptor: SAMDeploymentDescriptor?

// a top level DeploymentDescriptor DSL
@resultBuilder
public struct DeploymentDescriptor {

    // capture the deployment descriptor for unit tests
    let samDeploymentDescriptor: SAMDeploymentDescriptor

    // MARK: Generation of the SAM Deployment Descriptor

    private init(
        description: String = "A SAM template to deploy a Swift Lambda function",
        resources: [Resource<ResourceType>]
    ) {

        self.samDeploymentDescriptor = SAMDeploymentDescriptor(
            description: description,
            resources: resources
        )

        // and register it for serialization
        _deploymentDescriptor = self.samDeploymentDescriptor

        // at exit of this process,
        // we flush a YAML representation of the deployment descriptor to stdout
        atexit {
            try! DeploymentDescriptorSerializer.serialize(_deploymentDescriptor!, format: .yaml)
        }
    }

    // MARK: resultBuilder specific code

    // this initializer allows to declare a top level `DeploymentDescriptor { }``
    @discardableResult
    public init(@DeploymentDescriptor _ builder: () -> DeploymentDescriptor) {
        self = builder()
    }
    public static func buildBlock(_ description: String,
                                  _ resources: [Resource<ResourceType>]...) -> (String?, [Resource<ResourceType>]) {
        return (description, resources.flatMap { $0 })
    }
    public static func buildBlock(_ resources: [Resource<ResourceType>]...) -> (String?, [Resource<ResourceType>]) {
        return (nil, resources.flatMap { $0 })
    }
    public static func buildFinalResult(_ function: (String?, [Resource<ResourceType>])) -> DeploymentDescriptor {
        if let description = function.0 {
            return DeploymentDescriptor(description: description, resources: function.1)
        } else {
            return DeploymentDescriptor(resources: function.1)
        }
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
    public static func buildExpression(_ expression: Resource<ResourceType>) -> [Resource<ResourceType>] {
        return [expression]
    }
}

// MARK: Function resource

public struct Function {
    let name: String
    let architecture: Architectures
    let codeURI: String?
    let eventSources: [Resource<EventSourceType>]
    let environment: [String: String]

    enum FunctionError: Error, CustomStringConvertible {
        case packageDoesNotExist(String)

        var description: String {
            switch self {
            case .packageDoesNotExist(let pkg):
                return "Package \(pkg) does not exist"
            }
        }
    }

    private init(
        name: String,
        architecture: Architectures = Architectures.defaultArchitecture(),
        codeURI: String?,
        eventSources: [Resource<EventSourceType>] = [],
        environment: [String: String] = [:]
    ) {
        self.name = name
        self.architecture = architecture
        self.codeURI = codeURI
        self.eventSources = eventSources
        self.environment = environment
    }
    public init(
        name: String,
        architecture: Architectures = Architectures.defaultArchitecture(),
        codeURI: String? = nil,
        @FunctionBuilder _ builder: () -> (EventSources, [String: String])
    ) {

        let (eventSources, environmentVariables) = builder()
        let samEventSource: [Resource<EventSourceType>] = eventSources.samEventSources()
        self.init(
            name: name,
            architecture: architecture,
            codeURI: codeURI,
            eventSources: samEventSource,
            environment: environmentVariables)
    }

    // this method fails when the package does not exist at path
    internal func resources() -> [Resource<ResourceType>] {

        let properties = ServerlessFunctionProperties(
            codeUri: try! packagePath(),
            architecture: self.architecture,
            eventSources: self.eventSources,
            environment: SAMEnvironmentVariable(self.environment))

        let functionResource = [Resource<ResourceType>(
            type: .serverlessFunction,
            properties: properties,
            name: name)]

        let additionalQueueResources = collectQueueResources()

        return functionResource + additionalQueueResources
    }

    // compute the path for the lambda archive
    // package path comes from three sources with this priority
    // 1. the --archive-path arg
    // 2. the developer supplied value in Function() definition
    // 3. a default value
    // func is public for testability
    public func packagePath() throws -> String {

        // propose a default path unless the --archive-path argument was used
        // --archive-path argument value must match the value given to the archive plugin --output-path argument
        var lambdaPackage =
        ".build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/\(self.name)/\(self.name).zip"
        if let path = self.codeURI {
            lambdaPackage = path
        }
        if let optIdx = CommandLine.arguments.firstIndex(of: "--archive-path") {
            if CommandLine.arguments.count >= optIdx + 1 {
                let archiveArg = CommandLine.arguments[optIdx + 1]
                lambdaPackage = "\(archiveArg)/\(self.name)/\(self.name).zip"
            }
        }

        // check the ZIP file exists
        if !FileManager.default.fileExists(atPath: lambdaPackage) {
            throw FunctionError.packageDoesNotExist(lambdaPackage)
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
        public static func buildBlock(_ events: EventSources) -> (EventSources, [String: String]) {
            return (events, [:])
        }
        public static func buildBlock(_ events: EventSources,
                                      _ variables: EnvironmentVariables) -> (EventSources, [String: String]) {
            return (events, variables.environmentVariables)
        }
        public static func buildBlock(_ variables: EnvironmentVariables,
                                      _ events: EventSources) -> (EventSources, [String: String]) {
            return (events, variables.environmentVariables)
        }
        @available(*, unavailable, message: "Only one EnvironmentVariables block is allowed")
        public static func buildBlock(_ events: EventSources,
                                      _ components: EnvironmentVariables...) -> (EventSources, [String: String]) {
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
        public static func buildBlock(_ source: Resource<EventSourceType>...) -> [Resource<EventSourceType>] {
            return source.compactMap { $0 }
        }
        public static func buildExpression(_ expression: HttpApi) -> Resource<EventSourceType> {
            return expression.resource()
        }
        public static func buildExpression(_ expression: Sqs) -> Resource<EventSourceType> {
            return expression.resource()
        }
        public static func buildExpression(_ expression: Resource<EventSourceType>) -> Resource<EventSourceType> {
            return expression
        }
    }
}

// MARK: HttpApi event source
public struct HttpApi {
    private let method: HttpVerb?
    private let path: String?
    private let name: String = "HttpApiEvent"
    public init(
        method: HttpVerb? = nil,
        path: String? = nil
    ) {
        self.method = method
        self.path = path
    }
    internal func resource() -> Resource<EventSourceType> {

        var properties: SAMResourceProperties?
        if self.method != nil || self.path != nil {
            properties = HttpApiProperties(method: method, path: path)
        }

        return Resource<EventSourceType>(
            type: .httpApi,
            properties: properties,
            name: name)
    }
}

// MARK: SQS Event Source
public struct Sqs {
    private let name: String
    private var queueRef: String?
    private var queue: Queue?
    public var batchSize: Int = 10
    public var enabled: Bool = true

    public init(name: String = "SQSEvent") {
        self.name = name
    }
    public init(name: String = "SQSEvent",
                _ queue: String,
                batchSize: Int = 10,
                enabled: Bool = true) {
        self.name = name
        self.queueRef = queue
        self.batchSize = batchSize
        self.enabled = enabled
    }
    public init(name: String = "SQSEvent",
                _ queue: Queue,
                batchSize: Int = 10,
                enabled: Bool = true) {
        self.name = name
        self.queue = queue
        self.batchSize = batchSize
        self.enabled = enabled
    }
    public func queue(logicalName: String, physicalName: String) -> Sqs {
        let queue = Queue(logicalName: logicalName, physicalName: physicalName)
        return Sqs(name: self.name, queue)
    }
    internal func resource() -> Resource<EventSourceType> {
        var properties: SQSEventProperties! = nil
        if self.queue != nil {
            properties = SQSEventProperties(self.queue!.resource(),
                                            batchSize: self.batchSize,
                                            enabled: self.enabled)

        } else if self.queueRef != nil {

            properties = SQSEventProperties(byRef: self.queueRef!,
                                            batchSize: batchSize,
                                            enabled: enabled)
        } else {
            fatalError("Either queue or queueRef muts have a value")
        }

        return Resource<EventSourceType>(
            type: .sqs,
            properties: properties,
            name: name)
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

        let properties = SQSResourceProperties(queueName: self.physicalName)

        return Resource<ResourceType>(
                    type: .queue,
                    properties: properties,
                    name: self.logicalName)
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

        let primaryKey = SimpleTableProperties.PrimaryKey(name: primaryKeyName,
                                                          type: primaryKeyType)
        let properties = SimpleTableProperties(primaryKey: primaryKey,
                                               tableName: physicalName)
        return Resource<ResourceType>(
            type: .table,
            properties: properties,
            name: logicalName)
    }
}

// MARK: Serialization code

extension SAMDeploymentDescriptor {

    internal func toJSON(pretty: Bool = true) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        if pretty {
            encoder.outputFormatting = [encoder.outputFormatting, .prettyPrinted]
        }
        let jsonData = try! encoder.encode(self)
        return String(data: jsonData, encoding: .utf8)!
    }

    internal func toYAML() -> String {
        let yaml = try! YAMLEncoder().encode(self)
        return String(data: yaml, encoding: .utf8)!
    }
}

private struct DeploymentDescriptorSerializer {

    enum SerializeFormat {
        case json
        case yaml
    }

    // dump the JSON representation of the deployment descriptor to the given file descriptor
    // by default, it outputs on fileDesc = 1, which is stdout
    static func serialize(_ deploymentDescriptor: SAMDeploymentDescriptor,
                          format: SerializeFormat,
                          to fileDesc: Int32 = 1
    ) throws {

        // do not output the deployment descriptor on stdout when running unit tests
        if Thread.current.isRunningXCTest { return }

        guard let fd = fdopen(fileDesc, "w") else { return }
        switch format {
        case .json: fputs(deploymentDescriptor.toJSON(), fd)
        case .yaml: fputs(deploymentDescriptor.toYAML(), fd)
        }

        fclose(fd)
    }
}

// MARK: Support code for unit testing
// Detect when running inside a unit test
// This allows to avoid calling `fatalError()` or to print the deployment descriptor when unit testing
// inspired from https://stackoverflow.com/a/59732115/663360
extension Thread {
    var isRunningXCTest: Bool {
        self.threadDictionary.allKeys
            .contains {
                ($0 as? String)?
                    .range(of: "XCTest", options: .caseInsensitive) != nil
            }
    }
}
