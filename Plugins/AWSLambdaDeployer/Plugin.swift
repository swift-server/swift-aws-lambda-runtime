// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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
struct AWSLambdaDeployer: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        
        let configuration = try Configuration(context: context, arguments: arguments)
        if configuration.help {
            displayHelpMessage()
            return
        }
        
        // gather file paths
        let samDeploymentDescriptorFilePath = "\(context.package.directory)/template.yaml"
        
        let swiftExecutablePath = try self.findExecutable(context: context,
                                                          executableName: "swift",
                                                          helpMessage: "Is Swift or Xcode installed? (https://www.swift.org/getting-started)",
                                                          verboseLogging: configuration.verboseLogging)
        
        let samExecutablePath = try self.findExecutable(context: context,
                                                        executableName: "sam",
                                                        helpMessage: "SAM command line is required. (brew tap aws/tap && brew install aws-sam-cli)",
                                                        verboseLogging: configuration.verboseLogging)
        
        let shellExecutablePath = try self.findExecutable(context: context,
                                                          executableName: "sh",
                                                          helpMessage: "The default shell (/bin/sh) is required to run this plugin",
                                                          verboseLogging: configuration.verboseLogging)
        
        let awsRegion = try self.getDefaultAWSRegion(context: context,
                                                     regionFromCommandLine: configuration.region,
                                                     verboseLogging: configuration.verboseLogging)
        
        // build the shared lib to compile the deployment descriptor
        try self.compileSharedLibrary(projectDirectory: context.package.directory,
                                              buildConfiguration: configuration.buildConfiguration,
                                              swiftExecutable: swiftExecutablePath,
                                              verboseLogging: configuration.verboseLogging)

        // generate the deployment descriptor
        try self.generateDeploymentDescriptor(projectDirectory: context.package.directory,
                                              buildConfiguration: configuration.buildConfiguration,
                                              swiftExecutable: swiftExecutablePath,
                                              shellExecutable: shellExecutablePath,
                                              samDeploymentDescriptorFilePath: samDeploymentDescriptorFilePath,
                                              archivePath: configuration.archiveDirectory,
                                              force: configuration.force,
                                              verboseLogging: configuration.verboseLogging)
        
                
        // check if there is a samconfig.toml file.
        // when there is no file, generate one with default values and values collected from params
        try self.checkOrCreateSAMConfigFile(projetDirectory: context.package.directory,
                                            buildConfiguration: configuration.buildConfiguration,
                                            region: awsRegion,
                                            stackName: configuration.stackName,
                                            force: configuration.force,
                                            verboseLogging: configuration.verboseLogging)
        
        // validate the template
        try self.validate(samExecutablePath: samExecutablePath,
                          samDeploymentDescriptorFilePath: samDeploymentDescriptorFilePath,
                          verboseLogging: configuration.verboseLogging)
        

        // deploy the functions
        if !configuration.noDeploy {
            try self.deploy(samExecutablePath: samExecutablePath,
                            buildConfiguration: configuration.buildConfiguration,
                            verboseLogging: configuration.verboseLogging)
        }
        
        // list endpoints
        if !configuration.noList {
            let output = try self.listEndpoints(samExecutablePath: samExecutablePath,
                                                samDeploymentDescriptorFilePath: samDeploymentDescriptorFilePath,
                                                stackName : configuration.stackName,
                                                verboseLogging: configuration.verboseLogging)
            print(output)
        }
    }

    private func compileSharedLibrary(projectDirectory: Path,
                                      buildConfiguration: PackageManager.BuildConfiguration,
                                      swiftExecutable: Path,
                                      verboseLogging: Bool) throws {
        print("-------------------------------------------------------------------------")
        print("Compile shared library")
        print("-------------------------------------------------------------------------")

        let cmd = [ "swift", "build",
                    "-c", buildConfiguration.rawValue,
                    "--product", "AWSLambdaDeploymentDescriptor"]

        try Utils.execute(executable: swiftExecutable,
                          arguments: Array(cmd.dropFirst()),
                          customWorkingDirectory: projectDirectory,
                          logLevel: verboseLogging ? .debug : .silent)

    }

    private func generateDeploymentDescriptor(projectDirectory: Path,
                                              buildConfiguration: PackageManager.BuildConfiguration,
                                              swiftExecutable: Path,
                                              shellExecutable: Path,
                                              samDeploymentDescriptorFilePath: String,
                                              archivePath: String?,
                                              force: Bool,
                                              verboseLogging: Bool) throws {
        print("-------------------------------------------------------------------------")
        print("Generating SAM deployment descriptor")
        print("-------------------------------------------------------------------------")
        
        //
        // Build and run the Deploy.swift package description
        // this generates the SAM deployment descriptor
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
            var cmd = [
                "\"\(swiftExecutable.string)\"",
                "-L \(projectDirectory)/.build/\(buildConfiguration)/",
                "-I \(projectDirectory)/.build/\(buildConfiguration)/",
                "-l\(sharedLibraryName)",
                "\"\(deploymentDescriptorFilePath)\""
            ]
            if let archive = archivePath {
                cmd = cmd + ["--archive-path", archive]
            }
            let helperCmd = cmd.joined(separator: " \\\n")
            
            if verboseLogging {
                print("-------------------------------------------------------------------------")
                print("Swift compile and run Deploy.swift")
                print("-------------------------------------------------------------------------")
                print("Swift command:\n\n\(helperCmd)\n")
            }
            
            // create and execute a plugin helper to run the "swift" command
            let helperFilePath = "\(FileManager.default.temporaryDirectory.path)/compile.sh"
            FileManager.default.createFile(atPath: helperFilePath,
                                           contents: helperCmd.data(using: .utf8),
                                           attributes: [.posixPermissions: 0o755])
            defer { try? FileManager.default.removeItem(atPath: helperFilePath) }                                           

            // running the swift command directly from the plugin does not work 🤷‍♂️
            // the below launches a bash shell script that will launch the `swift` command
            let samDeploymentDescriptor = try Utils.execute(
                executable: shellExecutable,
                arguments: ["-c", helperFilePath],
                customWorkingDirectory: projectDirectory,
                logLevel: verboseLogging ? .debug : .silent)
        //    let samDeploymentDescriptor = try Utils.execute(
        //        executable: swiftExecutable,
        //        arguments: Array(cmd.dropFirst()),
        //        customWorkingDirectory: projectDirectory,
        //        logLevel: verboseLogging ? .debug : .silent)
            
            // write the generated SAM deployment descriptor to disk
            if FileManager.default.fileExists(atPath: samDeploymentDescriptorFilePath) && !force {
                
                print("SAM deployment descriptor already exists at")
                print("\(samDeploymentDescriptorFilePath)")
                print("use --force option to overwrite it.")
                
            } else {
                
                FileManager.default.createFile(atPath: samDeploymentDescriptorFilePath,
                                               contents: samDeploymentDescriptor.data(using: .utf8))
                verboseLogging ? print("Writing file at \(samDeploymentDescriptorFilePath)") : nil
            }
            
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
    
    private func checkOrCreateSAMConfigFile(projetDirectory: Path,
                                            buildConfiguration: PackageManager.BuildConfiguration,
                                            region: String,
                                            stackName: String,
                                            force: Bool,
                                            verboseLogging: Bool) throws {
        
        let samConfigFilePath = "\(projetDirectory)/samconfig.toml" // the default value for SAM
        let samConfigTemplate = """
version = 0.1
[\(buildConfiguration)]
[\(buildConfiguration).deploy]
[\(buildConfiguration).deploy.parameters]
stack_name = "\(stackName)"
region = "\(region)"
capabilities = "CAPABILITY_IAM"
image_repositories = []
"""
        if FileManager.default.fileExists(atPath: samConfigFilePath) && !force  {
            
            print("SAM configuration file already exists at")
            print("\(samConfigFilePath)")
            print("use --force option to overwrite it.")
            
        } else {
            
            // when SAM config does not exist, create it, it will allow function developers to customize and reuse it
            FileManager.default.createFile(atPath: samConfigFilePath,
                                           contents: samConfigTemplate.data(using: .utf8))
            verboseLogging ? print("Writing file at \(samConfigFilePath)") : nil

        }
    }
    
    private func deploy(samExecutablePath: Path,
                        buildConfiguration: PackageManager.BuildConfiguration,
                        verboseLogging: Bool) throws {
        
        print("-------------------------------------------------------------------------")
        print("Deploying AWS Lambda function")
        print("-------------------------------------------------------------------------")
        do {
            
            try Utils.execute(
                executable: samExecutablePath,
                arguments: ["deploy",
                            "--config-env", buildConfiguration.rawValue,
                            "--resolve-s3"],
                logLevel: verboseLogging ? .debug : .silent)
        } catch let error as DeployerPluginError {
            print("Error while deploying the SAM template.")
            print(error)
            print("Run the deploy plugin again with --verbose argument to receive more details.")
            throw DeployerPluginError.error(error)
        } catch let error as Utils.ProcessError {
            if case .processFailed(_, let errorCode, let output) = error {
                if errorCode == 1 && output.contains("Error: No changes to deploy.") {
                    print("There is no changes to deploy.")
                } else {
                    print("ProcessError : \(error)")
                    throw DeployerPluginError.error(error)
                }
            }
        } catch {
            print("Unexpected error : \(error)")
            throw DeployerPluginError.error(error)
        }
    }
    
    private func listEndpoints(samExecutablePath: Path,
                               samDeploymentDescriptorFilePath: String,
                               stackName: String,
                               verboseLogging: Bool) throws  -> String {
        
        print("-------------------------------------------------------------------------")
        print("Listing AWS endpoints")
        print("-------------------------------------------------------------------------")
        do {
            
            return try Utils.execute(
                executable: samExecutablePath,
                arguments: ["list", "endpoints",
                            "-t", samDeploymentDescriptorFilePath,
                            "--stack-name", stackName,
                            "--output", "json"],
                logLevel: verboseLogging ? .debug : .silent)
        } catch {
            print("Unexpected error : \(error)")
            throw DeployerPluginError.error(error)
        }
    }
    

    /// provides a region name where to deploy
    /// first check for the region provided as a command line param to the plugin
    /// second check AWS_DEFAULT_REGION
    /// third check [default] profile from AWS CLI (when AWS CLI is installed)
    private func getDefaultAWSRegion(context: PluginContext,
                                     regionFromCommandLine: String?,
                                     verboseLogging: Bool) throws -> String {
        
        let helpMsg = """
        Search order : 1. [--region] plugin parameter,
                       2. AWS_DEFAULT_REGION environment variable,
                       3. [default] profile from AWS CLI (~/.aws/config)
"""

        // first check the --region plugin command line
        var result: String? = regionFromCommandLine
        
        guard result == nil else {
            print("AWS Region : \(result!) (from command line)")
            return result!
        }

        // second check the environment variable
        result = ProcessInfo.processInfo.environment["AWS_DEFAULT_REGION"]
        if result != nil && result!.isEmpty { result = nil }

        guard result == nil else {
            print("AWS Region : \(result!) (from environment variable)")
            return result!
        }

        // third, check from AWS CLI configuration when it is available
        // aws cli is optional. It is used as last resort to identify the default AWS Region
        if let awsCLIPath  = try? self.findExecutable(context: context,
                                                      executableName: "aws",
                                                      helpMessage: "aws command line is used to find default AWS region. (brew install awscli)",
                                                      verboseLogging: verboseLogging) {

            let userDir = FileManager.default.homeDirectoryForCurrentUser.path
            if FileManager.default.fileExists(atPath: "\(userDir)/.aws/config") {
                // aws --profile default configure get region
                do {
                    result = try Utils.execute(
                        executable: awsCLIPath,
                        arguments: ["--profile", "default",
                                    "configure",
                                    "get", "region"],
                        logLevel: verboseLogging ? .debug : .silent)
                    
                    result?.removeLast() // remove trailing newline char
                } catch {
                    print("Unexpected error : \(error)")
                    throw DeployerPluginError.error(error)
                }
                
                guard result == nil else {
                    print("AWS Region : \(result!) (from AWS CLI configuration)")
                    return result!
                }
            } else {
                print("AWS CLI is not configured. Type `aws configure` to create a profile.")
            }
        }

        throw DeployerPluginError.noRegionFound(helpMsg)
    }
    
    private func displayHelpMessage() {
        print("""
OVERVIEW: A swift plugin to deploy your Lambda function on your AWS account.
          
REQUIREMENTS: To use this plugin, you must have an AWS account and have `sam` installed.
              You can install sam with the following command:
              (brew tap aws/tap && brew install aws-sam-cli)

USAGE: swift package --disable-sandbox deploy [--help] [--verbose]
                                              [--archive-path <archive_path>]
                                              [--configuration <configuration>]
                                              [--force] [--nodeploy] [--nolist]
                                              [--region <aws_region>]
                                              [--stack-name <stack-name>]

OPTIONS:
    --verbose       Produce verbose output for debugging.
    --archive-path <archive-path>
                    The path where the archive plugin created the ZIP archive.
                    Must be aligned with the value passed to archive --output-path plugin.
                    (default: .build/plugins/AWSLambdaPackager/outputs/AWSLambdaPackager)
    --configuration <configuration>
                    Build for a specific configuration.
                    Must be aligned with what was used to build and package.
                    Valid values: [ debug, release ] (default: release)
    --force         Overwrites existing SAM deployment descriptor.
    --nodeploy      Generates the YAML deployment descriptor, but do not deploy.
    --nolist        Do not list endpoints.
    --stack-name <stack-name>
                    The name of the CloudFormation stack when deploying.
                    (default: the project name)
    --region        The AWS region to deploy to.
                    (default: the region of AWS CLI's default profile)
    --help          Show help information.
""")
    }
}

private struct Configuration: CustomStringConvertible {
    public let buildConfiguration: PackageManager.BuildConfiguration
    public let help: Bool
    public let noDeploy: Bool
    public let noList: Bool
    public let force: Bool
    public let verboseLogging: Bool
    public let archiveDirectory: String?
    public let stackName: String
    public let region: String?
    
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
        let noListArgument = argumentExtractor.extractFlag(named: "nolist") > 0
        let forceArgument = argumentExtractor.extractFlag(named: "force") > 0
        let configurationArgument = argumentExtractor.extractOption(named: "configuration")
        let archiveDirectoryArgument = argumentExtractor.extractOption(named: "archive-path")
        let stackNameArgument = argumentExtractor.extractOption(named: "stackname")
        let regionArgument = argumentExtractor.extractOption(named: "region")
        let helpArgument = argumentExtractor.extractFlag(named: "help") > 0
        
        // help required ?
        self.help = helpArgument
        
        // force overwrite the SAM deployment descriptor when it already exists
        self.force = forceArgument
        
        // define deployment option
        self.noDeploy = nodeployArgument
        
        // define control on list endpoints after a deployment
        self.noList = noListArgument
        
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
            self.buildConfiguration = .release
        }
        
        // use a default archive directory when none are given
        if let archiveDirectory = archiveDirectoryArgument.first {
            self.archiveDirectory = archiveDirectory
            
            // check if archive directory exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: archiveDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw DeployerPluginError.invalidArgument(
                    "invalid archive directory: \(archiveDirectory)\nthe directory does not exists")
            }
        } else {
            self.archiveDirectory = nil
        }
        
        // infer or consume stack name
        if let stackName = stackNameArgument.first {
            self.stackName = stackName
        } else {
            self.stackName = context.package.displayName
        }
        
        if let region = regionArgument.first {
            self.region = region
        } else {
            self.region = nil
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
      force: \(self.force)
      noDeploy: \(self.noDeploy)
      noList: \(self.noList)
      buildConfiguration: \(self.buildConfiguration)
      archiveDirectory: \(self.archiveDirectory ?? "none provided on command line")
      stackName: \(self.stackName)
      region: \(self.region ?? "none provided on command line")
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
    case noRegionFound(String)
    case error(Error)
    
    var description: String {
        switch self {
        case .invalidArgument(let description):
            return description
        case .toolNotFound(let tool):
            return tool
        case .deployswiftDoesNotExist:
            return "Deploy.swift does not exist"
        case .noRegionFound(let msg):
            return "Can not find an AWS Region to deploy.\n\(msg)"
        case .error(let rootCause):
            return "Error caused by:\n\(rootCause)"
        }
    }
}

