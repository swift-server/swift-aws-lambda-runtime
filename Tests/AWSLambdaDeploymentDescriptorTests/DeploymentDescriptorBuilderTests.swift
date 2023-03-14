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
    
    func testGenericFunction() {
        
        // given
        let expected = [expectedSAMHeaders(),
                        expectedFunction(),
                        expectedEnvironmentVariables(), 
                        expectedHttpAPi()].flatMap { $0 }
        
        let testDeployment = MockDeploymentDescriptorBuilder(
            withFunction: true,
            architecture: .arm64,
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
            eventSource: sqsEventSource,
            environmentVariable: [:] )
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    // check wether the builder detects missing ZIP package
    func testLambdaMissingZIPPackage() {
        
        // given
        let expected = """
"CodeUri":"ERROR"
"""
        
        let testDeployment = MockDeploymentDescriptorBuilder(
            withFunction: true,
            architecture: .arm64,
            eventSource: HttpApi().resource(),
            environmentVariable: ["NAME1": "VALUE1"] )
        
        XCTAssertTrue(generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
    }
    
    // check wether the builder detects existing packages
    func testLambdaExistingZIPPackage() {
        
        // given
        let (tempDir, tempFile) = prepareTemporaryPackageFile()
        
        let expected = """
"CodeUri":"\(tempFile)"
""".replacingOccurrences(of: "/", with: "\\/")
        
        CommandLine.arguments = ["test", "--archive-path", tempDir]
        
        let testDeployment = MockDeploymentDescriptorBuilder(
            withFunction: true,
            architecture: .arm64,
            eventSource: HttpApi().resource(),
            environmentVariable: ["NAME1": "VALUE1"] )
        
        XCTAssertTrue(self.generateAndTestDeploymentDescriptor(deployment: testDeployment,
                                                               expected: expected))
        
        // cleanup
        deleteTemporaryPackageFile(tempFile)
    }
    
    private func prepareTemporaryPackageFile() -> (String,String) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let packageDir = MockDeploymentDescriptorBuilder.packageDir()
        let packageZip = MockDeploymentDescriptorBuilder.packageZip()
        XCTAssertNoThrow(try fm.createDirectory(atPath: tempDir.path + packageDir,
                                                withIntermediateDirectories: true))
        let tempFile = tempDir.path + packageDir + packageZip
        XCTAssertTrue(fm.createFile(atPath: tempFile, contents: nil))
        return (tempDir.path, tempFile)
    }
    
    private func deleteTemporaryPackageFile(_ file: String) {
        let fm = FileManager.default
        XCTAssertNoThrow(try fm.removeItem(atPath: file))
    }
}
