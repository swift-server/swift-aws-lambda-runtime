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

@testable import AWSLambdaDeploymentDescriptor
import XCTest

class DeploymentDescriptorBaseTest: XCTestCase {

    func generateAndTestDeploymentDescriptor<T: MockDeploymentDescriptorBehavior>(deployment: T,
                                             expected: [String]) -> Bool {
        // when
        let samJSON = deployment.toJSON()
        
        // then
        let result = expected.allSatisfy { samJSON.contains( $0 ) }

        if (!result) {
            print("===========")
            print(samJSON)
            print("-----------")
            print(expected.filter{ !samJSON.contains( $0 ) }.compactMap{ $0 })        
            print("===========")
        }

        return result
    }

    func generateAndTestDeploymentDescriptor<T: MockDeploymentDescriptorBehavior>(deployment: T,
                                             expected: String) -> Bool {
        return generateAndTestDeploymentDescriptor(deployment: deployment, expected: [expected])
    }

    func expectedSAMHeaders() -> [String] {
        return ["""
"Description":"A SAM template to deploy a Swift Lambda function"
""",
"""
"AWSTemplateFormatVersion":"2010-09-09"
""",
"""
"Transform":"AWS::Serverless-2016-10-31"
"""]
    }

    func expectedFunction(architecture : String = "arm64", codeURI: String = "ERROR") -> [String] {
        return ["""
"Resources":{"TestLambda":{
""",
"""
"Type":"AWS::Serverless::Function"
""",
"""
"AutoPublishAlias":"Live"
""",
"""
"Handler":"Provided"
""",
"""
"CodeUri":"\(codeURI)"
""",
"""
"Runtime":"provided.al2"
""",
"""
"Architectures":["\(architecture)"]
"""]
    }

    func expectedEnvironmentVariables() -> [String] {
        return ["""
"Environment":{"Variables":{"NAME1":"VALUE1"}}
"""]
    }

    func expectedHttpAPi() -> [String] {
        return ["""
"HttpApiEvent":{"Type":"HttpApi"}
"""]
    }

    func expectedQueue() -> [String] {
        return ["""
"Resources":
""",
"""
"QueueTestQueue":
""",
"""
"Type":"AWS::SQS::Queue"
""",
"""
"Properties":{"QueueName":"test-queue"}
"""]        
    }

    func expectedQueueEventSource(source: String) -> [String] {
        return [
"""
"SQSEvent"
""",
"""
"Type":"SQS"
""",
"""
\(source)
""",
"""
"BatchSize":10
""",
"""
"Enabled":true
"""
        ]
    }
}