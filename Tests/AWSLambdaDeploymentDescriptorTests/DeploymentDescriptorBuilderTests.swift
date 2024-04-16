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

import XCTest
@testable import AWSLambdaDeploymentDescriptor

// This test case tests the logic built into the DSL,
// i.e. the additional resources created automatically
// and the check on existence of the ZIP file
// the rest is boiler plate code
final class DeploymentDescriptorBuilderTests: DeploymentDescriptorBaseTest {
    
    //MARK: ServerlessFunction resource
    func testGenericFunction() {
        
        // given
        let expected: [Expected] = expectedSAMHeaders() +
        expectedFunction() +
        expectedEnvironmentVariables() +
        expectedHttpAPi()
        
        let testDeployment = MockDeploymentDescriptorBuilder(
            withFunction: true,
            architecture: .arm64,
            codeURI: self.codeURI,
            eventSource: HttpApi().resource(),
            environmentVariable: ["NAME1": "VALUE1"]
        )
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
        
    }
    
    // check wether the builder creates additional queue resources
    func testLambdaCreateAdditionalResourceWithName() {
        
        // given
        let expected = expectedQueue()
        
        let sqsEventSource = Sqs("test-queue").resource()
        
        let testDeployment = MockDeploymentDescriptorBuilder(
            withFunction: true,
            architecture: .arm64,
            codeURI: self.codeURI,
            eventSource: sqsEventSource,
            environmentVariable: [:])
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    // check wether the builder creates additional queue resources
    func testLambdaCreateAdditionalResourceWithQueue() {
        
        // given
        let expected = expectedQueue()
        
        let sqsEventSource = Sqs(Queue(logicalName: "QueueTestQueue",
                                       physicalName: "test-queue")).resource()
        
        let testDeployment = MockDeploymentDescriptorBuilder(
            withFunction: true,
            architecture: .arm64,
            codeURI: self.codeURI,
            eventSource: sqsEventSource,
            environmentVariable: [:] )
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    // check wether the builder detects missing ZIP package
    func testLambdaMissingZIPPackage() {
        
        // when
        let name = "TestFunction"
        let codeUri = "/path/does/not/exist/lambda.zip"
        
        // then
        XCTAssertThrowsError(try Function.packagePath(name: name, codeUri: codeUri))
    }
    
    // check wether the builder detects existing packages
    func testLambdaExistingZIPPackage() throws {
        
        // given
        XCTAssertNoThrow(try prepareTemporaryPackageFile())
        let (tempDir, tempFile) =  try prepareTemporaryPackageFile()
        let expected = Expected.keyValue(indent: 3, keyValue: ["CodeUri": tempFile])
        
        CommandLine.arguments = ["test", "--archive-path", tempDir]
        
        let testDeployment = MockDeploymentDescriptorBuilder(
            withFunction: true,
            architecture: .arm64,
            codeURI: self.codeURI,
            eventSource: HttpApi().resource(),
            environmentVariable: ["NAME1": "VALUE1"] )
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
        
        // cleanup
        XCTAssertNoThrow(try deleteTemporaryPackageFile(tempFile))
    }
    
    func testFunctionDescription() {
        // given
        let description = "My function description"
        let expected = [Expected.keyValue(indent: 3, keyValue: ["Description": description])]
        
        // when
        let function = Function(name: functionName, codeURI: self.codeURI) {
            description
        }
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
    }
    
    func testFunctionAliasModifier() {
        // given
        let aliasName = "MyAlias"
        let sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        let expected = [Expected.keyValue(indent: 3, keyValue: ["AutoPublishAliasAllProperties": "true",
                                                                "AutoPublishAlias": aliasName,
                                                                "AutoPublishCodeSha256" : sha256])]
        
        // when
        let function = Function(name: functionName, codeURI: self.codeURI)
            .autoPublishAlias(aliasName, all: true)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
    }
    
    func testFunctionEphemeralStorageModifier() {
        // given
        let size = 1024
        let expected = [
            Expected.keyOnly(indent: 3, key: "EphemeralStorage"),
            Expected.keyValue(indent: 4, keyValue: ["Size": "\(size)"])
        ]
        
        // when
        let function = Function(name: functionName, codeURI: self.codeURI)
            .ephemeralStorage(size)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
    }
    
    func testeventInvokeConfigWithArn() {
        // given
        let validArn1 = "arn:aws:sqs:eu-central-1:012345678901:lambda-test"
        let validArn2 = "arn:aws:lambda:eu-central-1:012345678901:lambda-test"
        let expected = [
            Expected.keyOnly(indent: 3, key: "EventInvokeConfig"),
            Expected.keyValue(indent: 4, keyValue: ["MaximumEventAgeInSeconds": "900",
                                                    "MaximumRetryAttempts": "3"]),
            Expected.keyOnly(indent: 3, key: "DestinationConfig"),
            Expected.keyOnly(indent: 4, key: "OnSuccess"),
            Expected.keyValue(indent: 5, keyValue: ["Type": "SQS",
                                                    "Destination": validArn1]),
            Expected.keyOnly(indent: 4, key: "OnFailure"),
            Expected.keyValue(indent: 5, keyValue: ["Type": "Lambda",
                                                    "Destination": validArn2])
        ]
        
        // when
        let function = Function(name: functionName, codeURI: self.codeURI)
            .eventInvoke(onSuccess: validArn1,
                         onFailure: validArn2,
                         maximumEventAgeInSeconds: 900,
                         maximumRetryAttempts: 3)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
    }
    
    func testeventInvokeConfigWithSuccessQueue() {
        // given
        let queue1 = Queue(logicalName: "queue1", physicalName: "queue1").resource()
        let expected = [
            Expected.keyOnly(indent: 3, key: "EventInvokeConfig"),
            Expected.keyValue(indent: 4, keyValue: ["MaximumEventAgeInSeconds": "900",
                                                    "MaximumRetryAttempts": "3"]),
            Expected.keyOnly(indent: 4, key: "DestinationConfig"),
            Expected.keyOnly(indent: 5, key: "OnSuccess"),
            Expected.keyValue(indent: 6, keyValue: ["Type": "SQS"]),
            Expected.keyOnly(indent: 6, key: "Destination"),
            Expected.keyOnly(indent: 7, key: "Fn::GetAtt"),
            Expected.arrayKey(indent: 8, key: "queue1"),
            Expected.arrayKey(indent: 8, key: "Arn")
        ]
        
        // when
        let function = Function(name: functionName, codeURI: self.codeURI)
            .eventInvoke(onSuccess: queue1,
                         onFailure: nil,
                         maximumEventAgeInSeconds: 900,
                         maximumRetryAttempts: 3)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
        
    }
    
    func testeventInvokeConfigWithFailureQueue() {
        // given
        let queue1 = Queue(logicalName: "queue1", physicalName: "queue1").resource()
        let expected = [
            Expected.keyOnly(indent: 3, key: "EventInvokeConfig"),
            Expected.keyValue(indent: 4, keyValue: ["MaximumEventAgeInSeconds": "900",
                                                    "MaximumRetryAttempts": "3"]),
            Expected.keyOnly(indent: 4, key: "DestinationConfig"),
            Expected.keyOnly(indent: 5, key: "OnFailure"),
            Expected.keyValue(indent: 6, keyValue: ["Type": "SQS"]),
            Expected.keyOnly(indent: 6, key: "Destination"),
            Expected.keyOnly(indent: 7, key: "Fn::GetAtt"),
            Expected.arrayKey(indent: 8, key: "queue1"),
            Expected.arrayKey(indent: 8, key: "Arn")
        ]
        
        // when
        let function = Function(name: functionName, codeURI: self.codeURI)
            .eventInvoke(onSuccess: nil,
                         onFailure: queue1,
                         maximumEventAgeInSeconds: 900,
                         maximumRetryAttempts: 3)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
        
    }
    
    func testeventInvokeConfigWithSuccessLambda() {
        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "EventInvokeConfig"),
            Expected.keyValue(indent: 4, keyValue: ["MaximumEventAgeInSeconds": "900",
                                                    "MaximumRetryAttempts": "3"]),
            Expected.keyOnly(indent: 4, key: "DestinationConfig"),
            Expected.keyOnly(indent: 5, key: "OnSuccess"),
            Expected.keyValue(indent: 6, keyValue: ["Type": "Lambda"]),
            Expected.keyOnly(indent: 6, key: "Destination"),
            Expected.keyOnly(indent: 7, key: "Fn::GetAtt"),
            Expected.arrayKey(indent: 8, key: functionName),
            Expected.arrayKey(indent: 8, key: "Arn")
        ]
        
        // when
        var function = Function(name: functionName, codeURI: self.codeURI)
        let resource = function.resources()
        XCTAssertTrue(resource.count == 1)
        function = function.eventInvoke(onSuccess: resource[0],
                                        onFailure: nil,
                                        maximumEventAgeInSeconds: 900,
                                        maximumRetryAttempts: 3)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
    }
    
    func testURLConfigCors() {
        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "FunctionUrlConfig"),
            Expected.keyValue(indent: 4, keyValue: ["AuthType" : "AWS_IAM"]),
            Expected.keyValue(indent: 4, keyValue: ["InvokeMode" : "BUFFERED"]),
            Expected.keyOnly(indent: 4, key: "Cors"),
            Expected.keyValue(indent: 5, keyValue: ["MaxAge":"99",
                                                    "AllowCredentials" : "true"]),
            Expected.keyOnly(indent: 5, key: "AllowHeaders"),
            Expected.arrayKey(indent: 6, key: "header1"),
            Expected.arrayKey(indent: 6, key: "header2"),
            Expected.keyOnly(indent: 5, key: "AllowMethods"),
            Expected.arrayKey(indent: 6, key: "GET"),
            Expected.arrayKey(indent: 6, key: "POST"),
            Expected.keyOnly(indent: 5, key: "AllowOrigins"),
            Expected.arrayKey(indent: 6, key: "origin1"),
            Expected.arrayKey(indent: 6, key: "origin2"),
            Expected.keyOnly(indent: 5, key: "ExposeHeaders"),
            Expected.arrayKey(indent: 6, key: "header1"),
            Expected.arrayKey(indent: 6, key: "header2"),
        ]
        
        // when
        var function = Function(name: functionName, codeURI: self.codeURI)
        let resource = function.resources()
        XCTAssertTrue(resource.count == 1)
        function = function.urlConfig(authType: .iam,
                                      invokeMode: .buffered,
                                      allowCredentials: true,
                                      maxAge: 99) {
            AllowHeaders {
                "header1"
                "header2"
            }
            AllowMethods {
                HttpVerb.GET
                HttpVerb.POST
            }
            AllowOrigins {
                "origin1"
                "origin2"
            }
            ExposeHeaders {
                "header1"
                "header2"
            }
        }
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
        
    }
    
    func testURLConfigNoCors() {
        // given
        let expected = [
            Expected.keyOnly(indent: 3, key: "FunctionUrlConfig"),
            Expected.keyValue(indent: 4, keyValue: ["AuthType" : "AWS_IAM"]),
            Expected.keyValue(indent: 4, keyValue: ["InvokeMode" : "BUFFERED"]),
        ]
        
        // when
        var function = Function(name: functionName, codeURI: self.codeURI)
        let resource = function.resources()
        XCTAssertTrue(resource.count == 1)
        function = function.urlConfig(authType: .iam,
                                      invokeMode: .buffered)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
        
    }
    
    func testFileSystemConfig() {
        // given
        let validArn1 = "arn:aws:elasticfilesystem:eu-central-1:012345678901:access-point/fsap-abcdef01234567890"
        let validArn2 = "arn:aws:elasticfilesystem:eu-central-1:012345678901:access-point/fsap-abcdef01234567890"
        let mount1 = "/mnt/path1"
        let mount2 = "/mnt/path2"
        let expected = [
            Expected.keyOnly(indent: 3, key: "FileSystemConfigs"),
            Expected.arrayKey(indent: 4, key: ""),
            Expected.keyValue(indent: 5, keyValue: ["Arn":validArn1,
                                                    "LocalMountPath" : mount1]),
            Expected.keyValue(indent: 5, keyValue: ["Arn":validArn2,
                                                    "LocalMountPath" : mount2])
        ]
        
        // when
        let function = Function(name: functionName, codeURI: self.codeURI)
            .fileSystem(validArn1, mountPoint: mount1)
            .fileSystem(validArn2, mountPoint: mount2)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: function)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
    }
    
    //MARK: SimpleTable resource
    func testSimpleTable() {
        // given
        let expected = [
            Expected.keyOnly(indent: 1, key: "SwiftLambdaTable"),
            Expected.keyValue(indent: 2, keyValue: ["Type": "AWS::Serverless::SimpleTable"]),
            Expected.keyValue(indent: 3, keyValue: ["TableName": "swift-lambda-table"]),
            Expected.keyOnly(indent: 3, key: "PrimaryKey"),
            Expected.keyValue(indent: 4, keyValue: ["Type": "String", "Name" : "id"]),
        ]
        
        // when
        let table = Table(logicalName: "SwiftLambdaTable",
                          physicalName: "swift-lambda-table",
                          primaryKeyName: "id",
                          primaryKeyType: "String")
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: table)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
    }
    
    func testCapacityThroughput() {
        // given
        let writeCapacity = 999
        let readCapacity = 666
        let expected = [
            Expected.keyOnly(indent: 3, key: "ProvisionedThroughput"),
            Expected.keyValue(indent: 4, keyValue: ["ReadCapacityUnits": "\(readCapacity)"]),
            Expected.keyValue(indent: 4, keyValue: ["WriteCapacityUnits": "\(writeCapacity)"])
        ]
        
        // when
        let table = Table(logicalName: "SwiftLambdaTable",
                          physicalName: "swift-lambda-table",
                          primaryKeyName: "id",
                          primaryKeyType: "String")
            .provisionedThroughput(readCapacityUnits: readCapacity, writeCapacityUnits: writeCapacity)
        
        // then
        let testDeployment = MockDeploymentDescriptorBuilder(withResource: table)
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment, expected: expected))
    }
    
}
