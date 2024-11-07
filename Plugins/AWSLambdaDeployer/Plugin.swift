//===----------------------------------------------------------------------===//
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
//===----------------------------------------------------------------------===//

import Foundation
import PackagePlugin

@main
@available(macOS 15.0, *)
struct AWSLambdaDeployer: CommandPlugin {


    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let configuration = try Configuration(context: context, arguments: arguments)

        if configuration.help {
            self.displayHelpMessage()
            return
        }
        
        let tool = try context.tool(named: "AWSLambdaDeployerHelper")
        try Utils.execute(executable: tool.url, arguments: [], logLevel: .debug)
    }

    private func displayHelpMessage() {
        print(
            """
            OVERVIEW: A SwiftPM plugin to deploy a Lambda function.

            USAGE: swift package lambda-deploy
                                 [--with-url]
                                 [--help] [--verbose]

            OPTIONS:
            --with-url     Add an URL to access the Lambda function          
            --verbose      Produce verbose output for debugging.
            --help         Show help information.
            """
        )
    }
}

private struct Configuration: CustomStringConvertible {
    public let help: Bool
    public let verboseLogging: Bool

    public init(
        context: PluginContext,
        arguments: [String]
    ) throws {
        var argumentExtractor = ArgumentExtractor(arguments)
        let verboseArgument = argumentExtractor.extractFlag(named: "verbose") > 0
        let helpArgument = argumentExtractor.extractFlag(named: "help") > 0

        // help required ?
        self.help = helpArgument

        // verbose logging required ?
        self.verboseLogging = verboseArgument
    }

    var description: String {
        """
        {
          verboseLogging: \(self.verboseLogging)
        }
        """
    }
}
