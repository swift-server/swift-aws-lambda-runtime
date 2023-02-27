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

#if canImport(Glibc)
import Glibc
#endif

@main
struct AWSLambdaPackager: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let configuration = try Configuration(context: context, arguments: arguments)
        guard !configuration.products.isEmpty else {
            throw PackagerPluginErrors.unknownProduct("no appropriate products found to package")
        }

        if configuration.products.count > 1 && !configuration.explicitProducts {
            let productNames = configuration.products.map(\.name)
            print("No explicit products named, building all executable products: '\(productNames.joined(separator: "', '"))'")
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
                buildConfiguration: configuration.buildConfiguration,
                verboseLogging: configuration.verboseLogging
            )
        }

        // create the archive
        let archives = try self.package(
            products: builtProducts,
            toolsProvider: { name in try context.tool(named: name).path },
            outputDirectory: configuration.outputDirectory,
            verboseLogging: configuration.verboseLogging
        )

        print("\(archives.count > 0 ? archives.count.description : "no") archive\(archives.count != 1 ? "s" : "") created")
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
        buildConfiguration: PackageManager.BuildConfiguration,
        verboseLogging: Bool
    ) throws -> [LambdaProduct: Path] {
        let dockerToolPath = try toolsProvider("docker")

        print("-------------------------------------------------------------------------")
        print("building \"\(packageIdentity)\" in docker")
        print("-------------------------------------------------------------------------")

        // update the underlying docker image, if necessary
        print("updating \"\(baseImage)\" docker image")
        try Utils.execute(
            executable: dockerToolPath,
            arguments: ["pull", baseImage],
            logLevel: .output
        )

        // get the build output path
        let buildOutputPathCommand = "swift build -c \(buildConfiguration.rawValue) --show-bin-path"
        let dockerBuildOutputPath = try Utils.execute(
            executable: dockerToolPath,
            arguments: ["run", "--rm", "-v", "\(packageDirectory.string):/workspace", "-w", "/workspace", baseImage, "bash", "-cl", buildOutputPathCommand],
            logLevel: verboseLogging ? .debug : .silent
        )
        guard let buildPathOutput = dockerBuildOutputPath.split(separator: "\n").last else {
            throw PackagerPluginErrors.failedParsingDockerOutput(dockerBuildOutputPath)
        }
        let buildOutputPath = Path(buildPathOutput.replacingOccurrences(of: "/workspace", with: packageDirectory.string))

        // build the products
        var builtProducts = [LambdaProduct: Path]()
        for product in products {
            print("building \"\(product.name)\"")
            let buildCommand = "swift build -c \(buildConfiguration.rawValue) --product \(product.name) --static-swift-stdlib"
            try Utils.execute(
                executable: dockerToolPath,
                // arguments: ["run", "--rm", "-v", "\(packageDirectory.string):/workspace", "-w", "/workspace", baseImage, "bash", "-cl", buildCommand],
                arguments: ["run", "--rm", "-v", "\(packageDirectory.string)/../..:/workspace", "-w", "/workspace/Examples/SAM", baseImage, "bash", "-cl", buildCommand],                logLevel: verboseLogging ? .debug : .output
            )
            let productPath = buildOutputPath.appending(product.name)
            guard FileManager.default.fileExists(atPath: productPath.string) else {
                Diagnostics.error("expected '\(product.name)' binary at \"\(productPath.string)\"")
                throw PackagerPluginErrors.productExecutableNotFound(product.name)
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
                throw PackagerPluginErrors.productExecutableNotFound(product.name)
            }
            results[.init(product)] = artifact.path
        }
        return results
    }

    // TODO: explore using ziplib or similar instead of shelling out
    private func package(
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
            try FileManager.default.createSymbolicLink(atPath: symbolicLinkPath.string, withDestinationPath: relocatedArtifactPath.lastComponent)

            #if os(macOS) || os(Linux)
            let arguments = ["--junk-paths", "--symlinks", zipfilePath.string, relocatedArtifactPath.string, symbolicLinkPath.string]
            #else
            throw Error.unsupportedPlatform("can't or don't know how to create a zip file on this platform")
            #endif

            // run the zip tool
            try Utils.execute(
                executable: zipToolPath,
                arguments: arguments,
                logLevel: verboseLogging ? .debug : .silent
            )

            archives[product] = zipfilePath
        }
        return archives
    }

    private func isAmazonLinux2() -> Bool {
        if let data = FileManager.default.contents(atPath: "/etc/system-release"), let release = String(data: data, encoding: .utf8) {
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

        self.verboseLogging = verboseArgument

        if let outputPath = outputPathArgument.first {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: outputPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw PackagerPluginErrors.invalidArgument("invalid output directory '\(outputPath)'")
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
                    throw PackagerPluginErrors.invalidArgument("product named '\(product.name)' is not an executable product")
                }
            }
            self.products = products

        } else {
            self.products = context.package.products.filter { $0 is ExecutableProduct }
        }

        if let buildConfigurationName = configurationArgument.first {
            guard let buildConfiguration = PackageManager.BuildConfiguration(rawValue: buildConfigurationName) else {
                throw PackagerPluginErrors.invalidArgument("invalid build configuration named '\(buildConfigurationName)'")
            }
            self.buildConfiguration = buildConfiguration
        } else {
            self.buildConfiguration = .release
        }

        guard !(!swiftVersionArgument.isEmpty && !baseDockerImageArgument.isEmpty) else {
            throw PackagerPluginErrors.invalidArgument("--swift-version and --base-docker-image are mutually exclusive")
        }

        let swiftVersion = swiftVersionArgument.first ?? .none // undefined version will yield the latest docker image
        self.baseDockerImage = baseDockerImageArgument.first ?? "swift:\(swiftVersion.map { $0 + "-" } ?? "")amazonlinux2"

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
        }
        """
    }
}

private enum PackagerPluginErrors: Error, CustomStringConvertible {
    case invalidArgument(String)
    case unsupportedPlatform(String)
    case unknownProduct(String)
    case productExecutableNotFound(String)
    case failedWritingDockerfile
    case failedParsingDockerOutput(String)

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
