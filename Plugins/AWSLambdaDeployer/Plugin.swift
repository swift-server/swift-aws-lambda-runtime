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
            throw PluginError.deployswiftDoesNotExist
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
            let helperFileUrl = URL(fileURLWithPath: helperFilePath)
            try helperCmd.write(to: helperFileUrl, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperFilePath)
            let samDeploymentDescriptor = try execute(
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
            try FileManager.default.removeItem(at: helperFileUrl)
            
            // write the generated SAM deployment decsriptor to disk
            let samDeploymentDescriptorFileUrl = URL(fileURLWithPath: samDeploymentDescriptorFilePath)
            try samDeploymentDescriptor.write(
                to: samDeploymentDescriptorFileUrl, atomically: true, encoding: .utf8)
            verboseLogging ? print("\(samDeploymentDescriptorFilePath)") : nil
            
        } catch let error as PluginError {
            print("Error while compiling Deploy.swift")
            print(error)
            print("Run the deploy plugin again with --verbose argument to receive more details.")
            throw PluginError.error(error)
        } catch {
            print("Unexpected error : \(error)")
            throw PluginError.error(error)
        }
        
    }
    
    private func findExecutable(context: PluginContext,
                                executableName: String,
                                helpMessage: String,
                                verboseLogging: Bool) throws -> Path {
        
        guard let executable = try? context.tool(named: executableName) else {
            print("Can not find `\(executableName)` executable.")
            print(helpMessage)
            throw PluginError.toolNotFound(executableName)
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
            try execute(
                executable: samExecutablePath,
                arguments: ["validate", "-t", samDeploymentDescriptorFilePath],
                logLevel: verboseLogging ? .debug : .silent)
            
        } catch let error as PluginError {
            print("Error while validating the SAM template.")
            print(error)
            print("Run the deploy plugin again with --verbose argument to receive more details.")
            throw PluginError.error(error)
        } catch {
            print("Unexpected error : \(error)")
            throw PluginError.error(error)
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

            try execute(
                executable: samExecutablePath,
                arguments: ["deploy",
                            "-t", samDeploymentDescriptorFilePath,
                            "--stack-name", stackName,
                            "--capabilities", "CAPABILITY_IAM",
                            "--resolve-s3"],
                logLevel: verboseLogging ? .debug : .silent)
        } catch let error as PluginError {
            print("Error while deploying the SAM template.")
            print(error)
            print("Run the deploy plugin again with --verbose argument to receive more details.")
            throw PluginError.error(error)
        } catch {
            print("Unexpected error : \(error)")
            throw PluginError.error(error)
        }
    }
}

private struct Configuration: CustomStringConvertible {
    public let buildConfiguration: PackageManager.BuildConfiguration
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
        let stackNamenArgument = argumentExtractor.extractOption(named: "stackname")
        
        // define deployment option
        self.noDeploy = nodeployArgument
        
        // define logging verbosity
        self.verboseLogging = verboseArgument
        
        // define build configuration, defaults to debug
        if let buildConfigurationName = configurationArgument.first {
            guard
                let buildConfiguration = PackageManager.BuildConfiguration(rawValue: buildConfigurationName)
            else {
                throw PluginError.invalidArgument(
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
            throw PluginError.invalidArgument(
                "invalid archive directory: \(self.archiveDirectory)\nthe directory does not exists")
        }
        
        // infer or consume stackname
        if let stackName = stackNamenArgument.first {
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

private enum PluginError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case processFailed([String], Int32)
    case toolNotFound(String)
    case deployswiftDoesNotExist
    case error(Error)
    
    var description: String {
        switch self {
        case .invalidArgument(let description):
            return description
        case .processFailed(let command, let code):
            return "\(command.joined(separator: " ")) failed with exit code \(code)"
        case .toolNotFound(let tool):
            return tool
        case .deployswiftDoesNotExist:
            return "Deploy.swift does not exist"
        case .error(let rootCause):
            return "Error caused by:\n\(rootCause)"
        }
    }
}

// **************************************************************
// Below this line, the code is copied from the archiver plugin
// **************************************************************
@discardableResult
private func execute(
    executable: Path,
    arguments: [String],
    customWorkingDirectory: Path? = .none,
    logLevel: ProcessLogLevel
) throws -> String {
    if logLevel >= .debug {
        print("\(executable.string) \(arguments.joined(separator: " "))")
    }
    
    var output = ""
    let outputSync = DispatchGroup()
    let outputQueue = DispatchQueue(label: "AWSLambdaPackager.output")
    let outputHandler = { (data: Data?) in
        dispatchPrecondition(condition: .onQueue(outputQueue))
        
        outputSync.enter()
        defer { outputSync.leave() }
        
        guard
            let _output = data.flatMap({
                String(data: $0, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(["\n"]))
            }), !_output.isEmpty
        else {
            return
        }
        
        output += _output + "\n"
        
        switch logLevel {
        case .silent:
            break
        case .debug(let outputIndent), .output(let outputIndent):
            print(String(repeating: " ", count: outputIndent), terminator: "")
            print(_output)
            fflush(stdout)
        }
    }
    
    let pipe = Pipe()
    pipe.fileHandleForReading.readabilityHandler = { fileHandle in
        outputQueue.async { outputHandler(fileHandle.availableData) }
    }
    
    let process = Process()
    process.standardOutput = pipe
    process.standardError = pipe
    process.executableURL = URL(fileURLWithPath: executable.string)
    process.arguments = arguments
    if let workingDirectory = customWorkingDirectory {
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory.string)
    }
    process.terminationHandler = { _ in
        outputQueue.async {
            outputHandler(try? pipe.fileHandleForReading.readToEnd())
        }
    }
    
    try process.run()
    process.waitUntilExit()
    
    // wait for output to be full processed
    outputSync.wait()
    
    if process.terminationStatus != 0 {
        // print output on failure and if not already printed
        if logLevel < .output {
            print(output)
            fflush(stdout)
        }
        throw PluginError.processFailed([executable.string] + arguments, process.terminationStatus)
    }
    
    return output
}

private enum ProcessLogLevel: Comparable {
    case silent
    case output(outputIndent: Int)
    case debug(outputIndent: Int)
    
    var naturalOrder: Int {
        switch self {
        case .silent:
            return 0
        case .output:
            return 1
        case .debug:
            return 2
        }
    }
    
    static var output: Self {
        .output(outputIndent: 2)
    }
    
    static var debug: Self {
        .debug(outputIndent: 2)
    }
    
    static func < (lhs: ProcessLogLevel, rhs: ProcessLogLevel) -> Bool {
        lhs.naturalOrder < rhs.naturalOrder
    }
}


// **************************************************************
// end copied code
// **************************************************************
