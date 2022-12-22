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
        guard !configuration.products.isEmpty else {
            throw Errors.unknownProduct("no appropriate products found to deploy")
        }

        let samExecutable = try context.tool(named: "sam")
        let samExecutableUrl = URL(fileURLWithPath: samExecutable.path.string)
        let deploymentDescriptorExecutableUrl = configuration.deployExecutable
        if configuration.verboseLogging {
            print("-------------------------------------------------------------------------")
            print("executables")
            print("-------------------------------------------------------------------------")
            print("SAM Executable : \(samExecutableUrl)")
            print("Deployment Descriptor Executable : \(deploymentDescriptorExecutableUrl)")
        }

        let currentDirectory = FileManager.default.currentDirectoryPath
        let samDeploymentDescriptorUrl = URL(fileURLWithPath: currentDirectory)
                                        .appendingPathComponent("sam.yaml")
        do {
            print("-------------------------------------------------------------------------")
            print("generating SAM deployment descriptor")
            configuration.verboseLogging ? print("\(samDeploymentDescriptorUrl)") : nil
            print("-------------------------------------------------------------------------")
            let samDeploymentDescriptor = try self.execute(
                executable: deploymentDescriptorExecutableUrl,
                arguments: configuration.products.compactMap { $0.name },
                logLevel: configuration.verboseLogging ? .debug : .silent)
            try samDeploymentDescriptor.write(
                to: samDeploymentDescriptorUrl, atomically: true, encoding: .utf8)

            print("-------------------------------------------------------------------------")
            print("validating SAM deployment descriptor")
            print("-------------------------------------------------------------------------")
            try self.execute(
                executable: samExecutableUrl,
                arguments: ["validate", "-t", samDeploymentDescriptorUrl.path],
                logLevel: configuration.verboseLogging ? .debug : .silent)

            if !configuration.noDeploy {
                print("-------------------------------------------------------------------------")
                print("deploying AWS Lambda function")
                print("-------------------------------------------------------------------------")
                try self.execute(
                    executable: samExecutableUrl,
                    arguments: ["deploy", "-t", samDeploymentDescriptorUrl.path],
                    logLevel: configuration.verboseLogging ? .debug : .silent)
            }
        } catch Errors.processFailed(_, _) {
            print("The generated SAM template is invalid or can not be deployed.")
            if configuration.verboseLogging {
                print("File at : \(samDeploymentDescriptorUrl)")
            } else {
                print("Run the command again with --verbose argument to receive more details.")
            }
        } catch {
            print("Can not execute file at:")
            print("\(deploymentDescriptorExecutableUrl.path)")
            print("or at:")
            print("\(samExecutableUrl.path)")
            print("Is SAM installed ? (brew tap aws/tap && brew install aws-sam-cli)")
            print("Did you add a 'Deploy' executable target into your project's Package.swift ?")
            print("Did you build the release version ? (swift build -c release)")
        }
    }

    @discardableResult
    private func execute(
        executable: URL,
        arguments: [String],
        customWorkingDirectory: URL? = nil,
        logLevel: ProcessLogLevel
    ) throws -> String {
        try self.execute(
            executable: Path(executable.path),
            arguments: arguments,
            customWorkingDirectory: customWorkingDirectory == nil
            ? nil : Path(customWorkingDirectory!.path),
            logLevel: logLevel)
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
            throw Errors.processFailed([executable.string] + arguments, process.terminationStatus)
        }

        return output
    }
    // **************************************************************
    // end copied code
    // **************************************************************
}

private struct Configuration: CustomStringConvertible {
    public let products: [Product]
    public let deployExecutable: URL
    public let explicitProducts: Bool
    public let buildConfiguration: PackageManager.BuildConfiguration
    public let noDeploy: Bool
    public let verboseLogging: Bool

    public init(
        context: PluginContext,
        arguments: [String]
    ) throws {

        // extrcat command line arguments
        var argumentExtractor = ArgumentExtractor(arguments)
        let nodeployArgument = argumentExtractor.extractFlag(named: "nodeploy") > 0
        let verboseArgument = argumentExtractor.extractFlag(named: "verbose") > 0
        let productsArgument = argumentExtractor.extractOption(named: "products")
        let configurationArgument = argumentExtractor.extractOption(named: "configuration")

        // define deployment option
        self.noDeploy = nodeployArgument

        // define logging verbosity
        self.verboseLogging = verboseArgument

        // define products
        self.explicitProducts = !productsArgument.isEmpty
        if self.explicitProducts {
            let products = try context.package.products(named: productsArgument)
            for product in products {
                guard product is ExecutableProduct else {
                    throw Errors.invalidArgument(
                        "product named '\(product.name)' is not an executable product")
                }
            }
            self.products = products

        } else {
            self.products = context.package.products.filter {
                $0 is ExecutableProduct && $0.name != "Deploy"
            }
        }

        // define build configuration
        if let buildConfigurationName = configurationArgument.first {
            guard
                let buildConfiguration = PackageManager.BuildConfiguration(rawValue: buildConfigurationName)
            else {
                throw Errors.invalidArgument(
                    "invalid build configuration named '\(buildConfigurationName)'")
            }
            self.buildConfiguration = buildConfiguration
        } else {
            self.buildConfiguration = .release
        }

        // search for deployment configuration executable
        let deployProducts = context.package.products.filter { $0.name == "Deploy" }
        guard deployProducts.count == 1,
              deployProducts[0].targets.count == 1
        else {
            throw Errors.deploymentDescriptorProductNotFound("Deploy")
        }
        for t in deployProducts[0].targets {
            print("\(t.name) - \(t.directory)")
        }
#if arch(arm64)
        let arch = "arm64-apple-macosx"
#else
        let arch = "x86_64-apple-macosx"
#endif
        self.deployExecutable = URL(fileURLWithPath: deployProducts[0].targets[0].directory.string)
            .deletingLastPathComponent()
            .appendingPathComponent(".build/\(arch)/\(self.buildConfiguration)/Deploy")

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
      products: \(self.products.map(\.name))
      buildConfiguration: \(self.buildConfiguration)
      deployExecutable: \(self.deployExecutable)
    }
    """
    }
}

private enum Errors: Error, CustomStringConvertible {
    case invalidArgument(String)
    case unsupportedPlatform(String)
    case unknownProduct(String)
    case productExecutableNotFound(String)
    case deploymentDescriptorProductNotFound(String)
    case processFailed([String], Int32)

    var description: String {
        switch self {
        case .invalidArgument(let description):
            return description
        case .unsupportedPlatform(let description):
            return description
        case .unknownProduct(let description):
            return description
        case .productExecutableNotFound(let product):
            return "product executable not found '\(product)'"
        case .deploymentDescriptorProductNotFound(let product):
            return "your project Package.swift has no executable named '\(product)'"
        case .processFailed(let arguments, let code):
            return "\(arguments.joined(separator: " ")) failed with code \(code)"
        }
    }
}

// **************************************************************
// Below this line, the code is copied from the archiver plugin
// **************************************************************

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
