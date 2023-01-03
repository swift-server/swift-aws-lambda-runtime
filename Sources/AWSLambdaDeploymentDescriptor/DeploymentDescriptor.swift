// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import Foundation
import Yams

// this is the developer-visible part of the deployment decsriptor.
// the rest is generated automatically.
public protocol DeploymentDescriptor {
    
    // returns the event sources for a given Lambda function
    func eventSources(_ lambdaName: String) -> [EventSource]
    
    // returns environment variables to associate with the given Lambda function
    func environmentVariables(_ lambdaName: String) -> EnvironmentVariable

    // returns additional resources to create in the cloud (ex : a dynamoDB table)
    func addResource() -> [Resource]
}

// Generates a deployment descriptor modelized by DeploymentDefinition
extension DeploymentDescriptor {
    
    // create the SAM deployment descriptor data structure
    // this method use multiple data sources :
    // - it calls protocol functions implemented by the lambda function developer to get function-specific
    //   details (event source, environment variables)
    // - it uses command line arguments (list of lambda names)
    // - it uses some default values (like the ZIP file produced by archive command)
    public func deploymentDefinition() -> DeploymentDefinition {
        
        // Create function resources for each Lambda function
        var resources = self.lambdaNames().map { name in
            return createServerlessFunctionResource(name) // returns [Resource]
        }.flatMap{ $0 } // convert [[Resource]] to [Resource]
            
        // add developer-provided resources
        resources.append(contentsOf: self.addResource())

        // create the SAM deployment descriptor
        return SAMDeployment(resources: resources)
    }
    
    // returns environment variables to associate with the given Lambda function
    // This is a default implementation to avoid forcing the lambda developer to implement it when not needed
    public func environmentVariables(_ lambdaName: String) -> EnvironmentVariable {
        return EnvironmentVariable.none()
    }
    
    // returns additional resources to create in the cloud (ex : a dynamoDB table)
    // This is a default implementation to avoid forcing the lambda developer to implement it when not needed
    public func addResource() -> [Resource] {
        return Resource.none()
    }
    
    // entry point and main function. Lambda developer must call this function.
    public func run() {
        do {
            let sam = try toYaml()
            print(sam)
        } catch {
            print(error)
        }
    }
    
    // The lambda function names that are passed as command line argument
    // it is used to infer the directory and the name of the ZIP files
    private func lambdaNames() -> [String] {
        if CommandLine.arguments.count < 2 {
            fatalError(
                "You must pass the AWS Lambda function names as list of arguments\n\nFor example: ./deploy LambdaOne LambdaTwo"
            )
        } else {
            return [String](CommandLine.arguments[1...])
        }
    }
    
    // generate the YAML version of the deployment descriptor
    // keep the method public for testability
    public func toYaml() throws -> String {
        let deploy = deploymentDefinition()
        
        do {
            let yaml = try YAMLEncoder().encode(deploy)
            return yaml
        } catch {
            throw DeploymentEncodingError.yamlError(causedBy: error)
        }
    }

    private func createServerlessFunctionResource(_ name: String) -> [Resource] {
        
        // the default output dir for archive plugin
        // FIXME: add support for --output-path option on packager
        let package = ".build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/\(name)/\(name).zip"

        // add event sources provided by Lambda developer
        let lambdaEventSources = eventSources(name)
        
        // When SQS event source is specified, the Lambda function developer
        // might give a queue name, a queue Arn, or a queue resource.
        // When developer gives a queue name or a queue resource,
        // the event source eventually creates the queue resource and references the resource.
        // Now, we need to collect all queue resources created by SQS event sources or passed by Lambda function develper
        // to add them to the list of resources to synthetize
        var resources : [Resource] = lambdaEventSources.filter{ lambdaEventSource in
            lambdaEventSource.type == "SQS" &&
            (lambdaEventSource.properties as? SQSEventProperties)?.queue != nil
        }.compactMap { sqsEventSource in (sqsEventSource.properties as? SQSEventProperties)?.queue }

        // finally, let's build the function definition
        let serverlessFunction =  Resource.serverlessFunction(name: name,
                                                              codeUri: package,
                                                              eventSources: lambdaEventSources,
                                                              environment: environmentVariables(name))
        
        // put all resources together
        resources.append(serverlessFunction)
        return resources
    }
}
