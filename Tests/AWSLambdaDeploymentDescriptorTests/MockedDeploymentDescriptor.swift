// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2023 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import Foundation
import XCTest
@testable import AWSLambdaDeploymentDescriptor

protocol MockDeploymentDescriptorBehavior {
    func toJSON() -> String
    func toYAML() -> String
}

struct MockDeploymentDescriptor: MockDeploymentDescriptorBehavior {

    let deploymentDescriptor: SAMDeploymentDescriptor

    init(withFunction: Bool = true,
         architecture: ServerlessFunctionProperties.Architectures = .defaultArchitecture(),
         codeURI: String = "",
         eventSource: [Resource<EventSourceType>]? = nil,
         environmentVariable: SAMEnvironmentVariable? = nil,
         additionalResources: [Resource<ResourceType>] = []) {
        if withFunction {

            let properties = ServerlessFunctionProperties(
                    codeUri: codeURI,
                    architecture: architecture,
                    eventSources: eventSource ?? [],
                    environment: environmentVariable ?? SAMEnvironmentVariable.none)
            let serverlessFunction = Resource<ResourceType>(
                    type: .function,
                    properties: properties,
                    name: "TestLambda")

            self.deploymentDescriptor = SAMDeploymentDescriptor(
                description: "A SAM template to deploy a Swift Lambda function",
                resources: [ serverlessFunction ] + additionalResources

            )
        } else {
            self.deploymentDescriptor = SAMDeploymentDescriptor(
                description: "A SAM template to deploy a Swift Lambda function",
                resources: additionalResources
            )
        }
    }
    func toJSON() -> String {
        return self.deploymentDescriptor.toJSON(pretty: false)
    }
    func toYAML() -> String {
        return self.deploymentDescriptor.toYAML()
    }
}

struct MockDeploymentDescriptorBuilder: MockDeploymentDescriptorBehavior {

    static let functionName = "TestLambda"
    let deploymentDescriptor: DeploymentDescriptor

    init(withResource function: Function) {
        XCTAssert(function.resources().count == 1)
        self.init(withResource: function.resources()[0])
    }
    init(withResource table: Table) {
        self.init(withResource: table.resource())
    }
    init(withResource: Resource<ResourceType>) {
        self.deploymentDescriptor = DeploymentDescriptor {
            "A SAM template to deploy a Swift Lambda function"
            withResource
        }
    }
    init(withFunction: Bool = true,
         architecture: ServerlessFunctionProperties.Architectures = .defaultArchitecture(),
         codeURI: String,
         eventSource: Resource<EventSourceType>,
         environmentVariable: [String: String]) {
        if withFunction {

            self.deploymentDescriptor = DeploymentDescriptor {
                "A SAM template to deploy a Swift Lambda function"

                Function(name: MockDeploymentDescriptorBuilder.functionName,
                         architecture: architecture,
                         codeURI: codeURI) {
                    EventSources {
                        eventSource
                    }
                    EnvironmentVariables {
                        environmentVariable
                    }
                }
            }

        } else {
            self.deploymentDescriptor = DeploymentDescriptor {
                "A SAM template to deploy a Swift Lambda function"
            }
        }
    }

    func toJSON() -> String {
        return self.deploymentDescriptor.samDeploymentDescriptor.toJSON(pretty: false)
    }
    func toYAML() -> String {
        return self.deploymentDescriptor.samDeploymentDescriptor.toYAML()
    }

    static func packageDir() -> String {
        return "/\(functionName)"
    }
    static func packageZip() -> String {
        return "/\(functionName).zip"
    }
}
