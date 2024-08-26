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

#if os(macOS)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#else
#error("Unsupported platform")
#endif

@main
struct AWSLambdaPackager: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let configuration = try Configuration(context: context, arguments: arguments)
        guard !configuration.products.isEmpty else {
            throw Errors.unknownProduct("no appropriate products found to package")
        }

        if configuration.products.count > 1 && !configuration.explicitProducts {
            let productNames = configuration.products.map(\.name)
            print(
                "No explicit products named, building all executable products: '\(productNames.joined(separator: "', '"))'"
            )
        }

        let builtProducts: [LambdaProduct: Path]
        if self.isAmazonLinux2() {
            // build directly on the machine
            builtProducts = try self.build(
                packageIdentity: context.package.id,
                products: configuration.products,
                buildConfiguration: configuration.buildConfiguration,
                verboseLogging: configuration.verboseLogging
            )
        } else {
            // build with docker
            builtProducts = try self.buildInDocker(
                packageIdentity: context.package.id,
                packageDirectory: context.package.directory,
                products: configuration.products,
                toolsProvider: { name in try context.tool(named: name).path },
                outputDirectory: configuration.outputDirectory,
                baseImage: configuration.baseDockerImage,
                disableDockerImageUpdate: configuration.disableDockerImageUpdate,
                buildConfiguration: configuration.buildConfiguration,
                verboseLogging: configuration.verboseLogging
            )
        }

        // create the archive
        let archives = try self.package(
            packageName: context.package.displayName,
            products: builtProducts,
            toolsProvider: { name in try context.tool(named: name).path },
            outputDirectory: configuration.outputDirectory,
            verboseLogging: configuration.verboseLogging
        )

        print(
            "\(archives.count > 0 ? archives.count.description : "no") archive\(archives.count != 1 ? "s" : "") created"
        )
        for (product, archivePath) in archives {
            print("  * \(product.name) at \(archivePath.string)")
        }
    }

    private func buildInDocker(
        packageIdentity: Package.ID,
        packageDirectory: Path,
        products: [Product],
        toolsProvider: (String) throws -> Path,
        outputDirectory: Path,
        baseImage: String,
        disableDockerImageUpdate: Bool,
        buildConfiguration: PackageManager.BuildConfiguration,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: Path] {
        let dockerToolPath = try toolsProvider("docker")

        print("-------------------------------------------------------------------------")
        print("building \"\(packageIdentity)\" in docker")
        print("-------------------------------------------------------------------------")

        if !disableDockerImageUpdate {
            // update the underlying docker image, if necessary
            print("updating \"\(baseImage)\" docker image")
            try self.execute(
                executable: dockerToolPath,
                arguments: ["pull", baseImage],
                logLevel: .output
            )
        }

        // get the build output path
        let buildOutputPathCommand = "swift build -c \(buildConfiguration.rawValue) --show-bin-path"
        let dockerBuildOutputPath = try self.execute(
            executable: dockerToolPath,
            arguments: [
                "run", "--rm", "-v", "\(packageDirectory.string):/workspace", "-w", "/workspace", baseImage, "bash",
                "-cl", buildOutputPathCommand,
            ],
            logLevel: verboseLogging ? .debug : .silent
        )
        guard let buildPathOutput = dockerBuildOutputPath.split(separator: "\n").last else {
            throw Errors.failedParsingDockerOutput(dockerBuildOutputPath)
        }
        let buildOutputPath = Path(
            buildPathOutput.replacingOccurrences(of: "/workspace", with: packageDirectory.string)
        )

        // build the products
        var builtProducts = [LambdaProduct: Path]()
        for product in products {
            print("building \"\(product.name)\"")
            let buildCommand =
                "swift build -c \(buildConfiguration.rawValue) --product \(product.name) --static-swift-stdlib"
            if ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"] != nil {
                // when developing locally, we must have the full swift-aws-lambda-runtime project in the container
                // because Examples' Package.swift have a dependency on ../..
                // just like Package.swift's examples assume ../.., we assume we are two levels below the root project
                let lastComponent = packageDirectory.lastComponent
                let beforeLastComponent = packageDirectory.removingLastComponent().lastComponent
                try self.execute(
                    executable: dockerToolPath,
                    arguments: [
                        "run", "--rm", "--env", "LAMBDA_USE_LOCAL_DEPS=true", "-v",
                        "\(packageDirectory.string)/../..:/workspace", "-w",
                        "/workspace/\(beforeLastComponent)/\(lastComponent)", baseImage, "bash", "-cl", buildCommand,
                    ],
                    logLevel: verboseLogging ? .debug : .output
                )
            } else {
                try self.execute(
                    executable: dockerToolPath,
                    arguments: [
                        "run", "--rm", "-v", "\(packageDirectory.string):/workspace", "-w", "/workspace", baseImage,
                        "bash", "-cl", buildCommand,
                    ],
                    logLevel: verboseLogging ? .debug : .output
                )
            }
            let productPath = buildOutputPath.appending(product.name)
            guard FileManager.default.fileExists(atPath: productPath.string) else {
                Diagnostics.error("expected '\(product.name)' binary at \"\(productPath.string)\"")
                throw Errors.productExecutableNotFound(product.name)
            }
            builtProducts[.init(product)] = productPath
        }
        return builtProducts
    }

    private func build(
        packageIdentity: Package.ID,
        products: [Product],
        buildConfiguration: PackageManager.BuildConfiguration,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: Path] {
        print("-------------------------------------------------------------------------")
        print("building \"\(packageIdentity)\"")
        print("-------------------------------------------------------------------------")

        var results = [LambdaProduct: Path]()
        for product in products {
            print("building \"\(product.name)\"")
            var parameters = PackageManager.BuildParameters()
            parameters.configuration = buildConfiguration
            parameters.otherSwiftcFlags = ["-static-stdlib"]
            parameters.logging = verboseLogging ? .verbose : .concise

            let result = try packageManager.build(
                .product(product.name),
                parameters: parameters
            )
            guard let artifact = result.executableArtifact(for: product) else {
                throw Errors.productExecutableNotFound(product.name)
            }
            results[.init(product)] = artifact.path
        }
        return results
    }

    // TODO: explore using ziplib or similar instead of shelling out
    private func package(
        packageName: String,
        products: [LambdaProduct: Path],
        toolsProvider: (String) throws -> Path,
        outputDirectory: Path,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: Path] {
        let zipToolPath = try toolsProvider("zip")

        var archives = [LambdaProduct: Path]()
        for (product, artifactPath) in products {
            print("-------------------------------------------------------------------------")
            print("archiving \"\(product.name)\"")
            print("-------------------------------------------------------------------------")

            // prep zipfile location
            let workingDirectory = outputDirectory.appending(product.name)
            let zipfilePath = workingDirectory.appending("\(product.name).zip")
            if FileManager.default.fileExists(atPath: workingDirectory.string) {
                try FileManager.default.removeItem(atPath: workingDirectory.string)
            }
            try FileManager.default.createDirectory(atPath: workingDirectory.string, withIntermediateDirectories: true)

            // rename artifact to "bootstrap"
            let relocatedArtifactPath = workingDirectory.appending(artifactPath.lastComponent)
            let symbolicLinkPath = workingDirectory.appending("bootstrap")
            try FileManager.default.copyItem(atPath: artifactPath.string, toPath: relocatedArtifactPath.string)
            try FileManager.default.createSymbolicLink(
                atPath: symbolicLinkPath.string,
                withDestinationPath: relocatedArtifactPath.lastComponent
            )

            var arguments: [String] = []
            #if os(macOS) || os(Linux)
            arguments = [
                "--recurse-paths",
                "--symlinks",
                zipfilePath.lastComponent,
                relocatedArtifactPath.lastComponent,
                symbolicLinkPath.lastComponent,
            ]
            #else
            throw Errors.unsupportedPlatform("can't or don't know how to create a zip file on this platform")
            #endif

            // add resources
            let artifactDirectory = artifactPath.removingLastComponent()
            let resourcesDirectoryName = "\(packageName)_\(product.name).resources"
            let resourcesDirectory = artifactDirectory.appending(resourcesDirectoryName)
            let relocatedResourcesDirectory = workingDirectory.appending(resourcesDirectoryName)
            if FileManager.default.fileExists(atPath: resourcesDirectory.string) {
                try FileManager.default.copyItem(
                    atPath: resourcesDirectory.string,
                    toPath: relocatedResourcesDirectory.string
                )
                arguments.append(resourcesDirectoryName)
            }

            // run the zip tool
            try self.execute(
                executable: zipToolPath,
                arguments: arguments,
                customWorkingDirectory: workingDirectory,
                logLevel: verboseLogging ? .debug : .silent
            )

            archives[product] = zipfilePath
        }
        return archives
    }

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

    private func isAmazonLinux2() -> Bool {
        if let data = FileManager.default.contents(atPath: "/etc/system-release"),
            let release = String(data: data, encoding: .utf8)
        {
            return release.hasPrefix("Amazon Linux release 2")
        } else {
            return false
        }
    }
}

private struct Configuration: CustomStringConvertible {
    public let outputDirectory: Path
    public let products: [Product]
    public let explicitProducts: Bool
    public let buildConfiguration: PackageManager.BuildConfiguration
    public let verboseLogging: Bool
    public let baseDockerImage: String
    public let disableDockerImageUpdate: Bool

    public init(
        context: PluginContext,
        arguments: [String]
    ) throws {
        var argumentExtractor = ArgumentExtractor(arguments)
        let verboseArgument = argumentExtractor.extractFlag(named: "verbose") > 0
        let outputPathArgument = argumentExtractor.extractOption(named: "output-path")
        let productsArgument = argumentExtractor.extractOption(named: "products")
        let configurationArgument = argumentExtractor.extractOption(named: "configuration")
        let swiftVersionArgument = argumentExtractor.extractOption(named: "swift-version")
        let baseDockerImageArgument = argumentExtractor.extractOption(named: "base-docker-image")
        let disableDockerImageUpdateArgument = argumentExtractor.extractFlag(named: "disable-docker-image-update") > 0

        self.verboseLogging = verboseArgument

        if let outputPath = outputPathArgument.first {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: outputPath, isDirectory: &isDirectory), isDirectory.boolValue
            else {
                throw Errors.invalidArgument("invalid output directory '\(outputPath)'")
            }
            self.outputDirectory = Path(outputPath)
        } else {
            self.outputDirectory = context.pluginWorkDirectory.appending(subpath: "\(AWSLambdaPackager.self)")
        }

        self.explicitProducts = !productsArgument.isEmpty
        if self.explicitProducts {
            let products = try context.package.products(named: productsArgument)
            for product in products {
                guard product is ExecutableProduct else {
                    throw Errors.invalidArgument("product named '\(product.name)' is not an executable product")
                }
            }
            self.products = products

        } else {
            self.products = context.package.products.filter { $0 is ExecutableProduct }
        }

        if let buildConfigurationName = configurationArgument.first {
            guard let buildConfiguration = PackageManager.BuildConfiguration(rawValue: buildConfigurationName) else {
                throw Errors.invalidArgument("invalid build configuration named '\(buildConfigurationName)'")
            }
            self.buildConfiguration = buildConfiguration
        } else {
            self.buildConfiguration = .release
        }

        guard !(!swiftVersionArgument.isEmpty && !baseDockerImageArgument.isEmpty) else {
            throw Errors.invalidArgument("--swift-version and --base-docker-image are mutually exclusive")
        }

        let swiftVersion = swiftVersionArgument.first ?? .none  // undefined version will yield the latest docker image
        self.baseDockerImage =
            baseDockerImageArgument.first ?? "swift:\(swiftVersion.map { $0 + "-" } ?? "")amazonlinux2"

        self.disableDockerImageUpdate = disableDockerImageUpdateArgument

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
          outputDirectory: \(self.outputDirectory)
          products: \(self.products.map(\.name))
          buildConfiguration: \(self.buildConfiguration)
          baseDockerImage: \(self.baseDockerImage)
          disableDockerImageUpdate: \(self.disableDockerImageUpdate)
        }
        """
    }
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

private enum Errors: Error, CustomStringConvertible {
    case invalidArgument(String)
    case unsupportedPlatform(String)
    case unknownProduct(String)
    case productExecutableNotFound(String)
    case failedWritingDockerfile
    case failedParsingDockerOutput(String)
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
        case .failedWritingDockerfile:
            return "failed writing dockerfile"
        case .failedParsingDockerOutput(let output):
            return "failed parsing docker output: '\(output)'"
        case .processFailed(let arguments, let code):
            return "\(arguments.joined(separator: " ")) failed with code \(code)"
        }
    }
}

private struct LambdaProduct: Hashable {
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

extension PackageManager.BuildResult {
    // find the executable produced by the build
    func executableArtifact(for product: Product) -> PackageManager.BuildResult.BuiltArtifact? {
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
