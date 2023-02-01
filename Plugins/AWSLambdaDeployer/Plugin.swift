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

import Dispatch
import Foundation
import PackagePlugin

@main
struct AWSLambdaPackager: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        
        let configuration = try Configuration(context: context, arguments: arguments)
        if configuration.help {
            displayHelpMessage()
            return
        }
        
        // gather file paths
        let samDeploymentDescriptorFilePath = "\(context.package.directory)/sam.json"
        
        let swiftExecutablePath = try self.findExecutable(context: context,
                                                          executableName: "swift",
                                                          helpMessage: "Is Swift or Xcode installed? (https://www.swift.org/getting-started)",
                                                          verboseLogging: configuration.verboseLogging)
        
        let samExecutablePath = try self.findExecutable(context: context,
                                                        executableName: "sam",
                                                        helpMessage: "Is SAM installed ? (brew tap aws/tap && brew install aws-sam-cli)",
                                                        verboseLogging: configuration.verboseLogging)
        
        // generate the deployment descriptor
        try self.generateDeploymentDescriptor(projectDirectory: context.package.directory,
                                              buildConfiguration: configuration.buildConfiguration,
                                              swiftExecutable: swiftExecutablePath,
                                              samDeploymentDescriptorFilePath: samDeploymentDescriptorFilePath,
                                              archivePath: configuration.archiveDirectory,
                                              verboseLogging: configuration.verboseLogging)
        
        
        // validate the template
        try self.validate(samExecutablePath: samExecutablePath,
                          samDeploymentDescriptorFilePath: samDeploymentDescriptorFilePath,
                          verboseLogging: configuration.verboseLogging)
        
        // deploy the functions
        if !configuration.noDeploy {
            try self.deploy(samExecutablePath: samExecutablePath,
                            samDeploymentDescriptorFilePath: samDeploymentDescriptorFilePath,
                            stackName : configuration.stackName,
                            verboseLogging: configuration.verboseLogging)
        }
    }
    
    private func generateDeploymentDescriptor(projectDirectory: Path,
                                              buildConfiguration: PackageManager.BuildConfiguration,
                                              swiftExecutable: Path,
                                              samDeploymentDescriptorFilePath: String,
                                              archivePath: String,
                                              verboseLogging: Bool) throws {
        print("-------------------------------------------------------------------------")
        print("Generating SAM deployment descriptor")
        print("-------------------------------------------------------------------------")
        
        //
        // Build and run the Deploy.swift package description
        // this generates the SAM deployment decsriptor
        //
        let deploymentDescriptorFileName = "Deploy.swift"
        let deploymentDescriptorFilePath = "\(projectDirectory)/\(deploymentDescriptorFileName)"
        let sharedLibraryName = "AWSLambdaDeploymentDescriptor" // provided by the swift lambda runtime
        
        // Check if Deploy.swift exists. Stop when it does not exist.
        guard FileManager.default.fileExists(atPath: deploymentDescriptorFilePath) else {
            print("`Deploy.Swift` file not found in directory \(projectDirectory)")
            throw DeployerPluginError.deployswiftDoesNotExist
        }
        
        do {
            let cmd = [
                swiftExecutable.string,
                "-L \(projectDirectory)/.build/\(buildConfiguration)/",
                "-I \(projectDirectory)/.build/\(buildConfiguration)/",
                "-l\(sharedLibraryName)",
                deploymentDescriptorFilePath,
                "--archive-path", archivePath
            ]
            let helperCmd = cmd.joined(separator: " \\\n")
            
            if verboseLogging {
                print("-------------------------------------------------------------------------")
                print("Swift compile and run Deploy.swift")
                print("-------------------------------------------------------------------------")
                print("Swift command:\n\n\(helperCmd)\n")
            }
            
            // create and execute a plugin helper to run the "swift" command
            let helperFilePath = "\(projectDirectory)/compile.sh"
            FileManager.default.createFile(atPath: helperFilePath,
                                           contents: helperCmd.data(using: .utf8),
                                           attributes: [.posixPermissions: 0o755])
            let samDeploymentDescriptor = try Utils.execute(
                executable: Path("/bin/bash"),
                arguments: ["-c", helperFilePath],
                customWorkingDirectory: projectDirectory,
                logLevel: verboseLogging ? .debug : .silent)
            // running the swift command directly from the plugin does not work 🤷‍♂️
            //            let samDeploymentDescriptor = try execute(
            //                executable: swiftExecutable.path,
            //                arguments: Array(cmd.dropFirst()),
            //                customWorkingDirectory: context.package.directory,
            //                logLevel: configuration.verboseLogging ? .debug : .silent)
            try FileManager.default.removeItem(atPath: helperFilePath)
            
            // write the generated SAM deployment decsriptor to disk
            FileManager.default.createFile(atPath: samDeploymentDescriptorFilePath,
                                           contents: samDeploymentDescriptor.data(using: .utf8))
            verboseLogging ? print("\(samDeploymentDescriptorFilePath)") : nil
            
        } catch let error as DeployerPluginError {
            print("Error while compiling Deploy.swift")
            print(error)
            print("Run the deploy plugin again with --verbose argument to receive more details.")
            throw DeployerPluginError.error(error)
        } catch {
            print("Unexpected error : \(error)")
            throw DeployerPluginError.error(error)
        }
        
    }
    
    private func findExecutable(context: PluginContext,
                                executableName: String,
                                helpMessage: String,
                                verboseLogging: Bool) throws -> Path {
        
        guard let executable = try? context.tool(named: executableName) else {
            print("Can not find `\(executableName)` executable.")
            print(helpMessage)
            throw DeployerPluginError.toolNotFound(executableName)
        }
        
        if verboseLogging {
            print("-------------------------------------------------------------------------")
            print("\(executableName) executable : \(executable.path)")
            print("-------------------------------------------------------------------------")
        }
        return executable.path
    }
    
    private func validate(samExecutablePath: Path,
                          samDeploymentDescriptorFilePath: String,
                          verboseLogging: Bool) throws {
        
        print("-------------------------------------------------------------------------")
        print("Validating SAM deployment descriptor")
        print("-------------------------------------------------------------------------")
        
        do {
            try Utils.execute(
                executable: samExecutablePath,
                arguments: ["validate",
                            "-t", samDeploymentDescriptorFilePath,
                            "--lint"],
                logLevel: verboseLogging ? .debug : .silent)
            
        } catch let error as DeployerPluginError {
            print("Error while validating the SAM template.")
            print(error)
            print("Run the deploy plugin again with --verbose argument to receive more details.")
            throw DeployerPluginError.error(error)
        } catch {
            print("Unexpected error : \(error)")
            throw DeployerPluginError.error(error)
        }
    }
    
    private func deploy(samExecutablePath: Path,
                        samDeploymentDescriptorFilePath: String,
                        stackName: String,
                        verboseLogging: Bool) throws {
        
        //TODO: check if there is a samconfig.toml file.
        // when there is no file, generate one with default data or data collected from params
        
        
        print("-------------------------------------------------------------------------")
        print("Deploying AWS Lambda function")
        print("-------------------------------------------------------------------------")
        do {
            
            try Utils.execute(
                executable: samExecutablePath,
                arguments: ["deploy",
                            "-t", samDeploymentDescriptorFilePath,
                            "--stack-name", stackName,
                            "--capabilities", "CAPABILITY_IAM",
                            "--resolve-s3"],
                logLevel: verboseLogging ? .debug : .silent)
        } catch let error as DeployerPluginError {
            print("Error while deploying the SAM template.")
            print(error)
            print("Run the deploy plugin again with --verbose argument to receive more details.")
            throw DeployerPluginError.error(error)
        } catch {
            print("Unexpected error : \(error)")
            throw DeployerPluginError.error(error)
        }
    }
    
    private func displayHelpMessage() {
        print("""
OVERVIEW: A swift plugin to deploy your Lambda function on your AWS account.
          
REQUIREMENTS: To use this plugin, you must have an AWS account and have `sam` installed.
              You can install sam with the following command:
              (brew tap aws/tap && brew install aws-sam-cli)

USAGE: swift package --disable-sandbox deploy [--help] [--verbose] [--nodeploy] [--configuration <configuration>] [--archive-path <archive_path>] [--stack-name <stack-name>]

OPTIONS:
    --verbose       Produce verbose output for debugging.
    --nodeploy      Generates the JSON deployment descriptor, but do not deploy.
    --configuration <configuration>
                    Build for a specific configuration.
                    Must be aligned with what was used to build and package.
                    Valid values: [ debug, release ] (default: debug)
    --archive-path <archive-path>
                    The path where the archive plugin created the ZIP archive.
                    Must be aligned with the value passed to archive --output-path.
                    (default: .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager)
    --stack-name <stack-name>
                    The name of the CloudFormation stack when deploying.
                    (default: the project name)
    --help          Show help information.
""")
    }
}

private struct Configuration: CustomStringConvertible {
    public let buildConfiguration: PackageManager.BuildConfiguration
    public let help: Bool
    public let noDeploy: Bool
    public let verboseLogging: Bool
    public let archiveDirectory: String
    public let stackName: String
    
    private let context: PluginContext
    
    public init(
        context: PluginContext,
        arguments: [String]
    ) throws {
        
        self.context = context // keep a reference for self.description
        
        // extract command line arguments
        var argumentExtractor = ArgumentExtractor(arguments)
        let nodeployArgument = argumentExtractor.extractFlag(named: "nodeploy") > 0
        let verboseArgument = argumentExtractor.extractFlag(named: "verbose") > 0
        let configurationArgument = argumentExtractor.extractOption(named: "configuration")
        let archiveDirectoryArgument = argumentExtractor.extractOption(named: "archive-path")
        let stackNameArgument = argumentExtractor.extractOption(named: "stackname")
        let helpArgument = argumentExtractor.extractFlag(named: "help") > 0
        
        // help required ?
        self.help = helpArgument
        
        // define deployment option
        self.noDeploy = nodeployArgument
        
        // define logging verbosity
        self.verboseLogging = verboseArgument
        
        // define build configuration, defaults to debug
        if let buildConfigurationName = configurationArgument.first {
            guard
                let buildConfiguration = PackageManager.BuildConfiguration(rawValue: buildConfigurationName)
            else {
                throw DeployerPluginError.invalidArgument(
                    "invalid build configuration named '\(buildConfigurationName)'")
            }
            self.buildConfiguration = buildConfiguration
        } else {
            self.buildConfiguration = .debug
        }
        
        // use a default archive directory when none are given
        if let archiveDirectory = archiveDirectoryArgument.first {
            self.archiveDirectory = archiveDirectory
        } else {
            self.archiveDirectory = "\(context.package.directory.string)/.build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager/"
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: self.archiveDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DeployerPluginError.invalidArgument(
                "invalid archive directory: \(self.archiveDirectory)\nthe directory does not exists")
        }
        
        // infer or consume stackname
        if let stackName = stackNameArgument.first {
            self.stackName = stackName
        } else {
            self.stackName = context.package.displayName 
        }
        
        if self.verboseLogging {
            print("-------------------------------------------------------------------------")
            print("configuration")
            print("-------------------------------------------------------------------------")
            print(self)
        }
    }
    
    var description: String {
    """
    {
      verbose: \(self.verboseLogging)
      noDeploy: \(self.noDeploy)
      buildConfiguration: \(self.buildConfiguration)
      archiveDirectory: \(self.archiveDirectory)
      stackName: \(self.stackName)
      
      Plugin directory: \(self.context.pluginWorkDirectory)
      Project directory: \(self.context.package.directory)
    }
    """
    }
}

private enum DeployerPluginError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case toolNotFound(String)
    case deployswiftDoesNotExist
    case error(Error)
    
    var description: String {
        switch self {
        case .invalidArgument(let description):
            return description
        case .toolNotFound(let tool):
            return tool
        case .deployswiftDoesNotExist:
            return "Deploy.swift does not exist"
        case .error(let rootCause):
            return "Error caused by:\n\(rootCause)"
        }
    }
}

