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

struct MockDeploymentDescriptor: DeploymentDescriptor {

    var eventSourceFunction: ( (String) -> [EventSource] )?
    var environmentVariableFunction: ( (String) -> EnvironmentVariable )?
    var additionalResourcesFunction: ( () -> [Resource] )?

    // returns the event sources for the given Lambda function
    func eventSources(_ lambdaName: String) -> [EventSource] {
        if let eventSourceFunction {
            return eventSourceFunction(lambdaName)
        } else {
            return []
        }
    }

    // returns environment variables to associate with the given Lambda function
    func environmentVariables(_ lambdaName: String) -> EnvironmentVariable {
        if let environmentVariableFunction {
            return environmentVariableFunction(lambdaName)
        } else {
            return EnvironmentVariable.none()
        }
    }

    // returns environment variables to associate with the given Lambda function
    func addResource() -> [Resource] {
        if let additionalResourcesFunction {
            return additionalResourcesFunction()
        } else {
            return []
        }
    }
}
