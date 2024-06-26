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
        let expected = [expectedFunction(architecture: ServerlessFunctionProperties.Architectures.x64.rawValue),
                        expectedSAMHeaders()]
                        .flatMap { $0 }

        // when
        let testDeployment = MockDeploymentDescriptor(withFunction: true,
                                                      architecture: .x64,
                                                      codeURI: self.codeURI)

        // then 
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }

    func testAllFunctionProperties() {

        // given
        let expected = [Expected.keyValue(indent: 3,
                                          keyValue: ["AutoPublishAliasAllProperties": "true",
                                                     "AutoPublishAlias" : "alias",
                                                     "AutoPublishCodeSha256" : "sha256",
                                                     "Description" : "my function description"
                                                    ] ),
                        Expected.keyOnly(indent: 3, key: "EphemeralStorage"),
                        Expected.keyValue(indent: 4, keyValue: ["Size": "1024"])
        ]

        // when                                                     
        var functionProperties = ServerlessFunctionProperties(codeUri: self.codeURI, architecture: .arm64)
        functionProperties.autoPublishAliasAllProperties = true
        functionProperties.autoPublishAlias = "alias"
        functionProperties.autoPublishCodeSha256 = "sha256"
        functionProperties.description = "my function description"
        functionProperties.ephemeralStorage = ServerlessFunctionProperties.EphemeralStorage(1024)
        let functionToTest = Resource<ResourceType>(type: .function,
                                                    properties: functionProperties,
                                                    name: functionName)

        // then
        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                codeURI: self.codeURI,
                                                additionalResources: [ functionToTest ])
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testEventInvokeConfig() {
        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "EventInvokeConfig"),
            Expected.keyOnly(indent: 4, key: "DestinationConfig"),
            Expected.keyOnly(indent: 5, key: "OnSuccess"),
            Expected.keyValue(indent: 6, keyValue: ["Type" : "SNS"]),
            Expected.keyOnly(indent: 5, key: "OnFailure"),
            Expected.keyValue(indent: 6, keyValue: ["Destination" : "arn:aws:sqs:eu-central-1:012345678901:lambda-test"]),
            Expected.keyValue(indent: 6, keyValue: ["Type" : "Lambda"])
        ]
        
        // when
        var functionProperties = ServerlessFunctionProperties(codeUri: self.codeURI, architecture: .arm64)
        let validArn = "arn:aws:sqs:eu-central-1:012345678901:lambda-test"
        let arn = Arn(validArn)
        let destination1 = ServerlessFunctionProperties.EventInvokeConfiguration.EventInvokeDestination(destination: nil,
                                                                                                        type: .sns)
        let destination2 = ServerlessFunctionProperties.EventInvokeConfiguration.EventInvokeDestination(destination: .arn(arn!),
                                                                                                        type: .lambda)
        let destinations = ServerlessFunctionProperties.EventInvokeConfiguration.EventInvokeDestinationConfiguration(
            onSuccess: destination1,
            onFailure: destination2)
        
        let invokeConfig = ServerlessFunctionProperties.EventInvokeConfiguration(
            destinationConfig: destinations,
            maximumEventAgeInSeconds: 999,
            maximumRetryAttempts: 33)
        functionProperties.eventInvokeConfig = invokeConfig
        let functionToTest = Resource<ResourceType>(type: .function,
                                                    properties: functionProperties,
                                                    name: functionName)

        // then
        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                codeURI: self.codeURI,
                                                additionalResources: [ functionToTest ])
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))

    }

    func testFileSystemConfig() {
        // given
        let validArn = "arn:aws:elasticfilesystem:eu-central-1:012345678901:access-point/fsap-abcdef01234567890"
        let mount1 = "/mnt/path1"
        let mount2 = "/mnt/path2"
        let expected = [
            Expected.keyOnly(indent: 3, key: "FileSystemConfigs"),
            Expected.arrayKey(indent: 4, key: ""),
            Expected.keyValue(indent: 5, keyValue: ["Arn":validArn,
                                                    "LocalMountPath" : mount1]),
            Expected.keyValue(indent: 5, keyValue: ["Arn":validArn,
                                                    "LocalMountPath" : mount2])
        ]
        
        // when
        var functionProperties = ServerlessFunctionProperties(codeUri: self.codeURI, architecture: .arm64)
        
        if let fileSystemConfig1 = ServerlessFunctionProperties.FileSystemConfig(arn: validArn, localMountPath: mount1),
           let fileSystemConfig2 = ServerlessFunctionProperties.FileSystemConfig(arn: validArn, localMountPath: mount2) {
            functionProperties.fileSystemConfigs = [fileSystemConfig1, fileSystemConfig2]
        } else {
            XCTFail("Invalid Arn or MountPoint")
        }

        let functionToTest = Resource<ResourceType>(type: .function,
                                                    properties: functionProperties,
                                                    name: functionName)

        // then
        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                codeURI: self.codeURI,
                                                additionalResources: [ functionToTest ])
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    func testInvalidFileSystemConfig() {
        // given
        let validArn = "arn:aws:elasticfilesystem:eu-central-1:012345678901:access-point/fsap-abcdef01234567890"
        let invalidArn1 = "arn:aws:sqs:eu-central-1:012345678901:lambda-test"
        let invalidArn2 = "arn:aws:elasticfilesystem:eu-central-1:012345678901:access-point/fsap-abcdef01234"

        // when
        // mount path is not conform (should be /mnt/something)
        let fileSystemConfig1 = ServerlessFunctionProperties.FileSystemConfig(arn: validArn, localMountPath: "/mnt1")
        // arn is not conform (should be an elastic filesystem)
        let fileSystemConfig2 = ServerlessFunctionProperties.FileSystemConfig(arn: invalidArn1, localMountPath: "/mnt/path1")
        // arn is not conform (should have 17 digits in the ID)
        let fileSystemConfig3 = ServerlessFunctionProperties.FileSystemConfig(arn: invalidArn2, localMountPath: "/mnt/path1")
        // OK
        let fileSystemConfig4 = ServerlessFunctionProperties.FileSystemConfig(arn: validArn, localMountPath: "/mnt/path1")

        // then
        XCTAssertNil(fileSystemConfig1)
        XCTAssertNil(fileSystemConfig2)
        XCTAssertNil(fileSystemConfig3)
        XCTAssertNotNil(fileSystemConfig4)
    }
    
    func testURLConfig() {
        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "FunctionUrlConfig"),
            Expected.keyValue(indent: 4, keyValue: ["AuthType" : "AWS_IAM"]),
            Expected.keyValue(indent: 4, keyValue: ["InvokeMode" : "BUFFERED"]),
            Expected.keyOnly(indent: 4, key: "Cors"),
            Expected.keyValue(indent: 5, keyValue: ["MaxAge":"99",
                                                    "AllowCredentials" : "true"]),
            Expected.keyOnly(indent: 5, key: "AllowHeaders"),
            Expected.arrayKey(indent: 6, key: "allowHeaders"),
            Expected.keyOnly(indent: 5, key: "AllowMethods"),
            Expected.arrayKey(indent: 6, key: "allowMethod"),
            Expected.keyOnly(indent: 5, key: "AllowOrigins"),
            Expected.arrayKey(indent: 6, key: "allowOrigin"),
            Expected.keyOnly(indent: 5, key: "ExposeHeaders"),
            Expected.arrayKey(indent: 6, key: "exposeHeaders")
        ]
        
        // when
        var functionProperties = ServerlessFunctionProperties(codeUri: self.codeURI, architecture: .arm64)
        
        let cors = ServerlessFunctionProperties.URLConfig.Cors(allowCredentials: true,
                                                               allowHeaders: ["allowHeaders"],
                                                               allowMethods: ["allowMethod"],
                                                               allowOrigins: ["allowOrigin"],
                                                               exposeHeaders: ["exposeHeaders"],
                                                               maxAge: 99)
        let config = ServerlessFunctionProperties.URLConfig(authType: .iam,
                                                            cors: cors,
                                                            invokeMode: .buffered)
        functionProperties.functionUrlConfig = config

        let functionToTest = Resource<ResourceType>(type: .function,
                                                    properties: functionProperties,
                                                    name: functionName)

        // then
        let testDeployment = MockDeploymentDescriptor(withFunction: false,
                                                codeURI: self.codeURI,
                                                additionalResources: [ functionToTest ])
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
        expectedFunction(architecture: ServerlessFunctionProperties.Architectures.defaultArchitecture().rawValue) +
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
        expectedFunction(architecture: ServerlessFunctionProperties.Architectures.defaultArchitecture().rawValue) +
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

    func testEncodeArn() throws {
        // given
        let validArn = "arn:aws:sqs:eu-central-1:012345678901:lambda-test"

        // when
        let arn = Arn(validArn)
        let yaml = try YAMLEncoder().encode(arn)

        // then
        XCTAssertEqual(String(data: yaml, encoding: .utf8), arn?.arn)
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

    func testServicefromArn() {
        // given
        var validArn = "arn:aws:sqs:eu-central-1:012345678901:lambda-test"

        // when
        var arn = Arn(validArn)

        // then
        XCTAssertEqual("sqs", arn!.service())

        // given
        validArn = "arn:aws:lambda:eu-central-1:012345678901:lambda-test"

        // when
        arn = Arn(validArn)

        // then
        XCTAssertEqual("lambda", arn!.service())

        // given
        validArn = "arn:aws:event-bridge:eu-central-1:012345678901:lambda-test"

        // when
        arn = Arn(validArn)

        // then
        XCTAssertEqual("event-bridge", arn!.service())
    }

}
