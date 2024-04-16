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
struct DeploymentDescriptor {
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

    public static func buildBlock(
        _ description: String,
        _ resources: [Resource<ResourceType>]...
    ) -> (String?, [Resource<ResourceType>]) {
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
        expression
    }

    static func buildExpression(_ expression: any BuilderResource) -> [Resource<ResourceType>] {
        expression.resource()
    }

}

internal protocol BuilderResource {
  func resource() -> [Resource<ResourceType>]
}

// MARK: Function resource

public struct Function: BuilderResource {
    private let _underlying: Resource<ResourceType>

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
        _ name: String,
        properties: ServerlessFunctionProperties
    ) {
        self._underlying = Resource<ResourceType>(
                type: .function,
                properties: properties,
                name: name
            )
    }
    
    public init(
        name: String,
        architecture: ServerlessFunctionProperties.Architectures = .defaultArchitecture(),
        codeURI: String? = nil,
        eventSources: [Resource<EventSourceType>] = [],
        environment: [String: String] = [:],
        description: String? = nil
    ) {
        var props = ServerlessFunctionProperties(
            codeUri: try! Function.packagePath(name: name, codeUri: codeURI),
            architecture: architecture,
            eventSources: eventSources,
            environment: environment.isEmpty ? nil : SAMEnvironmentVariable(environment)
        )
        props.description = description

        self.init(name, properties: props)
    }

    public init(
        name: String,
        architecture: ServerlessFunctionProperties.Architectures = .defaultArchitecture(),
        codeURI: String? = nil
    ) {
        let props = ServerlessFunctionProperties(
            codeUri: try! Function.packagePath(name: name, codeUri: codeURI),
            architecture: architecture
        )
        self.init(name, properties: props)
    }

    public init(
        name: String,
        architecture: ServerlessFunctionProperties.Architectures = .defaultArchitecture(),
        codeURI: String? = nil,
        @FunctionBuilder _ builder: () -> (String?, EventSources, [String: String])
    ) {
        let (description, eventSources, environmentVariables) = builder()
        let samEventSource: [Resource<EventSourceType>] = eventSources.samEventSources()
        self.init(
            name: name,
            architecture: architecture,
            codeURI: codeURI,
            eventSources: samEventSource,
            environment: environmentVariables,
            description: description
        )
    }

    // this method fails when the package does not exist at path
    internal func resource() -> [Resource<ResourceType>] {
        let functionResource = [ self._underlying ]
        let additionalQueueResources = self.collectQueueResources()

        return functionResource + additionalQueueResources
    }

    // compute the path for the lambda archive
    // package path comes from three sources with this priority
    // 1. the --archive-path arg
    // 2. the developer supplied value in Function() definition
    // 3. a default value
    // func is public for testability
    internal static func packagePath(name: String, codeUri: String?) throws -> String {
        // propose a default path unless the --archive-path argument was used
        // --archive-path argument value must match the value given to the archive plugin --output-path argument
        var lambdaPackage =
            ".build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/\(name)/\(name).zip"
        if let path = codeUri {
            lambdaPackage = path
        }
        if let optIdx = CommandLine.arguments.firstIndex(of: "--archive-path") {
            if CommandLine.arguments.count >= optIdx + 1 {
                let archiveArg = CommandLine.arguments[optIdx + 1]
                lambdaPackage = "\(archiveArg)/\(name)/\(name).zip"
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
        guard let events = properties().events else {
            return []
        }
        return events.values.compactMap { $0 }
            // first filter on event sources of type SQS where the reference is a `queue` resource
            .filter { lambdaEventSource in
                lambdaEventSource.type == .sqs
                //                var result = false
                //                if case .resource(_) = (lambdaEventSource.properties as? SQSEventProperties)?.reference {
                //                    result = lambdaEventSource.type == .sqs
                //                }
                //                return result
            }
            // next extract the queue resource part of the sqsEventSource
            .compactMap { sqsEventSource in
                var result: Resource<ResourceType>?
                // should alway be true because of the filer() above
                if case .resource(let resource) = (sqsEventSource.properties as? SQSEventProperties)?
                    .reference {
                    result = resource
                }
                return result
            }
    }

    // MARK: Function DSL code

    @resultBuilder
    public enum FunctionBuilder {
        public static func buildBlock(_ description: String) -> (
            String?, EventSources, [String: String]
        ) {
            return (description, EventSources.none, [:])
        }

        public static func buildBlock(
            _ description: String,
            _ events: EventSources
        ) -> (String?, EventSources, [String: String]) {
            return (description, events, [:])
        }

        public static func buildBlock(_ events: EventSources) -> (
            String?, EventSources, [String: String]
        ) {
            return (nil, events, [:])
        }

        public static func buildBlock(
            _ description: String,
            _ events: EventSources,
            _ variables: EnvironmentVariables
        ) -> (String?, EventSources, [String: String]) {
            return (description, events, variables.environmentVariables)
        }

        public static func buildBlock(
            _ events: EventSources,
            _ variables: EnvironmentVariables
        ) -> (String?, EventSources, [String: String]) {
            return (nil, events, variables.environmentVariables)
        }

        public static func buildBlock(
            _ description: String,
            _ variables: EnvironmentVariables,
            _ events: EventSources
        ) -> (String?, EventSources, [String: String]) {
            return (description, events, variables.environmentVariables)
        }

        public static func buildBlock(
            _ variables: EnvironmentVariables,
            _ events: EventSources
        ) -> (String?, EventSources, [String: String]) {
            return (nil, events, variables.environmentVariables)
        }

        @available(*, unavailable, message: "Only one EnvironmentVariables block is allowed")
        public static func buildBlock(
            _: String,
            _: EventSources,
            _: EnvironmentVariables...
        ) -> (String?, EventSources?, [String: String]) {
            fatalError()
        }

        @available(*, unavailable, message: "Only one EnvironmentVariables block is allowed")
        public static func buildBlock(
            _: EventSources,
            _: EnvironmentVariables...
        ) -> (String?, EventSources?, [String: String]) {
            fatalError()
        }
    }

    // MARK: function modifiers

    public func autoPublishAlias(_ name: String = "live", all: Bool = false, sha256: String? = nil)
        -> Function {
        var properties = properties()
        properties.autoPublishAlias = name
        properties.autoPublishAliasAllProperties = all
        if sha256 != nil {
            properties.autoPublishCodeSha256 = sha256
        } else {
            properties.autoPublishCodeSha256 = FileDigest.hex(from: properties.codeUri)
        }
        return Function(self.name(), properties: properties)
    }

    public func ephemeralStorage(_ size: Int = 512) -> Function {
        var properties = properties()
        properties.ephemeralStorage = ServerlessFunctionProperties.EphemeralStorage(size)
        return Function(name(), properties: properties)
    }

    private func getDestinations(onSuccess: Arn, onFailure: Arn)
        -> ServerlessFunctionProperties.EventInvokeConfiguration.EventInvokeDestinationConfiguration {
        let successDestination = ServerlessFunctionProperties.EventInvokeConfiguration
            .EventInvokeDestination(
                destination: .arn(onSuccess),
                type: .destinationType(from: onSuccess)
            )

        let failureDestination = ServerlessFunctionProperties.EventInvokeConfiguration
            .EventInvokeDestination(
                destination: .arn(onFailure),
                type: .destinationType(from: onFailure)
            )

        return ServerlessFunctionProperties.EventInvokeConfiguration
            .EventInvokeDestinationConfiguration(
                onSuccess: successDestination,
                onFailure: failureDestination
            )
    }

    private func getDestinations(
        onSuccess: Resource<ResourceType>?, onFailure: Resource<ResourceType>?
    )
        -> ServerlessFunctionProperties.EventInvokeConfiguration.EventInvokeDestinationConfiguration {
        var successDestination:
            ServerlessFunctionProperties.EventInvokeConfiguration.EventInvokeDestination? = nil
        if let onSuccess {
            successDestination = ServerlessFunctionProperties.EventInvokeConfiguration
                .EventInvokeDestination(
                    destination: .resource(onSuccess),
                    type: .destinationType(from: onSuccess)
                )
        }

        var failureDestination:
            ServerlessFunctionProperties.EventInvokeConfiguration.EventInvokeDestination? = nil
        if let onFailure {
            failureDestination = ServerlessFunctionProperties.EventInvokeConfiguration
                .EventInvokeDestination(
                    destination: .resource(onFailure),
                    type: .destinationType(from: onFailure)
                )
        }

        return ServerlessFunctionProperties.EventInvokeConfiguration
            .EventInvokeDestinationConfiguration(
                onSuccess: successDestination,
                onFailure: failureDestination
            )
    }

    public func eventInvoke(
        onSuccess: String? = nil,
        onFailure: String? = nil,
        maximumEventAgeInSeconds: Int? = nil,
        maximumRetryAttempts: Int? = nil
    ) -> Function {
        guard let succesArn = Arn(onSuccess ?? ""),
              let failureArn = Arn(onFailure ?? "")
        else {
            return self
        }

        let destination = self.getDestinations(onSuccess: succesArn, onFailure: failureArn)
        var properties = properties()
        properties.eventInvokeConfig = ServerlessFunctionProperties.EventInvokeConfiguration(
            destinationConfig: destination,
            maximumEventAgeInSeconds: maximumEventAgeInSeconds,
            maximumRetryAttempts: maximumRetryAttempts
        )
        return Function(name(), properties: properties)
    }

    // TODO: Add support for references to other resources (SNS, EventBridge)
    // currently support reference to SQS and Lambda resources
    public func eventInvoke(
        onSuccess: Resource<ResourceType>? = nil,
        onFailure: Resource<ResourceType>? = nil,
        maximumEventAgeInSeconds: Int? = nil,
        maximumRetryAttempts: Int? = nil
    ) -> Function {
        if let onSuccess {
            guard onSuccess.type == .queue || onSuccess.type == .function else {
                return self
            }
        }

        if let onFailure {
            guard onFailure.type == .queue || onFailure.type == .function else {
                return self
            }
        }

        let destination = self.getDestinations(onSuccess: onSuccess, onFailure: onFailure)
        var properties = properties()
        properties.eventInvokeConfig = ServerlessFunctionProperties.EventInvokeConfiguration(
            destinationConfig: destination,
            maximumEventAgeInSeconds: maximumEventAgeInSeconds,
            maximumRetryAttempts: maximumRetryAttempts
        )
        return Function(name(), properties: properties)
    }

    public func fileSystem(_ arn: String, mountPoint: String) -> Function {
        var properties = properties()

        if let newConfig = ServerlessFunctionProperties.FileSystemConfig(
            arn: arn,
            localMountPath: mountPoint
        ) {
            if properties.fileSystemConfigs != nil {
                properties.fileSystemConfigs! += [newConfig]
            } else {
                properties.fileSystemConfigs = [newConfig]
            }
        }
        return Function(name(), properties: properties)
    }

    public func urlConfig(
        authType: ServerlessFunctionProperties.URLConfig.AuthType = .iam,
        invokeMode: ServerlessFunctionProperties.URLConfig.InvokeMode? = nil
    )
        -> Function {
        let builder: () -> [any CorsElement] = { [] }
        return self.urlConfig(
            authType: authType,
            invokeMode: invokeMode,
            allowCredentials: nil,
            maxAge: nil,
            builder
        )
    }

    public func urlConfig(
        authType: ServerlessFunctionProperties.URLConfig.AuthType = .iam,
        invokeMode: ServerlessFunctionProperties.URLConfig.InvokeMode? = nil,
        allowCredentials: Bool? = nil,
        maxAge: Int? = nil,
        @CorsBuilder _ builder: () -> [any CorsElement]
    ) -> Function {
        let corsBlock = builder()
        let allowHeaders = corsBlock.filter { $0.type == .allowHeaders }
            .compactMap { $0.elements() }
            .reduce([], +)
        let allowOrigins = corsBlock.filter { $0.type == .allowOrigins }
            .compactMap { $0.elements() }
            .reduce([], +)
        let allowMethods = corsBlock.filter { $0.type == .allowMethods }
            .compactMap { $0.elements() }
            .reduce([], +)
        let exposeHeaders = corsBlock.filter { $0.type == .exposeHeaders }
            .compactMap { $0.elements() }
            .reduce([], +)

        let cors: ServerlessFunctionProperties.URLConfig.Cors!
        if allowCredentials == nil && maxAge == nil && corsBlock.isEmpty {
            cors = nil
        } else {
            cors = ServerlessFunctionProperties.URLConfig.Cors(
                allowCredentials: allowCredentials,
                allowHeaders: allowHeaders.isEmpty ? nil : allowHeaders,
                allowMethods: allowMethods.isEmpty ? nil : allowMethods,
                allowOrigins: allowOrigins.isEmpty ? nil : allowOrigins,
                exposeHeaders: exposeHeaders.isEmpty ? nil : exposeHeaders,
                maxAge: maxAge
            )
        }
        let urlConfig = ServerlessFunctionProperties.URLConfig(
            authType: authType,
            cors: cors,
            invokeMode: invokeMode
        )
        var properties = properties()
        properties.functionUrlConfig = urlConfig
        return Function(name(), properties: properties)
    }

    private func properties() -> ServerlessFunctionProperties {
      self._underlying.properties as! ServerlessFunctionProperties  
    }
    private func name() -> String { self._underlying.name }
}

// MARK: Url Config Cors DSL code

public enum CorsElementType {
    case allowHeaders
    case allowOrigins
    case exposeHeaders
    case allowMethods
}

public protocol CorsElement {
    associatedtype T where T: Encodable
    var type: CorsElementType { get }
    func elements() -> [String]
    init(@CorsElementBuilder<T> _ builder: () -> [T])
}

@resultBuilder
public enum CorsElementBuilder<T> {
    public static func buildBlock(_ header: T...) -> [T] {
        header.compactMap { $0 }
    }
}

public struct AllowHeaders: CorsElement {
    public var type: CorsElementType = .allowHeaders
    private var _elements: [String]
    public init(@CorsElementBuilder<String> _ builder: () -> [String]) {
        self._elements = builder()
    }

    public func elements() -> [String] {
        self._elements
    }
}

public struct AllowOrigins: CorsElement {
    public var type: CorsElementType = .allowOrigins
    private var _elements: [String]
    public init(@CorsElementBuilder<String> _ builder: () -> [String]) {
        self._elements = builder()
    }

    public func elements() -> [String] {
        self._elements
    }
}

public struct ExposeHeaders: CorsElement {
    public var type: CorsElementType = .exposeHeaders
    private var _elements: [String]
    public init(@CorsElementBuilder<String> _ builder: () -> [String]) {
        self._elements = builder()
    }

    public func elements() -> [String] {
        self._elements
    }
}

public struct AllowMethods: CorsElement {
    public var type: CorsElementType = .allowMethods
    private var _elements: [HttpVerb]
    public init(@CorsElementBuilder<HttpVerb> _ builder: () -> [HttpVerb]) {
        self._elements = builder()
    }

    public func elements() -> [String] {
        self._elements.map(\.rawValue)
    }
}

@resultBuilder
public enum CorsBuilder {
    public static func buildBlock(_ corsElement: any CorsElement...) -> [any CorsElement] {
        corsElement.compactMap { $0 }
    }
}

// MARK: Event Source

public struct EventSources {
    public static let none = EventSources()
    private let eventSources: [Resource<EventSourceType>]
    private init() {
        self.eventSources = []
    }

    public init(@EventSourceBuilder _ builder: () -> [Resource<EventSourceType>]) {
        self.eventSources = builder()
    }

    internal func samEventSources() -> [Resource<EventSourceType>] {
        self.eventSources
    }

    // MARK: EventSources DSL code

    @resultBuilder
    public enum EventSourceBuilder {
        public static func buildBlock(_ source: Resource<EventSourceType>...) -> [Resource<
            EventSourceType
        >] {
            source.compactMap { $0 }
        }

        public static func buildExpression(_ expression: HttpApi) -> Resource<EventSourceType> {
            expression.resource()
        }

        public static func buildExpression(_ expression: Sqs) -> Resource<EventSourceType> {
            expression.resource()
        }

        public static func buildExpression(_ expression: Resource<EventSourceType>) -> Resource<
            EventSourceType
        > {
            expression
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
            properties = HttpApiProperties(method: self.method, path: self.path)
        }

        return Resource<EventSourceType>(
            type: .httpApi,
            properties: properties,
            name: self.name
        )
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

    public init(
        name: String = "SQSEvent",
        _ queue: String,
        batchSize: Int = 10,
        enabled: Bool = true
    ) {
        self.name = name
        self.queueRef = queue
        self.batchSize = batchSize
        self.enabled = enabled
    }

    public init(
        name: String = "SQSEvent",
        _ queue: Queue,
        batchSize: Int = 10,
        enabled: Bool = true
    ) {
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
        var properties: SQSEventProperties!
        if self.queue != nil {
            properties = SQSEventProperties(
                self.queue!.resource()[0],
                batchSize: self.batchSize,
                enabled: self.enabled
            )

        } else if self.queueRef != nil {
            properties = SQSEventProperties(
                byRef: self.queueRef!,
                batchSize: self.batchSize,
                enabled: self.enabled
            )
        } else {
            fatalError("Either queue or queueRef muts have a value")
        }

        return Resource<EventSourceType>(
            type: .sqs,
            properties: properties,
            name: self.name
        )
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
                mergedDictKeepCurrent = mergedDictKeepCurrent.merging(dict) { current, _ in current }
            }
            return mergedDictKeepCurrent
        }
    }
}

// MARK: Queue top level resource
//TODO : do we really need two Queue and Sqs struct ?
public struct Queue: BuilderResource {
    private let _underlying: Resource<ResourceType>

    public init(logicalName: String, physicalName: String) {
        let properties = SQSResourceProperties(queueName: physicalName)

        self._underlying = Resource<ResourceType>(
            type: .queue,
            properties: properties,
            name: logicalName
        )
    }

    internal func resource() -> [Resource<ResourceType>] { [_underlying] }
}

// MARK: Table top level resource
public struct Table: BuilderResource {
    private let _underlying: Resource<ResourceType>
    private init(
        logicalName: String,
        properties: SimpleTableProperties
    ) {
        self._underlying = Resource<ResourceType>(
            type: .table,
            properties: properties,
            name: logicalName
        )
    }

    public init(
        logicalName: String,
        physicalName: String,
        primaryKeyName: String,
        primaryKeyType: String
    ) {
        let primaryKey = SimpleTableProperties.PrimaryKey(
            name: primaryKeyName,
            type: primaryKeyType
        )
        let properties = SimpleTableProperties(
            primaryKey: primaryKey,
            tableName: physicalName
        )
        self.init(logicalName: logicalName, properties: properties)
    }

    internal func resource() -> [Resource<ResourceType>] { [ self._underlying ] }

    public func provisionedThroughput(readCapacityUnits: Int, writeCapacityUnits: Int) -> Table {
        var properties = self._underlying.properties as! SimpleTableProperties // use as! is safe, it it fails, it is a programming error
        properties.provisionedThroughput = SimpleTableProperties.ProvisionedThroughput(
            readCapacityUnits: readCapacityUnits,
            writeCapacityUnits: writeCapacityUnits
        )
        return Table(
            logicalName: self._underlying.name,
            properties: properties
        )
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
        let encoder = YAMLEncoder()
        encoder.keyEncodingStrategy = .camelCase
        let yaml = try! encoder.encode(self)

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
    static func serialize(
        _ deploymentDescriptor: SAMDeploymentDescriptor,
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
