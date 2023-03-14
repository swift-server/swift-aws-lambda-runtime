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

// this test case tests the generation of the SAM deployment descriptor in JSON
final class DeploymentDescriptorTests: DeploymentDescriptorBaseTest {

    private var defaultCodeUri = "\\/path\\/lambda.zip"
    func testSAMHeader() {
        
        // given
        let expected = expectedSAMHeaders()
        
        let testDeployment = MockDeploymentDescriptor(withFunction: false)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testLambdaFunctionResource() {
        
        // given
        let expected = [expectedFunction(codeURI: defaultCodeUri), expectedSAMHeaders()].flatMap{ $0 }

        let testDeployment = MockDeploymentDescriptor(withFunction: true)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testLambdaFunctionWithSpecificArchitectures() {
        
        // given
        let expected = [expectedFunction(architecture: Architectures.x64.rawValue, codeURI: defaultCodeUri),
                                  expectedSAMHeaders()]
                                  .flatMap{ $0 }

        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      architecture: .x64)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testSimpleTableResource() {
        
        // given
        let expected = ["""
"Resources":{"LogicalTestTable"
""",
"""
"Type":"AWS::Serverless::SimpleTable"
""",
"""
"TableName":"TestTable"
""",
"""
"PrimaryKey"
""",
"""
"Name":"pk"
""",
"""
"Type":"String"
"""]

        
        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                      additionalResources:
                                                        [.table(logicalName: "LogicalTestTable",
                                                                physicalName: "TestTable",
                                                                primaryKeyName: "pk",
                                                                primaryKeyType: "String")]
        )
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testSQSQueueResource() {
        
        // given
        let expected = expectedQueue()
        
        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                      additionalResources:
                                                        [.queue(name: "QueueTestQueue",
                                                                properties: SQSResourceProperties(queueName: "test-queue"))]
                                                      
        )
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testHttpApiEventSourceCatchAll() {
        
        // given
        let expected = [expectedSAMHeaders(),
                               expectedFunction(architecture: Architectures.defaultArchitecture().rawValue, codeURI: defaultCodeUri),
["""
"HttpApiEvent":{"Type":"HttpApi"}
"""] ].flatMap{ $0 }
        
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      eventSource: [ .httpApi() ] )
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testHttpApiEventSourceSpecific() {
        
        // given
        let expected = [expectedSAMHeaders(),
                               expectedFunction(architecture: Architectures.defaultArchitecture().rawValue, codeURI: defaultCodeUri),
["""
{"HttpApiEvent":
""",
"""
"Type":"HttpApi"
""",
"""
"Properties"
""",
"""
"Path":"\\/test"
""",
"""
"Method":"GET"
"""] ].flatMap{ $0 }
        
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      eventSource: [ .httpApi(method: .GET, path: "/test") ])
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testSQSEventSourceWithArn() {
        
        let name = #"arn:aws:sqs:eu-central-1:012345678901:lambda-test"#
        // given
        let expected = [ expectedSAMHeaders(), 
                                   expectedFunction(codeURI: defaultCodeUri),
                                   expectedQueueEventSource(source: name)
                                 ].flatMap{ $0 }
        
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      eventSource: [ .sqs(queue: name) ] )
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testSQSEventSourceWithoutArn() {
        
        let name = """
        "Queue":{"Fn::GetAtt":["QueueQueueLambdaTest","Arn"]}
        """

        // given
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      eventSource: [ .sqs(queue: "queue-lambda-test") ] )
        
        let expected = [ expectedSAMHeaders(),
                                   expectedFunction(codeURI: defaultCodeUri),
                                   expectedQueueEventSource(source: name)
                                 ].flatMap{ $0 }

        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testEnvironmentVariablesString() {
        
        // given
        let expected = ["""
"Environment"
""",
"""
"Variables"
""",
"""
"TEST2_VAR":"TEST2_VALUE"
""",
"""
"TEST1_VAR":"TEST1_VALUE"
"""]
        
        
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      environmentVariable: SAMEnvironmentVariable(["TEST1_VAR": "TEST1_VALUE",
                                                                                                   "TEST2_VAR": "TEST2_VALUE"]) )
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
        
    }
    
    func testEnvironmentVariablesArray() {
        
        // given
        let expected = """
"Environment":{"Variables":{"TEST1_VAR":{"Ref":"TEST1_VALUE"}}}
"""
        
        var envVar = SAMEnvironmentVariable()
        envVar.append("TEST1_VAR", ["Ref" : "TEST1_VALUE"])
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      environmentVariable: envVar )
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testEnvironmentVariablesDictionary() {
        
        // given
        let expected = """
"Environment":{"Variables":{"TEST1_VAR":{"Fn::GetAtt":["TEST1_VALUE","Arn"]}}}
"""
        
        var envVar = SAMEnvironmentVariable()
        envVar.append("TEST1_VAR", ["Fn::GetAtt" : ["TEST1_VALUE", "Arn"]])
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      environmentVariable: envVar )
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testEnvironmentVariablesResource() {
        
        // given
        let expected = """
"Environment":{"Variables":{"TEST1_VAR":{"Ref":"LogicalName"}}}
"""
        
        let resource = Resource<ResourceType>.queue(logicalName: "LogicalName", physicalName: "PhysicalName")
        var envVar = SAMEnvironmentVariable()
        envVar.append("TEST1_VAR", resource)
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      environmentVariable: envVar )
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testArnOK() {
        // given
        let validArn = "arn:aws:sqs:eu-central-1:012345678901:lambda-test"
        
        // when
        let arn = Arn(validArn)
        
        // then
        XCTAssertNotNil(arn)
    }
    
    func testArnFail() {
        // given
        let invalidArn = "invalid"
        
        // when
        let arn = Arn(invalidArn)
        
        // then
        XCTAssertNil(arn)
    }
    
}
