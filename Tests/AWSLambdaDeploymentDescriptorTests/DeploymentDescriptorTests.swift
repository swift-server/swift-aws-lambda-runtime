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

    func testSAMHeader() {

        // given
        let expected = expectedSAMHeaders()

        let testDeployment = MockDeploymentDescriptor(withFunction: false, codeURI: self.codeURI)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testLambdaFunctionResource() {

        // given
        let expected = [expectedFunction(), expectedSAMHeaders()].flatMap { $0 }

        let testDeployment = MockDeploymentDescriptor(withFunction: true, codeURI: self.codeURI)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testLambdaFunctionWithSpecificArchitectures() {

        // given
        let expected = [expectedFunction(architecture: Architectures.x64.rawValue),
                                  expectedSAMHeaders()]
                                  .flatMap { $0 }

        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      architecture: .x64,
                                                      codeURI: self.codeURI)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testSimpleTableResource() {

        // given
        let expected = [
            Expected.keyOnly(indent: 0, key: "Resources"),
            Expected.keyOnly(indent: 1, key: "LogicalTestTable"),
            Expected.keyValue(indent: 2, keyValue: ["Type": "AWS::Serverless::SimpleTable"]),
            Expected.keyOnly(indent: 2, key: "Properties"),
            Expected.keyOnly(indent: 3, key: "PrimaryKey"),
            Expected.keyValue(indent: 3, keyValue: ["TableName": "TestTable"]),
            Expected.keyValue(indent: 4, keyValue: ["Name": "pk",
                                                    "Type": "String"])
            ]

        let pk = SimpleTableProperties.PrimaryKey(name: "pk", type: "String")
        let props = SimpleTableProperties(primaryKey: pk, tableName: "TestTable")
        let table = Resource<ResourceType>(type: .table,
                                           properties: props,
                                           name: "LogicalTestTable")

        // when
        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                      codeURI: self.codeURI,
                                                      additionalResources: [ table ]
        )

        // then
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testSQSQueueResource() {

        // given
        let expected = expectedQueue()

        let props = SQSResourceProperties(queueName: "test-queue")
        let queue = Resource<ResourceType>(type: .queue,
                                           properties: props,
                                           name: "QueueTestQueue")

        // when
        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                      codeURI: self.codeURI,
                                                      additionalResources: [ queue ]

        )

        // test
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testHttpApiEventSourceCatchAll() {

        // given
        let expected = expectedSAMHeaders() +
                       expectedFunction(architecture: Architectures.defaultArchitecture().rawValue) +
        [
            Expected.keyOnly(indent: 4, key: "HttpApiEvent"),
            Expected.keyValue(indent: 5, keyValue: ["Type": "HttpApi"])
        ]

        let httpApi = Resource<EventSourceType>(
                            type: .httpApi,
                            properties: nil,
                            name: "HttpApiEvent")

        // when
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      codeURI: self.codeURI,
                                                      eventSource: [ httpApi ] )

        // then
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testHttpApiEventSourceSpecific() {

        // given
        let expected = expectedSAMHeaders() +
                       expectedFunction(architecture: Architectures.defaultArchitecture().rawValue) +
        [
            Expected.keyOnly(indent: 4, key: "HttpApiEvent"),
            Expected.keyValue(indent: 5, keyValue: ["Type": "HttpApi"]),
            Expected.keyOnly(indent: 5, key: "Properties"),
            Expected.keyValue(indent: 6, keyValue: ["Path": "/test",
                                                    "Method": "GET"])
        ]

        let props = HttpApiProperties(method: .GET, path: "/test")
        let httpApi = Resource<EventSourceType>(
                            type: .httpApi,
                            properties: props,
                            name: "HttpApiEvent")

        // when
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      codeURI: self.codeURI,
                                                      eventSource: [ httpApi ])

        // then
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testSQSEventSourceWithArn() {

        let name = #"arn:aws:sqs:eu-central-1:012345678901:lambda-test"#
        // given
        let expected = expectedSAMHeaders() +
                       expectedFunction() +
                       expectedQueueEventSource(arn: name)

        let props = SQSEventProperties(byRef: name,
                                       batchSize: 10,
                                       enabled: true)
        let queue = Resource<EventSourceType>(type: .sqs,
                                              properties: props,
                                              name: "SQSEvent")

        // when
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      codeURI: self.codeURI,
                                                      eventSource: [ queue ] )

        // then
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testSQSEventSourceWithoutArn() {

        // given
        let expected =  expectedSAMHeaders() +
                        expectedFunction() +
                        expectedQueueEventSource(source: "QueueQueueLambdaTest")

        let props = SQSEventProperties(byRef: "queue-lambda-test",
                                       batchSize: 10,
                                       enabled: true)
        let queue = Resource<EventSourceType>(type: .sqs,
                                              properties: props,
                                              name: "SQSEvent")

        // when
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      codeURI: self.codeURI,
                                                      eventSource: [ queue ] )

        // then
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testEnvironmentVariablesString() {

        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "Environment"),
            Expected.keyOnly(indent: 4, key: "Variables"),
            Expected.keyValue(indent: 5, keyValue: [
                "TEST2_VAR": "TEST2_VALUE",
                "TEST1_VAR": "TEST1_VALUE"
            ])
        ]

        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      codeURI: self.codeURI,
                                                      environmentVariable: SAMEnvironmentVariable(["TEST1_VAR": "TEST1_VALUE",
                                                                                                   "TEST2_VAR": "TEST2_VALUE"]) )

        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))

    }

    func testEnvironmentVariablesArray() {

        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "Environment"),
            Expected.keyOnly(indent: 4, key: "Variables"),
            Expected.keyOnly(indent: 5, key: "TEST1_VAR"),
            Expected.keyValue(indent: 6, keyValue: ["Ref": "TEST1_VALUE"])
        ]

        var envVar = SAMEnvironmentVariable()
        envVar.append("TEST1_VAR", ["Ref": "TEST1_VALUE"])
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      codeURI: self.codeURI,
                                                      environmentVariable: envVar )
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testEnvironmentVariablesDictionary() {

        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "Environment"),
            Expected.keyOnly(indent: 4, key: "Variables"),
            Expected.keyOnly(indent: 5, key: "TEST1_VAR"),
            Expected.keyOnly(indent: 6, key: "Fn::GetAtt"),
            Expected.arrayKey(indent: 7, key: "TEST1_VALUE"),
            Expected.arrayKey(indent: 7, key: "Arn")
        ]

        var envVar = SAMEnvironmentVariable()
        envVar.append("TEST1_VAR", ["Fn::GetAtt": ["TEST1_VALUE", "Arn"]])
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      codeURI: self.codeURI,
                                                      environmentVariable: envVar )
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testEnvironmentVariablesResource() {

        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "Environment"),
            Expected.keyOnly(indent: 4, key: "Variables"),
            Expected.keyOnly(indent: 5, key: "TEST1_VAR"),
            Expected.keyValue(indent: 6, keyValue: ["Ref": "LogicalName"])
        ]

        let props = SQSResourceProperties(queueName: "PhysicalName")
        let resource = Resource<ResourceType>(type: .queue, properties: props, name: "LogicalName")
        var envVar = SAMEnvironmentVariable()
        envVar.append("TEST1_VAR", resource)
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      codeURI: self.codeURI,
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
