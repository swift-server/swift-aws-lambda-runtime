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

import PackagePlugin
import Foundation

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

        let builtProducts: [LambdaProduct: URL]
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
                packageDirectory: context.package.directoryURL,
                products: configuration.products,
                toolsProvider: { name in try context.tool(named: name).url },
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
            toolsProvider: { name in try context.tool(named: name).url },
            outputDirectory: configuration.outputDirectory,
            verboseLogging: configuration.verboseLogging
        )

        print(
            "\(archives.count > 0 ? archives.count.description : "no") archive\(archives.count != 1 ? "s" : "") created"
        )
        for (product, archivePath) in archives {
            print("  * \(product.name) at \(archivePath)")
        }
    }

    private func buildInDocker(
        packageIdentity: Package.ID,
        packageDirectory: URL,
        products: [Product],
        toolsProvider: (String) throws -> URL,
        outputDirectory: URL,
        baseImage: String,
        disableDockerImageUpdate: Bool,
        buildConfiguration: PackageManager.BuildConfiguration,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: URL] {
        let dockerToolPath = try toolsProvider("docker")

        print("-------------------------------------------------------------------------")
        print("building \"\(packageIdentity)\" in docker")
        print("-------------------------------------------------------------------------")

        if !disableDockerImageUpdate {
            // update the underlying docker image, if necessary
            print("updating \"\(baseImage)\" docker image")
            try Utils.execute(
                executable: dockerToolPath,
                arguments: ["pull", baseImage],
                logLevel: .output
            )
        }

        // get the build output path
        let buildOutputPathCommand = "swift build -c \(buildConfiguration.rawValue) --show-bin-path"
        let dockerBuildOutputPath = try Utils.execute(
            executable: dockerToolPath,
            arguments: [
                "run", "--rm", "-v", "\(packageDirectory.path()):/workspace", "-w", "/workspace", baseImage, "bash",
                "-cl", buildOutputPathCommand,
            ],
            logLevel: verboseLogging ? .debug : .silent
        )
        guard let buildPathOutput = dockerBuildOutputPath.split(separator: "\n").last else {
            throw Errors.failedParsingDockerOutput(dockerBuildOutputPath)
        }
        let buildOutputPath = URL(string: buildPathOutput.replacingOccurrences(of: "/workspace/", with: packageDirectory.description))!            

        // build the products
        var builtProducts = [LambdaProduct: URL]()
        for product in products {
            print("building \"\(product.name)\"")
            let buildCommand =
                "swift build -c \(buildConfiguration.rawValue) --product \(product.name) --static-swift-stdlib"
            if ProcessInfo.processInfo.environment["LAMBDA_USE_LOCAL_DEPS"] != nil {
                // when developing locally, we must have the full swift-aws-lambda-runtime project in the container
                // because Examples' Package.swift have a dependency on ../..
                // just like Package.swift's examples assume ../.., we assume we are two levels below the root project
                let slice = packageDirectory.pathComponents.suffix(2)
                let beforeLastComponent = packageDirectory.pathComponents[slice.startIndex]
                let lastComponent = packageDirectory.pathComponents[slice.endIndex-1]
                try Utils.execute(
                    executable: dockerToolPath,
                    arguments: [
                        "run", "--rm", "--env", "LAMBDA_USE_LOCAL_DEPS=true", "-v",
                        "\(packageDirectory.path())../..:/workspace", "-w",
                        "/workspace/\(beforeLastComponent)/\(lastComponent)", baseImage, "bash", "-cl", buildCommand,
                    ],
                    logLevel: verboseLogging ? .debug : .output
                )
            } else {
                try Utils.execute(
                    executable: dockerToolPath,
                    arguments: [
                        "run", "--rm", "-v", "\(packageDirectory.path()):/workspace", "-w", "/workspace", baseImage,
                        "bash", "-cl", buildCommand,
                    ],
                    logLevel: verboseLogging ? .debug : .output
                )
            }
            let productPath = buildOutputPath.appending(path: product.name)

            guard FileManager.default.fileExists(atPath: productPath.path()) else {
                Diagnostics.error("expected '\(product.name)' binary at \"\(productPath.path())\"")
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
    ) throws -> [LambdaProduct: URL] {
        print("-------------------------------------------------------------------------")
        print("building \"\(packageIdentity)\"")
        print("-------------------------------------------------------------------------")

        var results = [LambdaProduct: URL]()
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
            results[.init(product)] = artifact.url
        }
        return results
    }

    // TODO: explore using ziplib or similar instead of shelling out
    private func package(
        packageName: String,
        products: [LambdaProduct: URL],
        toolsProvider: (String) throws -> URL,
        outputDirectory: URL,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: URL] {
        let zipToolPath = try toolsProvider("zip")

        var archives = [LambdaProduct: URL]()
        for (product, artifactPath) in products {
            print("-------------------------------------------------------------------------")
            print("archiving \"\(product.name)\"")
            print("-------------------------------------------------------------------------")

            // prep zipfile location
            let workingDirectory = outputDirectory.appending(path: product.name)
            let zipfilePath = workingDirectory.appending(path: "\(product.name).zip")
            if FileManager.default.fileExists(atPath: workingDirectory.path()) {
                try FileManager.default.removeItem(atPath: workingDirectory.path())
            }
            try FileManager.default.createDirectory(atPath: workingDirectory.path(), withIntermediateDirectories: true)

            // rename artifact to "bootstrap"
            let relocatedArtifactPath = workingDirectory.appending(path: artifactPath.lastPathComponent)
            let symbolicLinkPath = workingDirectory.appending(path: "bootstrap")
            try FileManager.default.copyItem(atPath: artifactPath.path(), toPath: relocatedArtifactPath.path())
            try FileManager.default.createSymbolicLink(
                atPath: symbolicLinkPath.path(),
                withDestinationPath: relocatedArtifactPath.lastPathComponent
            )

            var arguments: [String] = []
            #if os(macOS) || os(Linux)
            arguments = [
                "--recurse-paths",
                "--symlinks",
                zipfilePath.lastPathComponent,
                relocatedArtifactPath.lastPathComponent,
                symbolicLinkPath.lastPathComponent,
            ]
            #else
            throw Errors.unsupportedPlatform("can't or don't know how to create a zip file on this platform")
            #endif

            // add resources
            var artifactPathComponents = artifactPath.pathComponents
            _ = artifactPathComponents.removeLast()
            let artifactDirectory = artifactPathComponents.joined(separator: "/")
            let resourcesDirectoryName = "\(packageName)_\(product.name).resources"
            let resourcesDirectory = artifactDirectory.appending(resourcesDirectoryName)
            let relocatedResourcesDirectory = workingDirectory.appending(path: resourcesDirectoryName)
            if FileManager.default.fileExists(atPath: resourcesDirectory) {
                try FileManager.default.copyItem(
                    atPath: resourcesDirectory,
                    toPath: relocatedResourcesDirectory.path()
                )
                arguments.append(resourcesDirectoryName)
            }

            // run the zip tool
            try Utils.execute(
                executable: zipToolPath,
                arguments: arguments,
                customWorkingDirectory: workingDirectory,
                logLevel: verboseLogging ? .debug : .silent
            )

            archives[product] = zipfilePath
        }
        return archives
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

@available(macOS 15.0, *)
private struct Configuration: CustomStringConvertible {
    public let outputDirectory: URL
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
            #if os(Linux)
            var isDirectory: Bool = false
            #else
            var isDirectory: ObjCBool = false
            #endif 
            guard FileManager.default.fileExists(atPath: outputPath, isDirectory: &isDirectory)
            else {
                throw Errors.invalidArgument("invalid output directory '\(outputPath)'")
            }
            self.outputDirectory = URL(string: outputPath)!
        } else {
            self.outputDirectory = context.pluginWorkDirectoryURL.appending(path: "\(AWSLambdaPackager.self)")
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
        let executables = self.builtArtifacts.filter { $0.kind == .executable && $0.url.lastPathComponent == product.name }
        guard !executables.isEmpty else {
            return nil
        }
        guard executables.count == 1, let executable = executables.first else {
            return nil
        }
        return executable
    }
}
