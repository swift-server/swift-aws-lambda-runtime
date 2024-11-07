//===----------------------------------------------------------------------===//
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
//===----------------------------------------------------------------------===//

import Foundation
import PackagePlugin

@main
@available(macOS 15.0, *)
struct AWSLambdaPackager: CommandPlugin {

    let destFileName = "Sources/main.swift"

    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let configuration = try Configuration(context: context, arguments: arguments)

        if configuration.help {
            self.displayHelpMessage()
            return
        }

        let destFileURL = context.package.directoryURL.appendingPathComponent(destFileName)
        do {
            try functionWithUrlTemplate.write(to: destFileURL, atomically: true, encoding: .utf8)

            if configuration.verboseLogging {
                Diagnostics.progress("✅ Lambda function written to \(destFileName)")
                Diagnostics.progress("📦 You can now package with: 'swift package archive'")
            }

        } catch {
            Diagnostics.error("🛑Failed to create the Lambda function file: \(error)")
        }
    }

    private func displayHelpMessage() {
        print(
            """
            OVERVIEW: A SwiftPM plugin to scaffold a HelloWorld Lambda function.

            USAGE: swift package lambda-init
                                 [--help] [--verbose]
                                 [--allow-writing-to-package-directory]

            OPTIONS:
            --allow-writing-to-package-directory  Don't ask for permissions to write files.
            --verbose                             Produce verbose output for debugging.
            --help                                Show help information.
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
