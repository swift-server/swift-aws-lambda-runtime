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

@testable import AWSLambdaDeploymentDescriptor
import XCTest

final class DeploymentDescriptorTest: XCTestCase {
    
    var originalCommandLineArgs: [String] = []
    
    override func setUp() {
        // save the original Command Line args, just in case
        originalCommandLineArgs = CommandLine.arguments
        CommandLine.arguments = ["mocked_arg0", "TestLambda"]
    }
    override func tearDown() {
        CommandLine.arguments = originalCommandLineArgs
    }
    
    private func generateAndTestDeploymentDecsriptor(deployment: MockDeploymentDescriptor, expected: String) -> Bool {
        // when
        let samJSON = deployment.deploymentDescriptor.toJSON(pretty: false)
        print(samJSON)
        // then
        return samJSON.contains(expected)
    }
    
    func testSAMHeader() {
        
        // given
        let expected = """
{"Description":"A SAM template to deploy a Swift Lambda function","AWSTemplateFormatVersion":"2010-09-09","Resources":{},"Transform":"AWS::Serverless-2016-10-31"}
"""

        let testDeployment = MockDeploymentDescriptor(withFunction: false)
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testLambdaFunctionResource() {

        // given
        let expected = """
function","AWSTemplateFormatVersion":"2010-09-09","Resources":{"TestLambda":{"Type":"AWS::Serverless::Function","Properties":{"Runtime":"provided.al2","CodeUri":"### ERROR package does not exist: .build\\/plugins\\/AWSLambdaPackager\\/outputs\\/AWSLambdaPackager\\/TestLambda\\/TestLambda.zip ###","Events":{},"Handler":"Provided","AutoPublishAlias":"Live","Architectures":["\(Architectures.defaultArchitecture())"]}}}
"""
        let testDeployment = MockDeploymentDescriptor(withFunction: true)
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testLambdaFunctionWithSpecificArchitectures() {

        // given
        let expected = """
function","AWSTemplateFormatVersion":"2010-09-09","Resources":{"TestLambda":{"Type":"AWS::Serverless::Function","Properties":{"Runtime":"provided.al2","CodeUri":"### ERROR package does not exist: .build\\/plugins\\/AWSLambdaPackager\\/outputs\\/AWSLambdaPackager\\/TestLambda\\/TestLambda.zip ###","Events":{},"Handler":"Provided","AutoPublishAlias":"Live","Architectures":["\(Architectures.x64.rawValue)"]}}}
"""
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      architecture: .x64)
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testSimpleTableResource() {

        // given
        let expected = """
"Resources":{"LogicalTestTable":{"Type":"AWS::Serverless::SimpleTable","Properties":{"TableName":"TestTable","PrimaryKey":{"Name":"pk","Type":"String"}}}}
"""

        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                      additionalResources:
                    [.table(logicalName: "LogicalTestTable",
                            physicalName: "TestTable",
                            primaryKeyName: "pk",
                            primaryKeyType: "String")]
        )
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testSQSQueueResource() {

        // given
        let expected = """
"Resources":{"LogicalQueueName":{"Type":"AWS::SQS::Queue","Properties":{"QueueName":"queue-name"}}}
"""

        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                      additionalResources:
                    [.queue(name: "LogicalQueueName",
                            properties: SQSResourceProperties(queueName: "queue-name"))]
            
        )
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testHttpApiEventSourceCatchAll() {

        // given
        let expected = """
"Resources":{"TestLambda":{"Type":"AWS::Serverless::Function","Properties":{"Runtime":"provided.al2","CodeUri":"### ERROR package does not exist: .build\\/plugins\\/AWSLambdaPackager\\/outputs\\/AWSLambdaPackager\\/TestLambda\\/TestLambda.zip ###","Events":{"HttpApiEvent":{"Type":"HttpApi"}},"Handler":"Provided","AutoPublishAlias":"Live","Architectures":["\(Architectures.defaultArchitecture())"]}}}
"""

        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      eventSource: [ .httpApi() ] )

        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testHttpApiEventSourceSpecific() {

        // given
        let expected = """
"Resources":{"TestLambda":{"Type":"AWS::Serverless::Function","Properties":{"Runtime":"provided.al2","CodeUri":"### ERROR package does not exist: .build\\/plugins\\/AWSLambdaPackager\\/outputs\\/AWSLambdaPackager\\/TestLambda\\/TestLambda.zip ###","Events":{"HttpApiEvent":{"Type":"HttpApi","Properties":{"Path":"\\/test","Method":"GET"}}},"Handler":"Provided","AutoPublishAlias":"Live","Architectures":["\(Architectures.defaultArchitecture())"]}}}
"""

        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      eventSource: [ .httpApi(method: .GET, path: "/test") ])

        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }
//
    func testSQSEventSourceWithArn() {

        // given
        let expected = """
"Resources":{"TestLambda":{"Type":"AWS::Serverless::Function","Properties":{"Runtime":"provided.al2","CodeUri":"### ERROR package does not exist: .build\\/plugins\\/AWSLambdaPackager\\/outputs\\/AWSLambdaPackager\\/TestLambda\\/TestLambda.zip ###","Events":{"SQSEvent":{"Type":"SQS","Properties":{"Queue":"arn:aws:sqs:eu-central-1:012345678901:lambda-test"}}},"Handler":"Provided","AutoPublishAlias":"Live","Architectures":["\(Architectures.defaultArchitecture())"]}}}
"""

        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      eventSource: [ .sqs(queue: "arn:aws:sqs:eu-central-1:012345678901:lambda-test") ] )

        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testSQSEventSourceWithoutArn() {

        // given
        var expected = """
"QueueQueueLambdaTest":{"Type":"AWS::SQS::Queue","Properties":{"QueueName":"queue-lambda-test"}}
"""

        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      eventSource: [ .sqs(queue: "queue-lambda-test") ] )

        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))

        expected = """
"Events":{"SQSEvent":{"Type":"SQS","Properties":{"Queue":{"Fn::GetAtt":["QueueQueueLambdaTest","Arn"]}}}}
"""
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testEnvironmentVariablesString() {

        // given
        let expectedinOrder = """
"Environment":{"Variables":{"TEST2_VAR":"TEST2_VALUE","TEST1_VAR":"TEST1_VALUE"}}
"""
        let expectedOutOfOrder = """
"Environment":{"Variables":{"TEST1_VAR":"TEST1_VALUE","TEST2_VAR":"TEST2_VALUE"}}
"""


        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      environmentVariable: EnvironmentVariable(["TEST1_VAR": "TEST1_VALUE",
                                                                                                "TEST2_VAR": "TEST2_VALUE"]) )

        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expectedinOrder)
                      ||
                      self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                                             expected: expectedOutOfOrder)
        )
    }

    func testEnvironmentVariablesArray() {

        // given
        let expected = """
"Environment":{"Variables":{"TEST1_VAR":{"Ref":"TEST1_VALUE"}}}
"""

        var envVar = EnvironmentVariable()
        envVar.append("TEST1_VAR", ["Ref" : "TEST1_VALUE"])
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      environmentVariable: envVar )
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testEnvironmentVariablesDictionary() {

        // given
        let expected = """
"Environment":{"Variables":{"TEST1_VAR":{"Fn::GetAtt":["TEST1_VALUE","Arn"]}}}
"""

        var envVar = EnvironmentVariable()
        envVar.append("TEST1_VAR", ["Fn::GetAtt" : ["TEST1_VALUE", "Arn"]])
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      environmentVariable: envVar )
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testEnvironmentVariablesResource() {

        // given
        let expected = """
"Environment":{"Variables":{"TEST1_VAR":{"Ref":"LogicalName"}}}
"""

        let resource = Resource.queue(logicalName: "LogicalName", physicalName: "PhysicalName")
        var envVar = EnvironmentVariable()
        envVar.append("TEST1_VAR", resource)
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      environmentVariable: envVar )
        XCTAssertTrue(self.generateAndTestDeploymentDecsriptor(deployment: testDeployment,
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
