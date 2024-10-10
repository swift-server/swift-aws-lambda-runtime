// swift-tools-version: 6.0

import PackageDescription

// needed for CI to test the local version of the library
import struct Foundation.URL

#if os(macOS)
let platforms: [PackageDescription.SupportedPlatform]? = [.macOS(.v15)]
#else
let platforms: [PackageDescription.SupportedPlatform]? = nil
#endif

let package = Package(
    name: "AWSSDKExample",
    platforms: platforms,
    products: [
        .executable(name: "AWSSDKExample", targets: ["AWSSDKExample"])
    ],
    dependencies: [
        // during CI, the dependency on local version of swift-aws-lambda-runtime is added dynamically below
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events", branch: "main"),
        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "AWSSDKExample",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSS3", package: "aws-sdk-swift"),
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
            location: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
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
