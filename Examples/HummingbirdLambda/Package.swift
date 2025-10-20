// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// needed for CI to test the local version of the library
import struct Foundation.URL

let package = Package(
    name: "HBLambda",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/awslabs/swift-aws-lambda-runtime.git",
            from: "2.0.0"
        ),
        .package(
            url: "https://github.com/hummingbird-project/hummingbird-lambda.git",
            branch: "main"
        ),
        .package(url: "https://github.com/awslabs/swift-aws-lambda-events.git", from: "1.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "HBLambda",
            dependencies: [
                .product(name: "HummingbirdLambda", package: "hummingbird-lambda"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            ]
        )
    ]
)

if let localDepsPath = Context.environment["LAMBDA_USE_LOCAL_DEPS"],
    localDepsPath != "",
    let v = try? URL(fileURLWithPath: localDepsPath).resourceValues(forKeys: [.isDirectoryKey]),
    v.isDirectory == true
{
    // when we use the local runtime as deps, let's remove the dependency added above
    let indexToRemove = package.dependencies.firstIndex { dependency in
        if case .sourceControl(
            name: _,
            location: "https://github.com/awslabs/swift-aws-lambda-runtime.git",
            requirement: _
        ) = dependency.kind {
            return true
        }
        return false
    }
    if let indexToRemove {
        package.dependencies.remove(at: indexToRemove)
    }

    // then we add the dependency on LAMBDA_USE_LOCAL_DEPS' path (typically ../..)
    print("[INFO] Compiling against swift-aws-lambda-runtime located at \(localDepsPath)")
    package.dependencies += [
        .package(name: "swift-aws-lambda-runtime", path: localDepsPath)
    ]
}
