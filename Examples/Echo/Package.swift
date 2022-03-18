// swift-tools-version:5.5

import Foundation
import PackageDescription

// this is the dependency on the swift-aws-lambda-runtime library
var dependencies = [Package.Dependency]()
if FileManager.default.fileExists(atPath: "../../Package.swift") {
    dependencies.append(Package.Dependency.package(name: "swift-aws-lambda-runtime", path: "../.."))
} else {
    dependencies.append(Package.Dependency.package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"))
}

let package = Package(
    name: "swift-aws-lambda-runtime-example",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "MyLambda", targets: ["MyLambda"]),
    ],
    dependencies: dependencies,
    targets: [
        .executableTarget(
            name: "MyLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            ],
            path: "."
        ),
    ]
)
