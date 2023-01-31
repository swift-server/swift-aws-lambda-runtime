// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import Foundation
import AWSLambdaDeploymentDescriptor

struct MockDeploymentDescriptor {

    let deploymentDescriptor : DeploymentDefinition
    
    init(withFunction: Bool = true,
         eventSource:  [EventSource]? = nil,
         environmentVariable: EnvironmentVariable? = nil,
         additionalResources: [Resource]? = nil)
    {
        if withFunction {
            self.deploymentDescriptor = DeploymentDefinition(
                description: "A SAM template to deploy a Swift Lambda function",
                functions: [
                    .function(
                        name: "TestLambda",
                        eventSources: eventSource ?? [],
                        environment: environmentVariable ?? EnvironmentVariable.none
                    )
                ],
                resources: additionalResources ?? []
            )
        } else {
            self.deploymentDescriptor = DeploymentDefinition(
                description: "A SAM template to deploy a Swift Lambda function",
                functions: [],
                resources: additionalResources ?? []
            )
        }
    }
}

