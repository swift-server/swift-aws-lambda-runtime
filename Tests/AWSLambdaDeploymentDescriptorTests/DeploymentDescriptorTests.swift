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

    func testSAMHeader() {

        // given
        let expected = """
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: A SAM template to deploy a Swift Lambda function
"""
        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable.none() }
        testDeployment.eventSourceFunction = { _ in [] }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expected))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }
    }

    func testLambdaFunctionResource() {

        // given
#if arch(arm64)
        let architecture = "arm64"
#else
        let architecture = "x86_64"
#endif
        let expected = """
Resources:
  TestLambda:
    Type: AWS::Serverless::Function
    Properties:
      Architectures:
      - \(architecture)
      Handler: Provided
      Runtime: provided.al2
      CodeUri: .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/TestLambda/TestLambda.zip
      AutoPublishAlias: Live
      Events: {}
"""
        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable.none() }
        testDeployment.eventSourceFunction = { _ in [] }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expected))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }
    }

    func testSimpleTableResource() {

        // given
        let expected = """
LogicalTestTable:
    Type: AWS::Serverless::SimpleTable
    Properties:
      TableName: TestTable
      PrimaryKey:
        Name: pk
        Type: String
"""

        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable.none() }
        testDeployment.eventSourceFunction = { _ in [] }
        testDeployment.additionalResourcesFunction = {
            return [Resource.simpleTable(name: "LogicalTestTable",
                                        properties: SimpleTableProperties(primaryKey: .init(name: "pk",
                                                                                            type: "String"),
                                                                          tableName: "TestTable")
            )]
        }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expected))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }
    }

    func testSQSQueueResource() {

        // given
        let expected = """
  LogicalQueueName:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: queue-name
"""

        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable.none() }
        testDeployment.eventSourceFunction = { _ in [] }
        testDeployment.additionalResourcesFunction = {
            return [Resource.sqsQueue(name: "LogicalQueueName",
                                      properties: SQSResourceProperties(queueName: "queue-name"))
            ]
        }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expected))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }
    }

    func testHttpApiEventSourceCatchAll() {

        // given
        let expected = """
      Events:
        HttpApiEvent:
          Type: HttpApi
"""

        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable.none() }
        testDeployment.eventSourceFunction = { _ in [ .httpApi() ] }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expected))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }
    }

    func testHttpApiEventSourceSpecific() {

        // given
        let expected = """
        HttpApiEvent:
          Type: HttpApi
          Properties:
            Method: GET
            Path: /test
"""

        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable.none() }
        testDeployment.eventSourceFunction = { _ in [ .httpApi(method: .GET,
                                                               path: "/test") ] }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expected))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }
    }

    func testSQSEventSourceWithArn() {

        // given
        let expected = """
      Events:
        SQSEvent:
          Type: SQS
          Properties:
            Queue: arn:aws:sqs:eu-central-1:012345678901:lambda-test
"""

        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable.none() }
        testDeployment.eventSourceFunction = { _ in [ .sqs(queue: "arn:aws:sqs:eu-central-1:012345678901:lambda-test") ] }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expected))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }
    }

    func testSQSEventSourceWithoutArn() {

        // given
        let expected = """
      Events:
        SQSEvent:
          Type: SQS
          Properties:
            Queue:
              Fn::GetAtt:
              - QueueQueueLambdaTest
              - Arn
"""
        let expectedResource = """
  QueueQueueLambdaTest:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: queue-lambda-test
"""

        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable.none() }
        testDeployment.eventSourceFunction = { _ in [ .sqs(queue: "queue-lambda-test") ] }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expected))
            XCTAssertTrue(samYaml.contains(expectedResource))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }

    }

    func testEnvironmentVariables() {

        // given
        let expectedOne = """
      Environment:
        Variables:
          TEST2_VAR: TEST2_VALUE
          TEST1_VAR: TEST1_VALUE
"""
        let expectedTwo = """
      Environment:
        Variables:
          TEST1_VAR: TEST1_VALUE
          TEST2_VAR: TEST2_VALUE
"""

        var testDeployment = MockDeploymentDescriptor()
        testDeployment.environmentVariableFunction = { _ in EnvironmentVariable(["TEST1_VAR": "TEST1_VALUE",
                                                                                 "TEST2_VAR": "TEST2_VALUE"]) }

        do {
            // when
            let samYaml = try testDeployment.toYaml()

            // then
            XCTAssertTrue(samYaml.contains(expectedOne) || samYaml.contains(expectedTwo))
        } catch {
            XCTFail("toYaml should not throw an exceptoon")
        }
    }
}
