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

import Dispatch
import Foundation
import PackagePlugin

struct Utils {
    @discardableResult
    static func execute(
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
            
            guard let _output = data.flatMap({ String(data: $0, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(["\n"])) }), !_output.isEmpty else {
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
        pipe.fileHandleForReading.readabilityHandler = { fileHandle in outputQueue.async { outputHandler(fileHandle.availableData) } }
        
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
            throw ProcessError.processFailed([executable.string] + arguments, process.terminationStatus)
        }
        
        return output
    }

    enum ProcessError: Error, CustomStringConvertible {
        case processFailed([String], Int32)

        var description: String {
            switch self {
            case .processFailed(let arguments, let code):
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
