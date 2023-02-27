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
import AWSLambdaDeploymentDescriptor

struct MockDeploymentDescriptor {

    let deploymentDescriptor : SAMDeploymentDescriptor
    
    init(withFunction: Bool = true,
         architecture: Architectures = Architectures.defaultArchitecture(),
         eventSource:  [Resource<EventSourceType>]? = nil,
         environmentVariable: SAMEnvironmentVariable? = nil,
         additionalResources: [Resource<ResourceType>]? = nil)
    {
        if withFunction {
            self.deploymentDescriptor = SAMDeploymentDescriptor(
                description: "A SAM template to deploy a Swift Lambda function",
                resources: [
                    .serverlessFunction(
                        name: "TestLambda",
                        architecture: architecture,
                        codeUri: "/path/lambda.zip",
                        eventSources: eventSource ?? [],
                        environment: environmentVariable ?? SAMEnvironmentVariable.none
                    )
                ] + (additionalResources ?? [])

            )
        } else {
            self.deploymentDescriptor = SAMDeploymentDescriptor(
                description: "A SAM template to deploy a Swift Lambda function",
                resources: (additionalResources ?? [])
            )
        }
    }
}

