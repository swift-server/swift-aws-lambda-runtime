// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

import Dispatch
import PackagePlugin

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import struct Foundation.URL
import struct Foundation.Data
import struct Foundation.CharacterSet
import class Foundation.Process
import class Foundation.Pipe
#endif

struct Utils {
    @discardableResult
    static func execute(
        executable: URL,
        arguments: [String],
        customWorkingDirectory: URL? = nil,
        logLevel: ProcessLogLevel
    ) throws -> String {
        if logLevel >= .debug {
            print("\(executable.absoluteString) \(arguments.joined(separator: " "))")
        }

        // this shared global variable is safe because we're mutating it in a dispatch group
        // https://developer.apple.com/documentation/foundation/process/1408746-terminationhandler
        nonisolated(unsafe) var output = ""
        let outputSync = DispatchGroup()
        let outputQueue = DispatchQueue(label: "AWSLambdaPlugin.output")
        let outputHandler = { @Sendable (data: Data?) in
            dispatchPrecondition(condition: .onQueue(outputQueue))

            outputSync.enter()
            defer { outputSync.leave() }

            guard let _output = data.flatMap({ String(decoding: $0, as: UTF8.self).trimmingCharacters(in: CharacterSet(["\n"])) }), !_output.isEmpty else {
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
            outputQueue.async {
                outputHandler(fileHandle.availableData)
            }
        }

        let process = Process()
        process.standardOutput = pipe
        process.standardError = pipe
        process.executableURL = executable
        process.arguments = arguments
        if let customWorkingDirectory {
            process.currentDirectoryURL = customWorkingDirectory
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
            throw ProcessError.processFailed([executable.absoluteString] + arguments, process.terminationStatus, output)
        }

        return output
    }

    enum ProcessError: Error, CustomStringConvertible {
        case processFailed([String], Int32, String)

        var description: String {
            switch self {
            case .processFailed(let arguments, let code, _):
                return "\(arguments.joined(separator: " ")) failed with code \(code)"
            }
        }
    }

    enum ProcessLogLevel: Comparable {
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
}
