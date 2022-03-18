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

#if canImport(Glibc)
import Glibc
#endif

@main
struct AWSLambdaPackager: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let configuration = Configuration(context: context, arguments: arguments)
        guard !configuration.products.isEmpty else {
            throw Errors.unknownProduct("no appropriate products found to package")
        }

        #if os(macOS)
        let builtProducts = try self.buildInDocker(
            packageIdentity: context.package.id,
            packageDirectory: context.package.directory,
            products: configuration.products,
            toolsProvider: { name in try context.tool(named: name).path },
            outputDirectory: configuration.outputDirectory,
            baseImage: configuration.baseImage,
            buildConfiguration: configuration.buildConfiguration,
            verboseLogging: configuration.verboseLogging
        )
        #elseif os(Linux)
        let builtProducts = try self.build(
            products: configuration.products,
            buildConfiguration: configuration.buildConfiguration,
            verboseLogging: configuration.verboseLogging
        )
        #else
        throw Errors.unsupportedPlatform("only macOS and Linux are supported")
        #endif

        let archives = try self.package(
            products: builtProducts,
            toolsProvider: { name in try context.tool(named: name).path },
            outputDirectory: configuration.outputDirectory,
            verboseLogging: configuration.verboseLogging
        )

        if !archives.isEmpty {
            print("\(archives.count) archives created:")
            for (product, archivePath) in archives {
                print("  * \(product.name) at \(archivePath.string)")
            }
        } else {
            print("no archives created")
        }
    }

    private func buildInDocker(
        packageIdentity: Package.ID,
        packageDirectory: Path,
        products: [Product],
        toolsProvider: (String) throws -> Path,
        outputDirectory: Path,
        baseImage: String,
        buildConfiguration: PackageManager.BuildConfiguration,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: Path] {
        let dockerToolPath = try toolsProvider("docker")

        /*
         if verboseLogging {
             print("-------------------------------------------------------------------------")
             print("preparing docker build image")
             print("-------------------------------------------------------------------------")
         }
         let packageDockerFilePath = packageDirectory.appending("Dockerfile")
         let tempDockerFilePath = outputDirectory.appending("Dockerfile")
         try FileManager.default.createDirectory(atPath: tempDockerFilePath.removingLastComponent().string, withIntermediateDirectories: true)
         if FileManager.default.fileExists(atPath: packageDockerFilePath.string) {
             try FileManager.default.copyItem(atPath: packageDockerFilePath.string, toPath: tempDockerFilePath.string)
         } else {
             FileManager.default.createFile(atPath: tempDockerFilePath.string, contents: "FROM \(baseImage)".data(using: .utf8))
         }
         try self.execute(
             executable: dockerToolPath,
             arguments: ["build", "-f", tempDockerFilePath.string, packageDirectory.string , "-t", "\(builderImageName)"],
             verboseLogging: verboseLogging
         )
         */

        let builderImageName = baseImage

        var builtProducts = [LambdaProduct: Path]()
        for product in products {
            if verboseLogging {
                print("-------------------------------------------------------------------------")
                print("building \"\(product.name)\" in docker")
                print("-------------------------------------------------------------------------")
            }
            //
            let buildCommand = "swift build --product \(product.name) -c \(buildConfiguration.rawValue) --static-swift-stdlib"
            try self.execute(
                executable: dockerToolPath,
                arguments: ["run", "--rm", "-v", "\(packageDirectory.string):/workspace", "-w", "/workspace", builderImageName, "bash", "-cl", buildCommand],
                verboseLogging: verboseLogging
            )
            #warning("this knows too much about the underlying implementation")
            builtProducts[.init(product)] = packageDirectory.appending([".build", buildConfiguration.rawValue, product.name])
        }
        return builtProducts
    }

    private func build(
        products: [Product],
        buildConfiguration: PackageManager.BuildConfiguration,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: Path] {
        var results = [LambdaProduct: Path]()
        for product in products {
            if verboseLogging {
                print("-------------------------------------------------------------------------")
                print("building \"\(product.name)\"")
                print("-------------------------------------------------------------------------")
            }
            var parameters = PackageManager.BuildParameters()
            parameters.configuration = buildConfiguration
            parameters.otherSwiftcFlags = ["-static-stdlib"]
            parameters.logging = verboseLogging ? .verbose : .concise

            let result = try packageManager.build(
                .product(product.name),
                parameters: parameters
            )
            guard result.builtArtifacts.count <= 1 else {
                throw Errors.unknownExecutable("too many executable artifacts found for \(product.name)")
            }
            guard let artifact = result.builtArtifacts.first else {
                throw Errors.unknownExecutable("no executable artifacts found for \(product.name)")
            }
            results[.init(product)] = artifact.path
        }
        return results
    }

    private func package(
        products: [LambdaProduct: Path],
        toolsProvider: (String) throws -> Path,
        outputDirectory: Path,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: Path] {
        let zipToolPath = try toolsProvider("zip")

        var archives = [LambdaProduct: Path]()
        for (product, artifactPath) in products {
            if verboseLogging {
                print("-------------------------------------------------------------------------")
                print("archiving \"\(product.name)\"")
                print("-------------------------------------------------------------------------")
            }

            // prep zipfile location
            let zipfilePath = outputDirectory.appending(product.name, "\(product.name).zip")
            if FileManager.default.fileExists(atPath: zipfilePath.string) {
                try FileManager.default.removeItem(atPath: zipfilePath.string)
            }
            try FileManager.default.createDirectory(atPath: zipfilePath.removingLastComponent().string, withIntermediateDirectories: true)

            #if os(macOS) || os(Linux)
            let arguments = ["--junk-paths", zipfilePath.string, artifactPath.string]
            #else
            throw Error.unsupportedPlatform("can't or don't know how to create a zipfile on this platform")
            #endif

            // run the zip tool
            try self.execute(
                executable: zipToolPath,
                arguments: arguments,
                verboseLogging: verboseLogging
            )

            archives[product] = zipfilePath

            /*

             target=".build/lambda/$executable"
             rm -rf "$target"
             mkdir -p "$target"
             cp ".build/release/$executable" "$target/"
             # add the target deps based on ldd
             ldd ".build/release/$executable" | grep swift | awk '{print $3}' | xargs cp -Lv -t "$target"
             cd "$target"
             ln -s "$executable" "bootstrap"
             zip --symlinks lambda.zip *

             */
            // docker run --rm -v "$workspace":/workspace -w /workspace/Examples/Deployment builder \
            //               bash -cl "./scripts/package.sh $executable"
        }
        return archives
    }

    @discardableResult
    private func execute(
        executable: Path,
        arguments: [String],
        customWorkingDirectory: Path? = .none,
        verboseLogging: Bool
    ) throws -> String {
        if verboseLogging {
            print("\(executable.string) \(arguments.joined(separator: " "))")
        }

        let sync = DispatchGroup()
        var output = ""
        let outputLock = NSLock()
        let outputHandler = { (fileHandle: FileHandle) in
            sync.enter()
            defer { sync.leave() }
            if !fileHandle.availableData.isEmpty, let _output = String(data: fileHandle.availableData, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(["\n"])) {
                if verboseLogging {
                    print(_output)
                    fflush(stdout)
                }
                outputLock.lock()
                output += _output
                outputLock.unlock()
            }
        }

        let stdoutPipe = Pipe()
        stdoutPipe.fileHandleForReading.readabilityHandler = outputHandler
        let stderrPipe = Pipe()
        stderrPipe.fileHandleForReading.readabilityHandler = outputHandler

        let process = Process()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.executableURL = URL(fileURLWithPath: executable.string)
        process.arguments = arguments
        if let workingDirectory = customWorkingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory.string)
        }
        process.terminationHandler = { _ in
            // Read and pass on any remaining free-form text output from the plugin.
            stderrPipe.fileHandleForReading.readabilityHandler?(stderrPipe.fileHandleForReading)
            // Read and pass on any remaining messages from the plugin.
            stdoutPipe.fileHandleForReading.readabilityHandler?(stdoutPipe.fileHandleForReading)
        }

        try process.run()
        process.waitUntilExit()

        // wait for output to be full processed
        sync.wait()

        if process.terminationStatus != 0 {
            throw Errors.processFailed(process.terminationStatus)
        }

        return output
    }
}

private struct Configuration {
    public let outputDirectory: Path
    public let products: [Product]
    public let buildConfiguration: PackageManager.BuildConfiguration
    public let staticallyLinkRuntime: Bool
    public let verboseLogging: Bool
    public let baseImage: String
    public let version: String
    public let applicationRoot: String

    public init(context: PluginContext, arguments: [String]) {
        self.outputDirectory = context.pluginWorkDirectory.appending(subpath: "\(AWSLambdaPackager.self)") // FIXME: read argument
        self.products = context.package.products.filter { $0 is ExecutableProduct } // FIXME: read argument, filter is ugly
        self.buildConfiguration = .release // FIXME: read argument
        #if os(Linux)
        self.staticallyLinkRuntime = true // FIXME: read argument
        #else
        self.staticallyLinkRuntime = false // FIXME: read argument, warn if set to true
        #endif
        self.verboseLogging = true // FIXME: read argument
        let swiftVersion = "5.6" // FIXME: read dynamically current version
        self.baseImage = "swift:\(swiftVersion)-amazonlinux2" // FIXME: read argument
        self.version = "1.0.0" // FIXME: where can we get this from? argument?
        self.applicationRoot = "/app" // FIXME: read argument
    }
}

private enum Errors: Error {
    case unsupportedPlatform(String)
    case unknownProduct(String)
    case unknownExecutable(String)
    case buildError(String)
    case failedWritingDockerfile
    case processFailed(Int32)
    case invalidProcessOutput
}

extension PackageManager.BuildResult {
    // find the executable produced by the build
    func executableArtifact(for product: Product) throws -> PackageManager.BuildResult.BuiltArtifact? {
        let executables = self.builtArtifacts.filter { $0.kind == .executable && $0.path.lastComponent == product.name }
        guard !executables.isEmpty else {
            return nil
        }
        guard executables.count == 1, let executable = executables.first else {
            return nil
        }
        return executable
    }
}

struct LambdaProduct: Hashable {
    let underlying: Product

    init(_ underlying: Product) {
        self.underlying = underlying
    }

    var name: String {
        self.underlying.name
    }

    func hash(into hasher: inout Hasher) {
        self.underlying.id.hash(into: &hasher)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.underlying.id == rhs.underlying.id
    }
}
